package id.vokas.service;

import id.vokas.model.Celengan;
import id.vokas.model.CelenganSetoran;
import id.vokas.repo.CelenganRepo;
import id.vokas.repo.CelenganSetoranRepo;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

/**
 * Celengan: sisihkan sebagian untung harian ke target tabungan (misalnya DP usaha atau cicilan KUR).
 * Uangnya tetap di rekening pedagang; VoKas hanya mencatat dan mengingatkan.
 */
@Service
public class CelenganService {

    private final CelenganRepo repo;
    private final CelenganSetoranRepo setoranRepo;
    private final TransaksiService transaksi;
    private final LaporanService laporan;
    private final ZoneId zona;

    public CelenganService(CelenganRepo repo, CelenganSetoranRepo setoranRepo, TransaksiService transaksi,
                           LaporanService laporan, id.vokas.config.VokasProperties props) {
        this.repo = repo;
        this.setoranRepo = setoranRepo;
        this.transaksi = transaksi;
        this.laporan = laporan;
        this.zona = ZoneId.of(props.zonaWaktu());
    }

    /**
     * @param saranHariIni persen x untung hari ini (0 bila belum untung)
     * @param perkiraanHari perkiraan hari sampai target bila rutin menyisihkan sebesar rata-rata untung 7 hari
     */
    public record Status(Celengan celengan, long terkumpul, long sisa, int persenTercapai, long untungHariIni,
                         long saranHariIni, boolean sudahSetorHariIni, Integer perkiraanHari,
                         List<CelenganSetoran> riwayat) {}

    public Status status(UUID pedagangId) {
        transaksi.pedagang(pedagangId);
        Celengan c = repo.findById(pedagangId).orElse(null);
        LocalDate hari = transaksi.hariIni();
        long untung = Math.max(0, laporan.buat(pedagangId, hari, hari).laba());
        if (c == null) return new Status(null, 0, 0, 0, untung, 0, false, null, List.of());
        long terkumpul = setoranRepo.total(pedagangId);
        long sisa = Math.max(0, c.getTarget() - terkumpul);
        int persen = (int) Math.min(100, terkumpul * 100 / c.getTarget());
        OffsetDateTime awalHari = hari.atStartOfDay(zona).toOffsetDateTime();
        boolean sudah = setoranRepo.setorSejak(pedagangId, awalHari) > 0;
        long rata7 = Math.max(0, laporan.buat(pedagangId, hari.minusDays(6), hari).laba() / 7);
        long perHari = rata7 * c.getPersen() / 100;
        Integer perkiraan = sisa == 0 ? 0 : perHari > 0 ? (int) Math.ceil((double) sisa / perHari) : null;
        long saran = bulatkan(untung * c.getPersen() / 100);
        return new Status(c, terkumpul, sisa, persen, untung, saran, sudah, perkiraan,
                setoranRepo.findTop30ByPedagangIdOrderByDibuatDesc(pedagangId));
    }

    @Transactional
    public Status atur(UUID pedagangId, String nama, long target, int persen) {
        transaksi.pedagang(pedagangId);
        if (target <= 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Target harus lebih dari 0");
        if (persen < 1 || persen > 100) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Persen 1 sampai 100");
        Celengan c = repo.findById(pedagangId).orElseGet(Celengan::new);
        c.setPedagangId(pedagangId);
        c.setNama(nama == null || nama.isBlank() ? "Celengan usaha" : nama.trim());
        c.setTarget(target);
        c.setPersen(persen);
        c.setDiubah(OffsetDateTime.now());
        repo.save(c);
        return status(pedagangId);
    }

    /** nominal positif = menyisihkan, negatif = mengambil. */
    @Transactional
    public Status setor(UUID pedagangId, long nominal, String catatan) {
        if (repo.findById(pedagangId).isEmpty())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Buat target celengan dulu");
        if (nominal == 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Nominal tidak boleh 0");
        if (nominal < 0 && setoranRepo.total(pedagangId) + nominal < 0)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Isi celengan tidak cukup");
        setoranRepo.save(new CelenganSetoran(pedagangId, nominal,
                catatan == null || catatan.isBlank() ? (nominal > 0 ? "Sisihkan untung" : "Ambil") : catatan.trim()));
        return status(pedagangId);
    }

    /** Dibulatkan ke ratusan rupiah supaya enak disisihkan. */
    static long bulatkan(long v) {
        return v <= 0 ? 0 : Math.max(100, Math.round(v / 100.0) * 100);
    }
}
