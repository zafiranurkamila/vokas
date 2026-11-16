package id.vokas.service;

import id.vokas.model.Jenis;
import id.vokas.model.Metode;
import id.vokas.model.Pedagang;
import id.vokas.model.Transaksi;
import id.vokas.repo.PedagangRepo;
import id.vokas.whatsapp.TwilioClient;
import id.vokas.whatsapp.WhatsAppClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.text.NumberFormat;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.time.format.TextStyle;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * Laporan berkala untuk pedagang:
 * - harian (settlement): rincian pembayaran QRIS dan ringkasan hari itu, dikirim pukul 21.00 WIB;
 * - bulanan: laporan lengkap bulan sebelumnya, dikirim tanggal 1 pukul 07.00 WIB.
 * Rincian lengkap lewat email; bila WhatsApp aktif, ringkasan singkat juga dikirim lewat WA.
 */
@Service
public class LaporanBerkalaService {

    private static final Logger log = LoggerFactory.getLogger(LaporanBerkalaService.class);
    private static final Locale ID = new Locale("id", "ID");
    private static final DateTimeFormatter TGL = DateTimeFormatter.ofPattern("d MMMM yyyy", ID);
    private static final DateTimeFormatter JAM = DateTimeFormatter.ofPattern("HH:mm");

    private final PedagangRepo pedagangRepo;
    private final TransaksiService transaksi;
    private final LaporanService laporan;
    private final SkorKurService kur;
    private final EmailService email;
    private final WhatsAppClient wa;
    private final TwilioClient twilio;
    private final EksporLaporanService ekspor;

    public LaporanBerkalaService(PedagangRepo pedagangRepo, TransaksiService transaksi, LaporanService laporan,
                                 SkorKurService kur, EmailService email, WhatsAppClient wa, TwilioClient twilio,
                                 EksporLaporanService ekspor) {
        this.ekspor = ekspor;
        this.pedagangRepo = pedagangRepo;
        this.transaksi = transaksi;
        this.laporan = laporan;
        this.kur = kur;
        this.email = email;
        this.wa = wa;
        this.twilio = twilio;
    }

    // ---------------- jadwal ----------------

    @Scheduled(cron = "0 0 21 * * *", zone = "Asia/Jakarta")
    public void jadwalHarian() {
        LocalDate hari = transaksi.hariIni();
        for (Pedagang p : penerima()) {
            try {
                if (!transaksi.daftar(p.getId(), hari, hari).isEmpty()) kirimHarian(p.getId(), hari);
            } catch (Exception e) {
                log.warn("Laporan harian {} gagal: {}", p.getId(), e.getMessage());
            }
        }
    }

    @Scheduled(cron = "0 0 7 1 * *", zone = "Asia/Jakarta")
    public void jadwalBulanan() {
        YearMonth lalu = YearMonth.from(transaksi.hariIni()).minusMonths(1);
        for (Pedagang p : penerima()) {
            try {
                kirimBulanan(p.getId(), lalu);
            } catch (Exception e) {
                log.warn("Laporan bulanan {} gagal: {}", p.getId(), e.getMessage());
            }
        }
    }

    private List<Pedagang> penerima() {
        return pedagangRepo.findAll().stream()
                .filter(p -> p.isEmailTerverifikasi() && p.isLaporanEmail() && p.getEmail() != null).toList();
    }

    // ---------------- laporan harian (settlement) ----------------

    public record Hasil(boolean email, boolean wa) {}

    public Hasil kirimHarian(UUID id, LocalDate hari) {
        Pedagang p = transaksi.pedagang(id);
        LaporanService.Laporan l = laporan.buat(id, hari, hari);
        List<Transaksi> qris = transaksi.daftar(id, hari, hari).stream()
                .filter(t -> t.getJenis() == Jenis.MASUK && t.getMetode() == Metode.QRIS).toList();

        StringBuilder baris = new StringBuilder();
        for (Transaksi t : qris) {
            String jam = t.getDibuat() == null ? "-" : t.getDibuat().atZoneSameInstant(java.time.ZoneId.of("Asia/Jakarta")).format(JAM);
            baris.append(tr(jam, t.getNamaItem(), rp(t.getTotal())));
        }
        if (qris.isEmpty()) baris.append("<tr><td colspan=3 style='padding:10px;color:#6B7663'>Belum ada pembayaran QRIS hari ini.</td></tr>");

        String isi = kepala("Settlement Harian", TGL.format(hari), p)
                + kotakAngka(new String[][]{{"Omzet", rp(l.omzet())}, {"Lewat QRIS", rp(l.omzetQris())},
                {"Pengeluaran", rp(l.pengeluaran())}, {"Laba", rp(l.laba())}})
                + "<h3 style='margin:24px 0 8px;color:#23301C'>Rincian pembayaran QRIS (" + qris.size() + ")</h3>"
                + tabel(new String[]{"Jam", "Keterangan", "Nominal"}, baris.toString())
                + "<p style='color:#6B7663;font-size:13px'>Total QRIS masuk hari ini: <b>" + rp(l.omzetQris()) + "</b> dari "
                + qris.size() + " transaksi. Dana diteruskan ke rekening BRI sesuai jadwal settlement merchant QRIS BRI.</p>"
                + kaki();
        boolean e = p.isEmailTerverifikasi() && p.getEmail() != null
                && email.kirim(p.getEmail(), "Settlement QRIS " + TGL.format(hari) + " - VoKas", isi);
        boolean w = kirimWa(p, "VoKas - " + TGL.format(hari) + "\nOmzet " + rp(l.omzet()) + " (QRIS " + rp(l.omzetQris())
                + ", " + qris.size() + " trx)\nLaba " + rp(l.laba()) + "\nRincian lengkap sudah dikirim ke email.");
        return new Hasil(e, w);
    }

    // ---------------- laporan bulanan ----------------

    public Hasil kirimBulanan(UUID id, YearMonth bulan) {
        Pedagang p = transaksi.pedagang(id);
        LaporanService.Laporan l = laporan.buat(id, bulan.atDay(1), bulan.atEndOfMonth());
        SkorKurService.Rapor r = kur.hitung(id);
        String namaBulan = bulan.getMonth().getDisplayName(TextStyle.FULL, ID) + " " + bulan.getYear();

        StringBuilder harian = new StringBuilder();
        for (LaporanService.Harian h : l.harian()) {
            harian.append(tr(h.tanggal().format(DateTimeFormatter.ofPattern("d MMM", ID)), rp(h.masuk()) + " (QRIS " + rp(h.qris()) + ")",
                    rp(h.masuk() - h.keluar())));
        }
        if (l.harian().isEmpty()) harian.append("<tr><td colspan=3 style='padding:10px;color:#6B7663'>Belum ada transaksi bulan ini.</td></tr>");
        StringBuilder laris = new StringBuilder();
        l.terlaris().stream().limit(5).forEach(t -> laris.append(tr(t.nama(), t.jumlah() + " terjual", rp(t.total()))));
        if (l.terlaris().isEmpty()) laris.append("<tr><td colspan=3 style='padding:10px;color:#6B7663'>-</td></tr>");

        String isi = kepala("Laporan Bulanan", namaBulan, p)
                + kotakAngka(new String[][]{{"Omzet", rp(l.omzet())}, {"Lewat QRIS", rp(l.omzetQris())},
                {"Pengeluaran", rp(l.pengeluaran())}, {"Laba bersih", rp(l.laba())}})
                + "<p style='color:#23301C'>" + l.jumlahTransaksi() + " transaksi tercatat. Rapor Kesiapan KUR: <b>" + r.skor()
                + "/100 (" + r.status() + ")</b>.</p>"
                + "<h3 style='margin:24px 0 8px;color:#23301C'>Barang terlaris</h3>"
                + tabel(new String[]{"Barang", "Jumlah", "Total"}, laris.toString())
                + "<h3 style='margin:24px 0 8px;color:#23301C'>Rincian per hari</h3>"
                + tabel(new String[]{"Tanggal", "Pemasukan", "Laba"}, harian.toString())
                + "<p style='color:#6B7663;font-size:12px'>Rapor Kesiapan KUR adalah alat bantu, bukan keputusan kredit. Persetujuan KUR tetap dari BRI.</p>"
                + kaki();
        boolean e = p.isEmailTerverifikasi() && p.getEmail() != null
                && email.kirim(p.getEmail(), "Laporan " + namaBulan + " - VoKas", isi, List.of(
                new EmailService.Lampiran(EksporLaporanService.namaBerkas(p, bulan.atDay(1), bulan.atEndOfMonth(), "pdf"),
                        ekspor.pdf(id, bulan.atDay(1), bulan.atEndOfMonth()), "application/pdf"),
                new EmailService.Lampiran(EksporLaporanService.namaBerkas(p, bulan.atDay(1), bulan.atEndOfMonth(), "xlsx"),
                        ekspor.xlsx(id, bulan.atDay(1), bulan.atEndOfMonth()),
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")));
        boolean w = kirimWa(p, "VoKas - Laporan " + namaBulan + "\nOmzet " + rp(l.omzet()) + "\nLaba " + rp(l.laba())
                + "\nSkor KUR " + r.skor() + "/100\nLaporan lengkap ada di email.");
        return new Hasil(e, w);
    }

    // ---------------- WhatsApp singkat ----------------

    private boolean kirimWa(Pedagang p, String teks) {
        if (p.getNoWa() == null) return false;
        if (wa.aktif()) {
            wa.kirimTeks(p.getNoWa(), teks);
            return true;
        }
        if (twilio.aktif()) {
            twilio.kirimTeks(p.getNoWa(), teks);
            return true;
        }
        return false;
    }

    // ---------------- HTML ----------------

    private static String kepala(String judul, String periode, Pedagang p) {
        return "<div style='font-family:Arial,sans-serif;max-width:600px;margin:auto;background:#F1F5E8;padding:24px;border-radius:16px'>"
                + "<div style='background:#3F5A2A;color:#fff;padding:20px 24px;border-radius:12px'>"
                + "<div style='color:#F2C230;font-size:12px;letter-spacing:2px;font-weight:bold'>VOKAS</div>"
                + "<div style='font-size:22px;font-weight:bold;margin-top:4px'>" + esc(judul) + "</div>"
                + "<div style='color:#DFE5B5;font-size:14px'>" + esc(periode) + " &middot; "
                + esc(p.getNamaUsaha() == null ? p.getNama() : p.getNamaUsaha()) + "</div></div>";
    }

    private static String kotakAngka(String[][] isi) {
        StringBuilder sb = new StringBuilder("<table width='100%' cellspacing='8' style='margin-top:12px'><tr>");
        for (String[] a : isi) {
            sb.append("<td style='background:#fff;border-radius:10px;padding:12px'><div style='color:#6B7663;font-size:12px'>")
                    .append(a[0]).append("</div><div style='color:#3F5A2A;font-size:17px;font-weight:bold'>").append(a[1]).append("</div></td>");
        }
        return sb.append("</tr></table>").toString();
    }

    private static String tabel(String[] kolom, String baris) {
        StringBuilder sb = new StringBuilder("<table width='100%' cellspacing='0' style='background:#fff;border-radius:10px;font-size:13px'><tr>");
        for (String k : kolom) sb.append("<th align='left' style='padding:10px;background:#3F5A2A;color:#fff'>").append(k).append("</th>");
        return sb.append("</tr>").append(baris).append("</table>").toString();
    }

    private static String tr(String a, String b, String c) {
        return "<tr><td style='padding:8px 10px;border-top:1px solid #D9E0CC'>" + esc(a) + "</td><td style='padding:8px 10px;border-top:1px solid #D9E0CC'>"
                + esc(b) + "</td><td style='padding:8px 10px;border-top:1px solid #D9E0CC'>" + esc(c) + "</td></tr>";
    }

    private static String kaki() {
        return "<p style='color:#6B7663;font-size:11px;margin-top:24px'>Email otomatis dari VoKas. Atur pengiriman laporan di menu Profil aplikasi.</p></div>";
    }

    static String esc(String s) {
        return s == null ? "" : s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }

    static String rp(long n) {
        return "Rp" + NumberFormat.getIntegerInstance(ID).format(n);
    }
}
