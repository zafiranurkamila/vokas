package id.vokas.service;

import id.vokas.config.VokasProperties;
import id.vokas.model.*;
import id.vokas.parser.HasilBaca;
import id.vokas.parser.ItemCatatan;
import id.vokas.parser.PembacaCatatan;
import id.vokas.repo.PedagangRepo;
import id.vokas.repo.TransaksiRepo;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class TransaksiService {

    private final TransaksiRepo repo;
    private final PedagangRepo pedagangRepo;
    private final PembacaCatatan pembaca;
    private final id.vokas.parser.PembacaGemini gemini;
    private final ZoneId zona;

    public TransaksiService(TransaksiRepo repo, PedagangRepo pedagangRepo, PembacaCatatan pembaca,
                            id.vokas.parser.PembacaGemini gemini, VokasProperties props) {
        this.repo = repo;
        this.gemini = gemini;
        this.pedagangRepo = pedagangRepo;
        this.pembaca = pembaca;
        this.zona = ZoneId.of(props.zonaWaktu());
    }

    public LocalDate hariIni() { return LocalDate.now(zona); }

    public Pedagang pedagang(UUID id) {
        return pedagangRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Pedagang tidak ditemukan"));
    }

    public record HasilCatat(HasilBaca baca, List<Transaksi> tersimpan) {}

    /** Membaca catatan teks lalu menyimpan transaksinya. simpan=false hanya pratinjau. */
    @Transactional
    public HasilCatat catatTeks(UUID pedagangId, String teks, boolean simpan) {
        pedagang(pedagangId);
        HasilBaca h = pembaca.bacaTeks(teks);
        return new HasilCatat(h, simpan ? simpanSemua(pedagangId, h, Sumber.TEKS, teks) : List.of());
    }

    @Transactional
    public HasilCatat catatSuara(UUID pedagangId, byte[] audio, String mime) {
        pedagang(pedagangId);
        HasilBaca h = pembaca.bacaSuara(audio, mime);
        return new HasilCatat(h, simpanSemua(pedagangId, h, Sumber.SUARA, h.transkrip()));
    }

    /** Foto nota belanja dibaca AI lalu dicatat (umumnya sebagai pengeluaran). */
    @Transactional
    public HasilCatat catatFoto(UUID pedagangId, byte[] gambar, String mime) {
        pedagang(pedagangId);
        HasilBaca h = gemini.bacaGambar(gambar, mime);
        return new HasilCatat(h, simpanSemua(pedagangId, h, Sumber.FOTO, h.transkrip()));
    }

    private List<Transaksi> simpanSemua(UUID pedagangId, HasilBaca h, Sumber sumber, String asli) {
        List<Transaksi> out = new ArrayList<>();
        for (ItemCatatan it : h.items()) {
            Transaksi t = new Transaksi();
            t.setPedagangId(pedagangId);
            t.setTanggal(hariIni());
            t.setJenis(it.jenis());
            t.setNamaItem(it.nama());
            t.setJumlah(it.jumlah());
            t.setSatuan(it.satuan());
            t.setHargaSatuan(it.hargaSatuan());
            t.setTotal(it.total());
            t.setMetode(Metode.TUNAI);
            t.setSumber(sumber);
            t.setCatatanAsli(asli);
            out.add(repo.save(t));
        }
        return out;
    }

    /**
     * Satu baris mutasi rekening. jenis MASUK/KELUAR, metode QRIS atau TRANSFER.
     * jenis/metode boleh kosong: default MASUK dan QRIS.
     */
    public record Mutasi(String ref, LocalDate tanggal, long nominal, String keterangan, Jenis jenis, Metode metode) {}

    public record HasilImpor(int baru, int perluCek, int dilewati) {}

    /**
     * Impor mutasi rekening (QRIS masuk, transfer masuk, transfer keluar) dari ekspor mutasi yang diunggah
     * pedagang. Belum ada integrasi langsung ke API BRI. ref mencegah mutasi yang sama tercatat dua kali.
     * QRIS masuk pasti dari pembeli, jadi langsung dihitung. Transfer belum tentu uang usaha (bisa kiriman
     * keluarga atau pindah dana sendiri), jadi ditandai perluCek dan tidak masuk laporan sampai dikonfirmasi.
     */
    @Transactional
    public HasilImpor imporMutasi(UUID pedagangId, List<Mutasi> mutasi) {
        pedagang(pedagangId);
        int baru = 0, cek = 0, lewat = 0;
        for (Mutasi m : mutasi) {
            if (m.nominal() <= 0 || m.ref() == null || m.ref().isBlank()
                    || repo.existsByPedagangIdAndRefEksternal(pedagangId, m.ref())) { lewat++; continue; }
            Jenis jenis = m.jenis() != null ? m.jenis() : Jenis.MASUK;
            Metode metode = m.metode() == Metode.TRANSFER ? Metode.TRANSFER : Metode.QRIS;
            boolean perluCek = metode == Metode.TRANSFER;
            Transaksi t = new Transaksi();
            t.setPedagangId(pedagangId);
            t.setTanggal(m.tanggal() != null ? m.tanggal() : hariIni());
            t.setJenis(jenis);
            String bawaan = metode == Metode.QRIS ? "Pembayaran QRIS" : (jenis == Jenis.MASUK ? "Transfer masuk" : "Transfer keluar");
            t.setNamaItem(m.keterangan() == null || m.keterangan().isBlank() ? bawaan : m.keterangan());
            t.setTotal(m.nominal());
            t.setMetode(metode);
            t.setSumber(metode == Metode.QRIS ? Sumber.QRIS : Sumber.MUTASI);
            t.setRefEksternal(m.ref());
            t.setPerluCek(perluCek);
            repo.save(t);
            baru++;
            if (perluCek) cek++;
        }
        return new HasilImpor(baru, cek, lewat);
    }

    public List<Transaksi> perluDicek(UUID pedagangId) {
        return repo.findByPedagangIdAndPerluCekTrueOrderByTanggalDesc(pedagangId);
    }

    /** usaha=true: transfer dihitung sebagai uang usaha. usaha=false: bukan uang usaha, dihapus dari catatan. */
    @Transactional
    public void konfirmasi(UUID pedagangId, UUID transaksiId, boolean usaha) {
        Transaksi t = repo.findById(transaksiId)
                .filter(x -> x.getPedagangId().equals(pedagangId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Transaksi tidak ditemukan"));
        if (usaha) {
            t.setPerluCek(false);
            repo.save(t);
        } else {
            repo.delete(t);
        }
    }

    /** Transaksi yang dihitung di laporan dan rapor KUR (tanpa transfer yang belum dikonfirmasi). */
    public List<Transaksi> daftar(UUID pedagangId, LocalDate dari, LocalDate sampai) {
        return repo.findByPedagangIdAndTanggalBetweenOrderByTanggalAscDibuatAsc(pedagangId, dari, sampai)
                .stream().filter(t -> !t.isPerluCek()).toList();
    }

    @Transactional
    public Transaksi simpanManual(UUID pedagangId, Transaksi t) {
        pedagang(pedagangId);
        t.setPedagangId(pedagangId);
        if (t.getTanggal() == null) t.setTanggal(hariIni());
        if (t.getSumber() == null) t.setSumber(Sumber.MANUAL);
        if (t.getMetode() == null) t.setMetode(Metode.TUNAI);
        return repo.save(t);
    }

    @Transactional
    public void hapus(UUID pedagangId, UUID transaksiId) {
        Transaksi t = repo.findById(transaksiId)
                .filter(x -> x.getPedagangId().equals(pedagangId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Transaksi tidak ditemukan"));
        repo.delete(t);
    }
}
