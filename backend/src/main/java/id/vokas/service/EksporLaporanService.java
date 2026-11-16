package id.vokas.service;

import com.lowagie.text.*;
import com.lowagie.text.pdf.PdfPCell;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfWriter;
import id.vokas.model.Jenis;
import id.vokas.model.Pedagang;
import id.vokas.model.Transaksi;
import org.dhatim.fastexcel.Workbook;
import org.dhatim.fastexcel.Worksheet;
import org.springframework.stereotype.Service;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.text.NumberFormat;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/** Ekspor laporan keuangan pedagang ke PDF (rapi untuk dibaca/dibagikan) dan Excel (.xlsx, untuk diolah). */
@Service
public class EksporLaporanService {

    private static final Locale ID = new Locale("id", "ID");
    private static final DateTimeFormatter TGL = DateTimeFormatter.ofPattern("d MMM yyyy", ID);
    private static final DateTimeFormatter JAM = DateTimeFormatter.ofPattern("HH:mm");
    private static final ZoneId WIB = ZoneId.of("Asia/Jakarta");
    private static final Color HIJAU = new Color(0x3F, 0x5A, 0x2A);
    private static final Color KREM = new Color(0xF1, 0xF5, 0xE8);
    private static final Color REDUP = new Color(0x6B, 0x76, 0x63);

    private final TransaksiService transaksi;
    private final LaporanService laporan;
    private final SkorKurService kur;

    public EksporLaporanService(TransaksiService transaksi, LaporanService laporan, SkorKurService kur) {
        this.transaksi = transaksi;
        this.laporan = laporan;
        this.kur = kur;
    }

    public static String namaBerkas(Pedagang p, LocalDate dari, LocalDate sampai, String ext) {
        String usaha = (p.getNamaUsaha() == null || p.getNamaUsaha().isBlank() ? p.getNama() : p.getNamaUsaha())
                .replaceAll("[^A-Za-z0-9]+", "_").replaceAll("^_|_$", "");
        return "Laporan_VoKas_" + usaha + "_" + dari + "_sd_" + sampai + "." + ext;
    }

    // ---------------- PDF ----------------

    public byte[] pdf(UUID id, LocalDate dari, LocalDate sampai) {
        Pedagang p = transaksi.pedagang(id);
        LaporanService.Laporan l = laporan.buat(id, dari, sampai);
        List<Transaksi> daftar = transaksi.daftar(id, dari, sampai);
        SkorKurService.Rapor r = kur.hitung(id);

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        Document doc = new Document(PageSize.A4, 36, 36, 36, 40);
        PdfWriter.getInstance(doc, out);
        doc.open();
        Font judul = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 18, HIJAU);
        Font sub = FontFactory.getFont(FontFactory.HELVETICA, 10, REDUP);
        Font tebal = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 10, Color.BLACK);
        Font biasa = FontFactory.getFont(FontFactory.HELVETICA, 9, Color.BLACK);
        Font putih = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9, Color.WHITE);

        doc.add(new Paragraph("Laporan Keuangan Usaha", judul));
        doc.add(new Paragraph((p.getNamaUsaha() == null ? p.getNama() : p.getNamaUsaha()) + "  |  "
                + TGL.format(dari) + " - " + TGL.format(sampai), sub));
        doc.add(new Paragraph(" "));

        PdfPTable ringkas = new PdfPTable(4);
        ringkas.setWidthPercentage(100);
        for (String[] a : new String[][]{{"Omzet", rp(l.omzet())}, {"Lewat QRIS", rp(l.omzetQris())},
                {"Pengeluaran", rp(l.pengeluaran())}, {"Laba bersih", rp(l.laba())}}) {
            PdfPCell c = new PdfPCell();
            c.setBackgroundColor(KREM);
            c.setBorderColor(Color.WHITE);
            c.setPadding(8);
            c.addElement(new Paragraph(a[0], sub));
            c.addElement(new Paragraph(a[1], FontFactory.getFont(FontFactory.HELVETICA_BOLD, 12, HIJAU)));
            ringkas.addCell(c);
        }
        doc.add(ringkas);
        doc.add(new Paragraph(l.jumlahTransaksi() + " transaksi  |  Rapor Kesiapan KUR " + r.skor() + "/100 (" + r.status() + ")", sub));

        doc.add(new Paragraph(" "));
        doc.add(bagian("Barang terlaris", tebal));
        PdfPTable laris = tabel(new float[]{3, 1.2f, 1.6f}, new String[]{"Barang", "Jumlah", "Total"}, putih);
        l.terlaris().stream().limit(5).forEach(t -> baris(laris, biasa, t.nama(), String.valueOf(t.jumlah()), rp(t.total())));
        if (l.terlaris().isEmpty()) baris(laris, biasa, "-", "-", "-");
        doc.add(laris);

        doc.add(new Paragraph(" "));
        doc.add(bagian("Ringkasan per hari", tebal));
        PdfPTable harian = tabel(new float[]{1.4f, 1.6f, 1.6f, 1.6f, 1.6f}, new String[]{"Tanggal", "Pemasukan", "QRIS", "Pengeluaran", "Laba"}, putih);
        for (LaporanService.Harian h : l.harian())
            baris(harian, biasa, TGL.format(h.tanggal()), rp(h.masuk()), rp(h.qris()), rp(h.keluar()), rp(h.masuk() - h.keluar()));
        if (l.harian().isEmpty()) baris(harian, biasa, "-", "-", "-", "-", "-");
        doc.add(harian);

        doc.add(new Paragraph(" "));
        doc.add(bagian("Rincian transaksi", tebal));
        PdfPTable rinci = tabel(new float[]{1.3f, 0.8f, 2.6f, 1, 1.6f}, new String[]{"Tanggal", "Jam", "Keterangan", "Metode", "Nominal"}, putih);
        for (Transaksi t : daftar) {
            String jam = t.getDibuat() == null ? "-" : t.getDibuat().atZoneSameInstant(WIB).format(JAM);
            String nom = (t.getJenis() == Jenis.MASUK ? "+" : "-") + rp(t.getTotal());
            baris(rinci, biasa, TGL.format(t.getTanggal()), jam, t.getNamaItem(), String.valueOf(t.getMetode()), nom);
        }
        if (daftar.isEmpty()) baris(rinci, biasa, "-", "-", "-", "-", "-");
        doc.add(rinci);

        doc.add(new Paragraph(" "));
        doc.add(new Paragraph("Dibuat otomatis oleh VoKas. Rapor Kesiapan KUR adalah alat bantu, bukan keputusan kredit; "
                + "persetujuan KUR tetap dari BRI.", FontFactory.getFont(FontFactory.HELVETICA_OBLIQUE, 8, REDUP)));
        doc.close();
        return out.toByteArray();
    }

    private static Paragraph bagian(String teks, Font f) {
        Paragraph p = new Paragraph(teks, f);
        p.setSpacingBefore(6);
        p.setSpacingAfter(6);
        return p;
    }

    private static PdfPTable tabel(float[] lebar, String[] kolom, Font f) {
        PdfPTable t = new PdfPTable(lebar);
        t.setWidthPercentage(100);
        t.setHeaderRows(1);
        for (String k : kolom) {
            PdfPCell c = new PdfPCell(new Phrase(k, f));
            c.setBackgroundColor(HIJAU);
            c.setBorderColor(HIJAU);
            c.setPadding(5);
            t.addCell(c);
        }
        return t;
    }

    private static void baris(PdfPTable t, Font f, String... isi) {
        for (String s : isi) {
            PdfPCell c = new PdfPCell(new Phrase(s == null ? "" : s, f));
            c.setBorderColor(new Color(0xD9, 0xE0, 0xCC));
            c.setPadding(4);
            t.addCell(c);
        }
    }

    // ---------------- Excel ----------------

    public byte[] xlsx(UUID id, LocalDate dari, LocalDate sampai) {
        Pedagang p = transaksi.pedagang(id);
        LaporanService.Laporan l = laporan.buat(id, dari, sampai);
        List<Transaksi> daftar = transaksi.daftar(id, dari, sampai);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try {
            Workbook wb = new Workbook(out, "VoKas", "1.0");

            Worksheet r = wb.newWorksheet("Ringkasan");
            r.value(0, 0, "Laporan Keuangan Usaha - VoKas");
            r.style(0, 0).bold().fontSize(14).set();
            r.value(1, 0, p.getNamaUsaha() == null ? p.getNama() : p.getNamaUsaha());
            r.value(2, 0, "Periode");
            r.value(2, 1, TGL.format(dari) + " - " + TGL.format(sampai));
            String[][] angka = {{"Omzet"}, {"Lewat QRIS"}, {"Pengeluaran"}, {"Laba bersih"}, {"Jumlah transaksi"}};
            long[] nilai = {l.omzet(), l.omzetQris(), l.pengeluaran(), l.laba(), l.jumlahTransaksi()};
            for (int i = 0; i < angka.length; i++) {
                r.value(4 + i, 0, angka[i][0]);
                r.value(4 + i, 1, nilai[i]);
                if (i < 4) r.style(4 + i, 1).format("\"Rp\"#,##0").set();
            }
            r.width(0, 22);
            r.width(1, 26);

            Worksheet h = wb.newWorksheet("Per Hari");
            judulKolom(h, "Tanggal", "Pemasukan", "QRIS", "Pengeluaran", "Laba");
            int b = 1;
            for (LaporanService.Harian x : l.harian()) {
                h.value(b, 0, x.tanggal());
                h.style(b, 0).format("dd/mm/yyyy").set();
                h.value(b, 1, x.masuk());
                h.value(b, 2, x.qris());
                h.value(b, 3, x.keluar());
                h.value(b, 4, x.masuk() - x.keluar());
                for (int c = 1; c <= 4; c++) h.style(b, c).format("#,##0").set();
                b++;
            }
            for (int c = 0; c < 5; c++) h.width(c, 16);

            Worksheet t = wb.newWorksheet("Transaksi");
            judulKolom(t, "Tanggal", "Jam", "Jenis", "Keterangan", "Jumlah", "Satuan", "Harga satuan", "Total", "Metode", "Sumber");
            b = 1;
            for (Transaksi x : daftar) {
                t.value(b, 0, x.getTanggal());
                t.style(b, 0).format("dd/mm/yyyy").set();
                t.value(b, 1, x.getDibuat() == null ? "" : x.getDibuat().atZoneSameInstant(WIB).format(JAM));
                t.value(b, 2, x.getJenis() == Jenis.MASUK ? "Masuk" : "Keluar");
                t.value(b, 3, x.getNamaItem());
                if (x.getJumlah() != null) t.value(b, 4, x.getJumlah());
                t.value(b, 5, x.getSatuan());
                if (x.getHargaSatuan() != null) t.value(b, 6, x.getHargaSatuan());
                t.value(b, 7, x.getTotal());
                t.style(b, 7).format("#,##0").set();
                t.value(b, 8, String.valueOf(x.getMetode()));
                t.value(b, 9, String.valueOf(x.getSumber()));
                b++;
            }
            int[] lebar = {12, 7, 8, 26, 8, 10, 13, 13, 9, 9};
            for (int c = 0; c < lebar.length; c++) t.width(c, lebar[c]);
            wb.finish();
        } catch (IOException e) {
            throw new IllegalStateException("Gagal membuat Excel", e);
        }
        return out.toByteArray();
    }

    private static void judulKolom(Worksheet w, String... kolom) {
        for (int c = 0; c < kolom.length; c++) {
            w.value(0, c, kolom[c]);
            w.style(0, c).bold().fontColor("FFFFFF").fillColor("3F5A2A").set();
        }
        w.freezePane(0, 1);
    }

    static String rp(long n) {
        return "Rp" + NumberFormat.getIntegerInstance(ID).format(n);
    }
}
