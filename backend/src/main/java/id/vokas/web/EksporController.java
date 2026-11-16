package id.vokas.web;

import id.vokas.model.Pedagang;
import id.vokas.service.EksporLaporanService;
import id.vokas.service.EmailService;
import id.vokas.service.TransaksiService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/** Ekspor laporan (PDF / Excel) dan kirim laporan ke email beserta lampirannya. */
@RestController
@RequestMapping("/api/pedagang/{id}/laporan")
public class EksporController {

    static final String MIME_XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    private final TransaksiService transaksi;
    private final EksporLaporanService ekspor;
    private final EmailService email;

    public EksporController(TransaksiService transaksi, EksporLaporanService ekspor, EmailService email) {
        this.transaksi = transaksi;
        this.ekspor = ekspor;
        this.email = email;
    }

    private LocalDate[] periode(LocalDate dari, LocalDate sampai) {
        LocalDate s = sampai != null ? sampai : transaksi.hariIni();
        LocalDate d = dari != null ? dari : s.minusDays(29);
        if (d.isAfter(s) || d.isBefore(s.minusDays(400)))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Periode laporan tidak valid (maksimal setahun)");
        return new LocalDate[]{d, s};
    }

    @GetMapping("/ekspor")
    public ResponseEntity<byte[]> unduh(@PathVariable UUID id, @RequestParam(defaultValue = "pdf") String format,
                                        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dari,
                                        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate sampai) {
        LocalDate[] p = periode(dari, sampai);
        Pedagang pd = transaksi.pedagang(id);
        boolean excel = "xlsx".equalsIgnoreCase(format) || "excel".equalsIgnoreCase(format);
        byte[] isi = excel ? ekspor.xlsx(id, p[0], p[1]) : ekspor.pdf(id, p[0], p[1]);
        String nama = EksporLaporanService.namaBerkas(pd, p[0], p[1], excel ? "xlsx" : "pdf");
        return ResponseEntity.ok()
                .contentType(excel ? MediaType.parseMediaType(MIME_XLSX) : MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment().filename(nama).build().toString())
                .header(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, HttpHeaders.CONTENT_DISPOSITION)
                .body(isi);
    }

    /** Kirim laporan periode tertentu ke email terverifikasi, dengan lampiran PDF dan Excel. */
    @PostMapping("/kirim-email")
    public Map<String, Object> kirimEmail(@PathVariable UUID id,
                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dari,
                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate sampai) {
        LocalDate[] p = periode(dari, sampai);
        Pedagang pd = transaksi.pedagang(id);
        if (pd.getEmail() == null || !pd.isEmailTerverifikasi())
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Tambahkan dan verifikasi email dulu");
        if (!email.aktif()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Pengiriman email belum aktif di server");
        DateTimeFormatter f = DateTimeFormatter.ofPattern("d MMM yyyy", new Locale("id", "ID"));
        String periode = f.format(p[0]) + " - " + f.format(p[1]);
        String html = "<div style='font-family:Arial,sans-serif;max-width:560px;margin:auto;background:#F1F5E8;padding:24px;border-radius:16px'>"
                + "<div style='background:#3F5A2A;color:#fff;padding:18px 22px;border-radius:12px'>"
                + "<div style='color:#F2C230;font-size:12px;letter-spacing:2px;font-weight:bold'>VOKAS</div>"
                + "<div style='font-size:20px;font-weight:bold'>Laporan Keuangan Usaha</div>"
                + "<div style='color:#DFE5B5'>" + periode + "</div></div>"
                + "<p>Halo " + esc(pd.getNama()) + ", laporan usaha Anda terlampir:</p>"
                + "<ul><li><b>PDF</b>: ringkasan, barang terlaris, per hari, dan rincian transaksi.</li>"
                + "<li><b>Excel</b>: data yang sama untuk diolah atau dibawa saat mengajukan KUR.</li></ul>"
                + "<p style='color:#6B7663;font-size:12px'>Email otomatis dari VoKas.</p></div>";
        boolean ok = email.kirim(pd.getEmail(), "Laporan VoKas " + periode, html, List.of(
                new EmailService.Lampiran(EksporLaporanService.namaBerkas(pd, p[0], p[1], "pdf"), ekspor.pdf(id, p[0], p[1]), "application/pdf"),
                new EmailService.Lampiran(EksporLaporanService.namaBerkas(pd, p[0], p[1], "xlsx"), ekspor.xlsx(id, p[0], p[1]), MIME_XLSX)));
        if (!ok) throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Email gagal dikirim, coba lagi sebentar");
        return Map.of("terkirim", true, "email", pd.getEmail());
    }

    private static String esc(String s) {
        return s == null ? "" : s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }
}
