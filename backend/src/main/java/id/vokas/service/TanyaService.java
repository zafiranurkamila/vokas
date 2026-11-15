package id.vokas.service;

import id.vokas.model.Pedagang;
import id.vokas.parser.PembacaGemini;
import org.springframework.stereotype.Service;

import java.text.NumberFormat;
import java.time.LocalDate;
import java.time.format.TextStyle;
import java.util.Locale;
import java.util.UUID;

/**
 * Tanya AI: asisten yang menjawab pertanyaan pedagang tentang usahanya sendiri.
 * Angka dihitung di backend dari data asli, lalu diberikan ke Gemini sebagai konteks,
 * supaya AI tidak mengarang angka.
 */
@Service
public class TanyaService {

    private static final Locale ID = new Locale("id", "ID");

    private final TransaksiService transaksi;
    private final LaporanService laporan;
    private final SkorKurService kur;
    private final PembacaGemini gemini;

    public TanyaService(TransaksiService transaksi, LaporanService laporan, SkorKurService kur, PembacaGemini gemini) {
        this.transaksi = transaksi;
        this.laporan = laporan;
        this.kur = kur;
        this.gemini = gemini;
    }

    public PembacaGemini.Jawaban tanya(UUID pedagangId, String pertanyaan) {
        Pedagang p = transaksi.pedagang(pedagangId);
        return gemini.jawab(instruksi(p, konteks(pedagangId)), pertanyaan);
    }

    String konteks(UUID id) {
        LocalDate hari = transaksi.hariIni();
        LaporanService.Laporan h = laporan.buat(id, hari, hari);
        LaporanService.Laporan m = laporan.buat(id, hari.minusDays(6), hari);
        LaporanService.Laporan b = laporan.buat(id, hari.minusDays(29), hari);
        SkorKurService.Rapor r = kur.hitung(id);

        StringBuilder sb = new StringBuilder();
        sb.append("Tanggal hari ini: ").append(hari).append(" (")
                .append(hari.getDayOfWeek().getDisplayName(TextStyle.FULL, ID)).append(")\n");
        ringkas(sb, "Hari ini", h);
        ringkas(sb, "7 hari terakhir", m);
        ringkas(sb, "30 hari terakhir", b);
        sb.append("Barang terlaris 30 hari: ");
        if (b.terlaris().isEmpty()) sb.append("belum ada");
        b.terlaris().forEach(t -> sb.append(t.nama()).append(" (").append(t.jumlah()).append(" terjual, ")
                .append(rp(t.total())).append("); "));
        sb.append("\nOmzet per hari 30 hari terakhir: ");
        b.harian().forEach(x -> sb.append(x.tanggal()).append(" ")
                .append(x.tanggal().getDayOfWeek().getDisplayName(TextStyle.SHORT, ID)).append("=")
                .append(rp(x.masuk())).append(", "));
        sb.append("\nRapor Kesiapan KUR: ").append(r.skor()).append("/100 (").append(r.status()).append(")\n");
        r.kriteria().forEach(k -> sb.append("- ").append(k.nama()).append(": ").append(k.poin()).append("/")
                .append(k.bobot()).append(", ").append(k.keterangan()).append("\n"));
        return sb.toString();
    }

    private static void ringkas(StringBuilder sb, String label, LaporanService.Laporan l) {
        sb.append(label).append(": omzet ").append(rp(l.omzet())).append(", pengeluaran ").append(rp(l.pengeluaran()))
                .append(", laba ").append(rp(l.laba())).append(", lewat QRIS ").append(rp(l.omzetQris()))
                .append(", ").append(l.jumlahTransaksi()).append(" transaksi\n");
    }

    private static String instruksi(Pedagang p, String data) {
        return """
                Kamu asisten keuangan VoKas untuk pedagang kecil Indonesia. Nama pedagang: %s. Usaha: %s.
                Jawab dalam bahasa Indonesia sehari-hari yang ramah dan singkat (maksimal 5 kalimat atau 5 poin).
                Aturan:
                - Untuk angka, pakai HANYA data di bawah. Jangan mengarang angka. Bila datanya tidak ada, bilang belum ada data.
                - Tulis rupiah seperti Rp60.000.
                - KUR adalah Kredit Usaha Rakyat, pinjaman modal bersubsidi pemerintah yang disalurkan BRI.
                  Rapor Kesiapan KUR hanya alat bantu, bukan keputusan kredit; persetujuan tetap dari BRI.
                - Jangan memberi saran investasi saham/kripto. Fokus ke usaha, pencatatan, QRIS, dan KUR.
                - Jangan pakai format markdown tebal atau judul; boleh poin dengan tanda "-".

                DATA USAHA:
                %s
                """.formatted(p.getNama(), p.getNamaUsaha() == null ? "-" : p.getNamaUsaha(), data);
    }

    private static String rp(long n) {
        return "Rp" + NumberFormat.getIntegerInstance(ID).format(n);
    }
}
