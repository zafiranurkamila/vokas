package id.vokas.service;

import id.vokas.model.Jenis;
import id.vokas.model.Kasbon;
import id.vokas.model.Transaksi;
import id.vokas.parser.PembacaGemini;
import id.vokas.repo.KasbonRepo;
import org.springframework.stereotype.Service;

import java.text.NumberFormat;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.TextStyle;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

/**
 * Wawasan dari catatan pedagang sendiri:
 * - Saran Belanja Besok: perkiraan omzet dan jumlah barang yang perlu disiapkan, dari pola hari yang sama 4 minggu terakhir.
 * - Peringatan Pintar: hal janggal seperti omzet turun beruntun, pengeluaran melonjak, atau kasbon menumpuk.
 * Angka dihitung dari data asli; AI hanya menulis satu-dua kalimat saran di atas angka itu.
 */
@Service
public class WawasanService {

    private static final Locale ID = new Locale("id", "ID");

    private final TransaksiService transaksi;
    private final KasbonRepo kasbonRepo;
    private final PembacaGemini gemini;
    private final ZoneId zona;
    /** Tips AI disimpan per pedagang per hari supaya tidak memanggil AI setiap kali layar dibuka. */
    private final Map<String, String> tipsCache = new ConcurrentHashMap<>();

    public WawasanService(TransaksiService transaksi, KasbonRepo kasbonRepo, PembacaGemini gemini,
                          id.vokas.config.VokasProperties props) {
        this.transaksi = transaksi;
        this.kasbonRepo = kasbonRepo;
        this.gemini = gemini;
        this.zona = ZoneId.of(props.zonaWaktu());
    }

    // ================= Saran Belanja Besok =================

    public record Barang(String nama, String satuan, double rataJumlah, int siapkan, long rataOmzet) {}

    public record PengingatBelanja(String nama, int tiapHari, int terakhirHariLalu, long rataBelanja) {}

    public record Saran(LocalDate tanggal, String hari, boolean cukupData, int hariData, boolean polaHariSama,
                        long perkiraanOmzet, Integer bandingRataPersen, List<Barang> barang,
                        List<PengingatBelanja> pengingatBelanja, String tipsAi) {}

    public Saran saranBesok(UUID pedagangId) {
        transaksi.pedagang(pedagangId);
        LocalDate hari = transaksi.hariIni();
        LocalDate besok = hari.plusDays(1);
        String namaHari = besok.getDayOfWeek().getDisplayName(TextStyle.FULL, ID);
        List<Transaksi> semua = transaksi.daftar(pedagangId, hari.minusDays(27), hari);
        Map<LocalDate, List<Transaksi>> masukPerHari = semua.stream().filter(t -> t.getJenis() == Jenis.MASUK)
                .collect(Collectors.groupingBy(Transaksi::getTanggal, TreeMap::new, Collectors.toList()));
        List<PengingatBelanja> pengingat = pengingatBelanja(semua, hari);
        if (masukPerHari.size() < 3) {
            return new Saran(besok, namaHari, false, masukPerHari.size(), false, 0, null, List.of(), pengingat, null);
        }
        DayOfWeek dow = besok.getDayOfWeek();
        List<LocalDate> hariSama = masukPerHari.keySet().stream().filter(d -> d.getDayOfWeek() == dow).toList();
        boolean polaSama = hariSama.size() >= 2;
        List<LocalDate> dasar = polaSama ? hariSama : new ArrayList<>(masukPerHari.keySet());
        int n = dasar.size();

        long omzetDasar = dasar.stream().flatMap(d -> masukPerHari.get(d).stream()).mapToLong(Transaksi::getTotal).sum();
        long perkiraan = omzetDasar / n;
        long rataSemua = masukPerHari.values().stream().flatMap(List::stream).mapToLong(Transaksi::getTotal).sum()
                / masukPerHari.size();
        Integer banding = rataSemua > 0 && polaSama ? (int) Math.round((perkiraan * 100.0 / rataSemua) - 100) : null;

        Map<String, List<Transaksi>> perBarang = dasar.stream().flatMap(d -> masukPerHari.get(d).stream())
                .filter(t -> !t.getNamaItem().toLowerCase(ID).startsWith("kasbon"))
                .collect(Collectors.groupingBy(t -> t.getNamaItem().toLowerCase(ID).trim()));
        List<Barang> barang = perBarang.entrySet().stream().map(e -> {
            List<Transaksi> l = e.getValue();
            double jumlah = l.stream().mapToInt(t -> t.getJumlah() == null ? 0 : t.getJumlah()).sum() / (double) n;
            long omzet = l.stream().mapToLong(Transaksi::getTotal).sum() / n;
            String satuan = l.stream().map(Transaksi::getSatuan).filter(Objects::nonNull)
                    .collect(Collectors.groupingBy(s -> s, Collectors.counting())).entrySet().stream()
                    .max(Map.Entry.comparingByValue()).map(Map.Entry::getKey).orElse(null);
            int siapkan = jumlah > 0 ? (int) Math.ceil(jumlah * 1.1) : 0;   // lebihkan 10% supaya tidak kehabisan
            return new Barang(e.getKey(), satuan, Math.round(jumlah * 10) / 10.0, siapkan, omzet);
        }).sorted(Comparator.comparingLong(Barang::rataOmzet).reversed()).limit(6).toList();

        String kunci = pedagangId + "|" + hari;
        String tips = tipsCache.get(kunci);
        if (tips == null && gemini.aktif()) {
            tips = tipsAi(namaHari, perkiraan, banding, barang, pengingat);
            if (tips != null) {
                if (tipsCache.size() > 2000) tipsCache.clear();
                tipsCache.put(kunci, tips);
            }
        }
        return new Saran(besok, namaHari, true, masukPerHari.size(), polaSama, perkiraan, banding, barang, pengingat, tips);
    }

    /** Barang belanjaan rutin (dibeli minimal 3 kali dalam 4 minggu) yang sudah waktunya dibeli lagi. */
    private List<PengingatBelanja> pengingatBelanja(List<Transaksi> semua, LocalDate hari) {
        Map<String, List<Transaksi>> keluar = semua.stream().filter(t -> t.getJenis() == Jenis.KELUAR)
                .collect(Collectors.groupingBy(t -> t.getNamaItem().toLowerCase(ID).trim()));
        List<PengingatBelanja> out = new ArrayList<>();
        keluar.forEach((nama, l) -> {
            List<LocalDate> tgl = l.stream().map(Transaksi::getTanggal).distinct().sorted().toList();
            if (tgl.size() < 3) return;
            long rentang = ChronoUnit.DAYS.between(tgl.get(0), tgl.get(tgl.size() - 1));
            int tiap = (int) Math.max(1, Math.round(rentang / (double) (tgl.size() - 1)));
            int lalu = (int) ChronoUnit.DAYS.between(tgl.get(tgl.size() - 1), hari);
            long rata = l.stream().mapToLong(Transaksi::getTotal).sum() / tgl.size();
            if (lalu + 1 >= tiap) out.add(new PengingatBelanja(nama, tiap, lalu, rata));
        });
        out.sort(Comparator.comparingLong(PengingatBelanja::rataBelanja).reversed());
        return out.stream().limit(4).toList();
    }

    private String tipsAi(String namaHari, long perkiraan, Integer banding, List<Barang> barang, List<PengingatBelanja> pengingat) {
        StringBuilder data = new StringBuilder();
        data.append("Besok hari ").append(namaHari).append(". Perkiraan omzet ").append(rp(perkiraan));
        if (banding != null) data.append(" (").append(banding >= 0 ? "+" : "").append(banding).append("% dari rata-rata harian)");
        data.append(".\nBarang yang biasanya laku: ");
        barang.forEach(b -> data.append(b.nama()).append(b.siapkan() > 0 ? " sekitar " + b.siapkan() + " " + Objects.requireNonNullElse(b.satuan(), "") : "")
                .append("; "));
        if (!pengingat.isEmpty()) {
            data.append("\nBelanjaan rutin yang sudah waktunya: ");
            pengingat.forEach(p -> data.append(p.nama()).append(" (tiap ").append(p.tiapHari()).append(" hari); "));
        }
        PembacaGemini.Jawaban j = gemini.jawab("""
                Kamu asisten usaha untuk pedagang kecil Indonesia. Dari data berikut, tulis saran persiapan jualan untuk besok
                dalam maksimal 2 kalimat pendek, bahasa santai dan hangat, tanpa markdown, tanpa salam pembuka.
                Gunakan hanya angka yang ada di data, jangan mengarang angka baru.""", data.toString());
        return j.galat() == null && j.teks() != null && !j.teks().isBlank() ? j.teks().trim() : null;
    }

    // ================= Peringatan Pintar =================

    /** jenis: BAHAYA, WASPADA, INFO, atau BAIK. ikon dipakai aplikasi untuk memilih gambar. */
    public record Peringatan(String jenis, String ikon, String judul, String isi) {}

    public List<Peringatan> peringatan(UUID pedagangId) {
        transaksi.pedagang(pedagangId);
        LocalDate hari = transaksi.hariIni();
        List<Transaksi> l = transaksi.daftar(pedagangId, hari.minusDays(13), hari);
        List<Peringatan> out = new ArrayList<>();

        Map<LocalDate, Long> omzet = new TreeMap<>();
        Map<LocalDate, Long> keluar = new TreeMap<>();
        for (Transaksi t : l) {
            (t.getJenis() == Jenis.MASUK ? omzet : keluar).merge(t.getTanggal(), t.getTotal(), Long::sum);
        }

        // 1. Omzet turun 3 hari berturut-turut (hari ini belum selesai, jadi dihitung sampai kemarin)
        long a = omzet.getOrDefault(hari.minusDays(3), 0L), b = omzet.getOrDefault(hari.minusDays(2), 0L),
                c = omzet.getOrDefault(hari.minusDays(1), 0L);
        if (a > 0 && b > 0 && c > 0 && a > b && b > c && c < a * 0.8) {
            out.add(new Peringatan("BAHAYA", "turun", "Omzet turun 3 hari berturut-turut",
                    "Dari " + rp(a) + " jadi " + rp(c) + " (" + Math.round(100 - c * 100.0 / a) + "% lebih rendah). "
                            + "Cek apakah ada barang yang kurang laku atau pembeli yang pindah."));
        }

        // 2. Pengeluaran per barang melonjak: 7 hari terakhir vs 7 hari sebelumnya
        LocalDate batas = hari.minusDays(6);
        Map<String, long[]> perBarang = new HashMap<>();
        for (Transaksi t : l) {
            if (t.getJenis() != Jenis.KELUAR) continue;
            long[] v = perBarang.computeIfAbsent(t.getNamaItem().toLowerCase(ID).trim(), k -> new long[2]);
            v[t.getTanggal().isBefore(batas) ? 0 : 1] += t.getTotal();
        }
        perBarang.entrySet().stream()
                .filter(e -> e.getValue()[0] > 0 && e.getValue()[1] >= e.getValue()[0] * 1.3 && e.getValue()[1] - e.getValue()[0] >= 20_000)
                .sorted(Comparator.comparingLong((Map.Entry<String, long[]> e) -> e.getValue()[1] - e.getValue()[0]).reversed())
                .limit(2)
                .forEach(e -> {
                    long lama = e.getValue()[0], baru = e.getValue()[1];
                    out.add(new Peringatan("WASPADA", "naik", "Belanja " + e.getKey() + " naik " + Math.round(baru * 100.0 / lama - 100) + "%",
                            "Minggu ini " + rp(baru) + ", minggu lalu " + rp(lama) + ". Mungkin harga naik atau ada yang terbuang; "
                                    + "pertimbangkan cari pemasok lain atau sesuaikan harga jual."));
                });

        // 3. Untung tipis 7 hari terakhir
        long om7 = omzet.entrySet().stream().filter(e -> !e.getKey().isBefore(batas)).mapToLong(Map.Entry::getValue).sum();
        long kl7 = keluar.entrySet().stream().filter(e -> !e.getKey().isBefore(batas)).mapToLong(Map.Entry::getValue).sum();
        long om7Lalu = omzet.entrySet().stream().filter(e -> e.getKey().isBefore(batas)).mapToLong(Map.Entry::getValue).sum();
        if (om7 > 0 && kl7 > om7) {
            out.add(new Peringatan("BAHAYA", "rugi", "Pengeluaran lebih besar dari omzet",
                    "7 hari terakhir keluar " + rp(kl7) + ", masuk " + rp(om7) + ". Usaha sedang rugi " + rp(kl7 - om7) + "."));
        } else if (om7 > 0 && (om7 - kl7) * 100 / om7 < 15) {
            out.add(new Peringatan("WASPADA", "tipis", "Untung tipis minggu ini",
                    "Untung hanya " + ((om7 - kl7) * 100 / om7) + "% dari omzet. Coba naikkan harga sedikit atau tekan biaya bahan."));
        }

        // 4. Kasbon menumpuk lebih dari 7 hari
        OffsetDateTime seminggu = OffsetDateTime.now(zona).minusDays(7);
        List<Kasbon> lama = kasbonRepo.findByPedagangIdAndLunasFalseOrderByDibuatAsc(pedagangId).stream()
                .filter(k -> k.getDibuat() != null && k.getDibuat().isBefore(seminggu)).toList();
        if (!lama.isEmpty()) {
            long total = lama.stream().mapToLong(Kasbon::getNominal).sum();
            out.add(new Peringatan("WASPADA", "kasbon", lama.size() + " kasbon belum dibayar lebih dari seminggu",
                    "Total " + rp(total) + ", paling lama atas nama " + lama.get(0).getNamaPelanggan() + ". Tagih lewat menu Kasbon."));
        }

        // 5. Belum mencatat hari ini (setelah jam 1 siang)
        boolean adaHariIni = l.stream().anyMatch(t -> t.getTanggal().equals(hari));
        if (!adaHariIni && LocalTime.now(zona).isAfter(LocalTime.of(13, 0))) {
            out.add(new Peringatan("INFO", "catat", "Belum ada catatan hari ini",
                    "Catatan rutin menaikkan skor Rapor KUR. Tekan mic dan sebutkan jualanmu."));
        }

        // 6. Kabar baik: omzet minggu ini naik
        if (om7Lalu > 0 && om7 >= om7Lalu * 1.2) {
            out.add(new Peringatan("BAIK", "mantap", "Omzet naik " + Math.round(om7 * 100.0 / om7Lalu - 100) + "% minggu ini",
                    "Minggu ini " + rp(om7) + " dibanding " + rp(om7Lalu) + " minggu lalu. Pertahankan!"));
        }

        List<String> urutan = List.of("BAHAYA", "WASPADA", "INFO", "BAIK");
        out.sort(Comparator.comparingInt(p -> urutan.indexOf(p.jenis())));
        return out;
    }

    private static String rp(long v) {
        return "Rp" + NumberFormat.getIntegerInstance(ID).format(v);
    }
}
