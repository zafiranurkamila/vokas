package id.vokas.service;

import id.vokas.model.Jenis;
import id.vokas.model.Metode;
import id.vokas.model.Pedagang;
import id.vokas.model.Transaksi;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Rapor Kesiapan KUR: skor 0-100 dari lima kriteria, sama dengan prototipe.
 * Ini alat bantu pedagang merapikan catatan, bukan penilaian kredit BRI.
 */
@Service
public class SkorKurService {

    static final int JENDELA_HARI = 90;
    static final int AMBANG_SIAP = 70;

    private final TransaksiService transaksi;

    public SkorKurService(TransaksiService transaksi) {
        this.transaksi = transaksi;
    }

    public record Kriteria(String nama, double nilai, int bobot, int poin, String keterangan) {}
    public record Rapor(int skor, boolean siap, String status, int hariTercatat, int hariTotal, List<Kriteria> kriteria) {}

    record Hari(long omzet, long biaya, long qris) {}

    public Rapor hitung(UUID pedagangId) {
        Pedagang p = transaksi.pedagang(pedagangId);
        LocalDate sampai = transaksi.hariIni();
        List<Transaksi> list = transaksi.daftar(pedagangId, sampai.minusDays(JENDELA_HARI - 1L), sampai);
        return hitung(list, p.isRekeningTerpisah(), sampai);
    }

    static Rapor hitung(List<Transaksi> list, boolean rekeningTerpisah, LocalDate sampai) {
        TreeMap<LocalDate, Hari> perHari = new TreeMap<>();
        list.stream().collect(Collectors.groupingBy(Transaksi::getTanggal)).forEach((tgl, ts) -> perHari.put(tgl, new Hari(
                LaporanService.jumlah(ts, Jenis.MASUK, null),
                LaporanService.jumlah(ts, Jenis.KELUAR, null),
                LaporanService.jumlah(ts, Jenis.MASUK, Metode.QRIS))));

        if (perHari.isEmpty()) {
            List<Kriteria> nol = List.of(
                    new Kriteria("Konsistensi pencatatan", 0, 30, 0, "Belum ada catatan"),
                    new Kriteria("Transaksi QRIS BRI", 0, 20, 0, "Belum ada catatan"),
                    kriteriaRekening(rekeningTerpisah),
                    new Kriteria("Keuntungan usaha", 0, 20, 0, "Belum ada catatan"),
                    new Kriteria("Tren omzet", 0, 15, 0, "Belum ada catatan"));
            int skor = nol.stream().mapToInt(Kriteria::poin).sum();
            return new Rapor(skor, false, "Mulai catat dulu", 0, 0, nol);
        }

        // hari total dihitung sejak catatan pertama (maksimal 90 hari), supaya pengguna baru tidak langsung dihukum
        int hariTotal = (int) ChronoUnit.DAYS.between(perHari.firstKey(), sampai) + 1;
        List<Hari> rec = new ArrayList<>(perHari.values());
        int n = rec.size();
        List<Hari> awal = rec.subList(0, Math.min(30, n)), akhir = rec.subList(Math.max(0, n - 30), n);

        long omzetTotal = rec.stream().mapToLong(Hari::omzet).sum();
        long labaTotal = rec.stream().mapToLong(h -> h.omzet() - h.biaya()).sum();
        double margin = omzetTotal > 0 ? (double) labaTotal / omzetTotal : 0;
        double rataAwal = rata(awal), rataAkhir = rata(akhir);
        double tumbuh = rataAwal > 0 ? rataAkhir / rataAwal - 1 : 0;
        long omzetAkhir = akhir.stream().mapToLong(Hari::omzet).sum();
        double qshare = omzetAkhir > 0 ? (double) akhir.stream().mapToLong(Hari::qris).sum() / omzetAkhir : 0;

        List<Kriteria> k = List.of(
                kriteria("Konsistensi pencatatan", (double) n / hariTotal, 30, n + " dari " + hariTotal + " hari tercatat"),
                kriteria("Transaksi QRIS BRI", Math.min(1, qshare / 0.5), 20, Math.round(qshare * 100) + "% omzet 30 hari tercatat terakhir"),
                kriteriaRekening(rekeningTerpisah),
                kriteria("Keuntungan usaha", batas(margin / 0.4), 20, "Margin laba " + Math.round(margin * 100) + "%"),
                kriteria("Tren omzet", n < 14 ? 0.5 : batas(0.5 + tumbuh * 2.5), 15, n < 14
                        ? "Butuh minimal 14 hari tercatat"
                        : (tumbuh >= 0 ? "Naik " : "Turun ") + Math.abs(Math.round(tumbuh * 100)) + "% dari awal pencatatan"));
        // skor = jumlah poin yang ditampilkan, supaya total selalu sama dengan penjumlahan komponennya
        int skor = k.stream().mapToInt(Kriteria::poin).sum();
        boolean siap = skor >= AMBANG_SIAP;
        return new Rapor(skor, siap, siap ? "Catatan siap dilaporkan" : "Lanjutkan pencatatan", n, hariTotal, k);
    }

    private static Kriteria kriteria(String nama, double v, int bobot, String ket) {
        return new Kriteria(nama, v, bobot, (int) Math.round(v * bobot), ket);
    }

    private static Kriteria kriteriaRekening(boolean ya) {
        return kriteria("Uang usaha terpisah", ya ? 1 : 0, 15, ya ? "Punya rekening usaha sendiri" : "Uang usaha masih campur");
    }

    private static double rata(List<Hari> hs) {
        return hs.isEmpty() ? 0 : hs.stream().mapToLong(Hari::omzet).average().orElse(0);
    }

    private static double batas(double v) {
        return Math.min(1, Math.max(0, v));
    }
}
