package id.vokas.web;

import id.vokas.model.Jenis;
import id.vokas.model.Metode;
import id.vokas.model.Transaksi;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import id.vokas.parser.HasilBaca;
import id.vokas.parser.PembacaCatatan;
import id.vokas.service.DataContohService;
import id.vokas.service.LaporanService;
import id.vokas.service.RiwayatService;
import id.vokas.service.SkorKurService;
import id.vokas.service.TransaksiService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api")
public class TransaksiController {

    private static final long MAKS_AUDIO = 12L * 1024 * 1024;

    private final TransaksiService transaksi;
    private final LaporanService laporan;
    private final SkorKurService kur;
    private final PembacaCatatan pembaca;
    private final DataContohService dataContoh;
    private final RiwayatService riwayat;

    public TransaksiController(TransaksiService transaksi, LaporanService laporan, SkorKurService kur,
                               PembacaCatatan pembaca, DataContohService dataContoh, RiwayatService riwayat) {
        this.riwayat = riwayat;
        this.transaksi = transaksi;
        this.laporan = laporan;
        this.kur = kur;
        this.pembaca = pembaca;
        this.dataContoh = dataContoh;
    }

    public record Catatan(@NotBlank @Size(max = 1000) String teks) {}

    /** Coba baca kalimat tanpa menyimpan (untuk demo dan pengujian parser). */
    @PostMapping("/baca")
    public HasilBaca baca(@Valid @RequestBody Catatan c) {
        return pembaca.bacaTeks(c.teks());
    }

    @PostMapping("/pedagang/{id}/catat")
    public TransaksiService.HasilCatat catat(@PathVariable UUID id, @Valid @RequestBody Catatan c,
                                             @RequestParam(defaultValue = "true") boolean simpan) {
        TransaksiService.HasilCatat h = transaksi.catatTeks(id, c.teks(), simpan);
        if (simpan) riwayat.simpanCatat(id, "TEKS", c.teks(), h);
        return h;
    }

    @PostMapping(value = "/pedagang/{id}/catat-suara", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public TransaksiService.HasilCatat catatSuara(@PathVariable UUID id, @RequestParam("audio") MultipartFile audio) throws IOException {
        if (audio.isEmpty() || audio.getSize() > MAKS_AUDIO)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Audio kosong atau lebih dari 12 MB");
        TransaksiService.HasilCatat h = transaksi.catatSuara(id, audio.getBytes(), audio.getContentType());
        riwayat.simpanCatat(id, "SUARA", null, h, audio.getBytes(), audio.getContentType());
        return h;
    }

    private static final long MAKS_FOTO = 8L * 1024 * 1024;

    /** Foto nota/struk belanja dibaca AI lalu dicatat. */
    @PostMapping(value = "/pedagang/{id}/catat-foto", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public TransaksiService.HasilCatat catatFoto(@PathVariable UUID id, @RequestParam("foto") MultipartFile foto) throws IOException {
        if (foto.isEmpty() || foto.getSize() > MAKS_FOTO)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Foto kosong atau lebih dari 8 MB");
        TransaksiService.HasilCatat h = transaksi.catatFoto(id, foto.getBytes(), foto.getContentType());
        riwayat.simpanCatat(id, "FOTO", null, h);
        return h;
    }

    /** Putar ulang rekaman voice note dari riwayat. */
    @GetMapping("/pedagang/{id}/riwayat-ai/{riwayatId}/audio")
    public org.springframework.http.ResponseEntity<byte[]> audio(@PathVariable UUID id, @PathVariable UUID riwayatId) {
        id.vokas.model.RiwayatAudio a = riwayat.audio(id, riwayatId);
        if (a == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Rekaman tidak tersimpan");
        return org.springframework.http.ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(a.getMime()))
                .body(a.getAudio());
    }

    /** Riwayat Tanya AI (jenis=TANYA) atau catatan suara/teks (jenis=CATAT), maksimal 50 terakhir. */
    @GetMapping("/pedagang/{id}/riwayat-ai")
    public List<id.vokas.model.RiwayatAi> riwayat(@PathVariable UUID id, @RequestParam(defaultValue = "TANYA") String jenis) {
        transaksi.pedagang(id);
        return riwayat.daftar(id, jenis.toUpperCase());
    }

    @DeleteMapping("/pedagang/{id}/riwayat-ai")
    public Map<String, Integer> hapusRiwayat(@PathVariable UUID id, @RequestParam(defaultValue = "TANYA") String jenis) {
        transaksi.pedagang(id);
        return Map.of("terhapus", riwayat.hapus(id, jenis.toUpperCase()));
    }

    @GetMapping("/pedagang/{id}/transaksi")
    public List<Transaksi> daftar(@PathVariable UUID id,
                                  @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dari,
                                  @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate sampai) {
        LocalDate s = sampai != null ? sampai : transaksi.hariIni();
        return transaksi.daftar(id, dari != null ? dari : s, s);
    }

    @PostMapping("/pedagang/{id}/transaksi")
    @ResponseStatus(HttpStatus.CREATED)
    public Transaksi tambah(@PathVariable UUID id, @Valid @RequestBody TransaksiBaru b) {
        Transaksi t = new Transaksi();
        t.setJenis(b.jenis());
        t.setNamaItem(b.namaItem());
        t.setJumlah(b.jumlah());
        t.setSatuan(b.satuan());
        t.setHargaSatuan(b.hargaSatuan());
        t.setTotal(b.total());
        t.setMetode(b.metode());
        t.setTanggal(b.tanggal());
        return transaksi.simpanManual(id, t);
    }

    public record TransaksiBaru(@NotNull Jenis jenis, @NotBlank String namaItem, Integer jumlah, String satuan,
                                Long hargaSatuan, @Positive long total, Metode metode, LocalDate tanggal) {}

    @DeleteMapping("/pedagang/{id}/transaksi/{trxId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void hapus(@PathVariable UUID id, @PathVariable UUID trxId) {
        transaksi.hapus(id, trxId);
    }

    @PostMapping("/pedagang/{id}/mutasi/impor")
    public TransaksiService.HasilImpor imporMutasi(@PathVariable UUID id, @RequestBody List<TransaksiService.Mutasi> mutasi) {
        if (mutasi.size() > 2000) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Maksimal 2000 baris per impor");
        return transaksi.imporMutasi(id, mutasi);
    }

    @GetMapping("/pedagang/{id}/mutasi/perlu-cek")
    public List<Transaksi> perluCek(@PathVariable UUID id) {
        return transaksi.perluDicek(id);
    }

    public record Konfirmasi(boolean usaha) {}

    @PostMapping("/pedagang/{id}/mutasi/{trxId}/konfirmasi")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void konfirmasi(@PathVariable UUID id, @PathVariable UUID trxId, @RequestBody Konfirmasi k) {
        transaksi.konfirmasi(id, trxId, k.usaha());
    }

    @GetMapping("/pedagang/{id}/laporan")
    public LaporanService.Laporan laporan(@PathVariable UUID id,
                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dari,
                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate sampai) {
        LocalDate s = sampai != null ? sampai : transaksi.hariIni();
        return laporan.buat(id, dari != null ? dari : s.minusDays(6), s);
    }

    @PostMapping("/pedagang/{id}/data-contoh")
    public Map<String, Integer> isiDataContoh(@PathVariable UUID id) {
        return Map.of("dibuat", dataContoh.isi(id));
    }

    @DeleteMapping("/pedagang/{id}/data-contoh")
    public Map<String, Integer> hapusDataContoh(@PathVariable UUID id) {
        return Map.of("dihapus", dataContoh.hapus(id));
    }

    @GetMapping("/pedagang/{id}/rapor-kur")
    public SkorKurService.Rapor raporKur(@PathVariable UUID id) {
        return kur.hitung(id);
    }
}
