package id.vokas.web;

import id.vokas.model.Pedagang;
import id.vokas.repo.PedagangRepo;
import id.vokas.service.EmailService;
import id.vokas.service.LaporanBerkalaService;
import id.vokas.service.TransaksiService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.util.HexFormat;
import java.util.Map;
import java.util.UUID;

/** Email pedagang: daftar + verifikasi kode OTP, atur laporan, dan kirim laporan manual (untuk demo). */
@RestController
@RequestMapping("/api/pedagang/{id}/email")
public class EmailController {

    private static final SecureRandom ACAK = new SecureRandom();
    /** Batasi tebakan kode: setelah 5 kali salah, kode dibatalkan. */
    private final java.util.concurrent.ConcurrentHashMap<UUID, Integer> salah = new java.util.concurrent.ConcurrentHashMap<>();

    private final PedagangRepo repo;
    private final TransaksiService transaksi;
    private final EmailService email;
    private final LaporanBerkalaService laporan;

    public EmailController(PedagangRepo repo, TransaksiService transaksi, EmailService email, LaporanBerkalaService laporan) {
        this.repo = repo;
        this.transaksi = transaksi;
        this.email = email;
        this.laporan = laporan;
    }

    public record AlamatEmail(@NotBlank @Email String email) {}
    public record Kode(@Pattern(regexp = "^\\d{6}$", message = "kode 6 angka") String kode) {}
    public record Pengaturan(boolean laporanEmail) {}

    /** Simpan email lalu kirim kode verifikasi 6 angka (berlaku 10 menit). */
    @PostMapping
    public Map<String, Object> daftar(@PathVariable UUID id, @Valid @RequestBody AlamatEmail b) {
        if (!email.aktif()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Pengiriman email belum diaktifkan di server");
        Pedagang p = transaksi.pedagang(id);
        String kode = String.format("%06d", ACAK.nextInt(1_000_000));
        p.setEmail(b.email().trim().toLowerCase());
        p.setEmailTerverifikasi(false);
        p.setEmailKodeHash(hash(id + ":" + kode));
        p.setEmailKodeSampai(OffsetDateTime.now().plusMinutes(10));
        repo.save(p);
        salah.remove(id);
        String html = "<div style='font-family:Arial,sans-serif;max-width:480px;margin:auto;background:#F1F5E8;padding:24px;border-radius:16px'>"
                + "<div style='color:#3F5A2A;font-weight:bold;font-size:18px'>Kode verifikasi VoKas</div>"
                + "<p>Masukkan kode ini di aplikasi untuk mengaktifkan laporan lewat email:</p>"
                + "<div style='font-size:32px;font-weight:bold;letter-spacing:8px;color:#3F5A2A'>" + kode + "</div>"
                + "<p style='color:#6B7663;font-size:12px'>Berlaku 10 menit. Abaikan email ini bila Anda tidak memintanya.</p></div>";
        if (!email.kirim(p.getEmail(), "Kode verifikasi VoKas: " + kode, html))
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Email gagal dikirim, cek alamatnya lalu coba lagi");
        return Map.of("terkirim", true, "email", p.getEmail());
    }

    @PostMapping("/verifikasi")
    public Pedagang verifikasi(@PathVariable UUID id, @Valid @RequestBody Kode b) {
        Pedagang p = transaksi.pedagang(id);
        if (p.getEmailKodeHash() == null || p.getEmailKodeSampai() == null || p.getEmailKodeSampai().isBefore(OffsetDateTime.now()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Kode sudah kedaluwarsa, minta kode baru");
        if (!MessageDigest.isEqual(p.getEmailKodeHash().getBytes(StandardCharsets.UTF_8),
                hash(id + ":" + b.kode()).getBytes(StandardCharsets.UTF_8)))
        {
            if (salah.merge(id, 1, Integer::sum) >= 5) {
                p.setEmailKodeHash(null);
                repo.save(p);
                salah.remove(id);
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Terlalu banyak salah, minta kode baru");
            }
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Kode salah");
        }
        salah.remove(id);
        p.setEmailTerverifikasi(true);
        p.setEmailKodeHash(null);
        p.setEmailKodeSampai(null);
        return repo.save(p);
    }

    @PatchMapping
    public Pedagang atur(@PathVariable UUID id, @RequestBody Pengaturan b) {
        Pedagang p = transaksi.pedagang(id);
        p.setLaporanEmail(b.laporanEmail());
        return repo.save(p);
    }

    /** Kirim laporan sekarang (untuk demo): jenis=harian (hari ini) atau bulanan (bulan berjalan). */
    @PostMapping("/kirim-laporan")
    public LaporanBerkalaService.Hasil kirimSekarang(@PathVariable UUID id, @RequestParam(defaultValue = "harian") String jenis) {
        Pedagang p = transaksi.pedagang(id);
        if (!p.isEmailTerverifikasi()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Verifikasi email dulu");
        return "bulanan".equalsIgnoreCase(jenis)
                ? laporan.kirimBulanan(id, YearMonth.from(transaksi.hariIni()))
                : laporan.kirimHarian(id, transaksi.hariIni());
    }

    private static String hash(String s) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
