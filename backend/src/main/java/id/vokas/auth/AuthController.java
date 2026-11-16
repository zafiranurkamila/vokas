package id.vokas.auth;

import id.vokas.model.Pedagang;
import id.vokas.repo.PedagangRepo;
import id.vokas.service.EmailService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Auth VoKas:
 * - daftar: data usaha + email, dibuktikan dengan kode yang dikirim ke email (atau akun Google), lalu PIN;
 * - masuk: email ATAU nomor WA + PIN (PIN di-hash PBKDF2 di server; 5x salah = dikunci 15 menit);
 * - lupa PIN: kode ke email terdaftar (atau Google), lalu PIN baru;
 * - Google: masuk langsung bila akunnya sudah terdaftar, atau mulai daftar dengan nama dan email dari Google.
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    public static final String DAFTAR = "DAFTAR";
    public static final String LUPA_PIN = "LUPA_PIN";
    /** Kode WA demo untuk akun lama yang belum punya email (OTP WhatsApp belum aktif). */
    public static final String KODE_DEMO_WA = "123456";

    private static final SecureRandom ACAK = new SecureRandom();
    private static final DateTimeFormatter JAM = DateTimeFormatter.ofPattern("HH:mm");

    private final PedagangRepo pedagang;
    private final KodeOtpRepo kode;
    private final EmailService email;
    private final GoogleVerifier google;

    public AuthController(PedagangRepo pedagang, KodeOtpRepo kode, EmailService email, GoogleVerifier google) {
        this.pedagang = pedagang;
        this.kode = kode;
        this.email = email;
        this.google = google;
    }

    // ---------------- kode email ----------------

    public record MintaKode(@NotBlank String identitas, @NotBlank String keperluan) {}

    /** Kirim kode 6 angka. DAFTAR: identitas = email baru. LUPA_PIN: identitas = email atau nomor WA terdaftar. */
    @PostMapping("/kode")
    @Transactional
    public Map<String, Object> kirimKode(@Valid @RequestBody MintaKode b) {
        if (!email.aktif()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Pengiriman email belum aktif di server");
        String keperluan = b.keperluan().toUpperCase();
        String tujuan;
        if (DAFTAR.equals(keperluan)) {
            tujuan = normalEmail(b.identitas());
            if (pedagang.findByEmailIgnoreCase(tujuan).isPresent())
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Email sudah terdaftar, silakan masuk");
        } else if (LUPA_PIN.equals(keperluan)) {
            Pedagang p = cari(b.identitas());
            if (p.getEmail() == null)
                throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "AKUN_TANPA_EMAIL");
            tujuan = p.getEmail();
        } else {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Keperluan tidak dikenal");
        }
        if (kode.hitungSejak(tujuan, OffsetDateTime.now().minusHours(1)) >= 5)
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "Terlalu sering meminta kode, coba lagi nanti");

        String k = String.format("%06d", ACAK.nextInt(1_000_000));
        kode.save(new KodeOtp(tujuan, keperluan, hashKode(tujuan, keperluan, k), OffsetDateTime.now().plusMinutes(10)));
        String judul = DAFTAR.equals(keperluan) ? "Kode pendaftaran VoKas: " + k : "Kode atur ulang PIN VoKas: " + k;
        String ket = DAFTAR.equals(keperluan) ? "untuk menyelesaikan pendaftaran VoKas" : "untuk membuat PIN baru VoKas";
        String html = "<div style='font-family:Arial,sans-serif;max-width:480px;margin:auto;background:#F1F5E8;padding:24px;border-radius:16px'>"
                + "<div style='color:#3F5A2A;font-weight:bold;font-size:18px'>Kode verifikasi VoKas</div>"
                + "<p>Masukkan kode ini " + ket + ":</p>"
                + "<div style='font-size:32px;font-weight:bold;letter-spacing:8px;color:#3F5A2A'>" + k + "</div>"
                + "<p style='color:#6B7663;font-size:12px'>Berlaku 10 menit. Jangan berikan kode ini kepada siapa pun, "
                + "termasuk yang mengaku dari VoKas atau BRI. Abaikan email ini bila Anda tidak memintanya.</p></div>";
        if (!email.kirim(tujuan, judul, html))
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Email gagal dikirim, cek alamatnya lalu coba lagi");
        return Map.of("terkirim", true, "email", samarkan(tujuan));
    }

    // ---------------- daftar ----------------

    public record Daftar(@NotBlank String nama, String namaUsaha,
                         @Pattern(regexp = "^62\\d{8,13}$", message = "format 62xxxxxxxxxx") String noWa,
                         String email, String kode, String googleIdToken, String googleAccessToken,
                         @Pattern(regexp = "^\\d{6}$", message = "PIN 6 angka") String pin) {}

    @PostMapping("/daftar")
    @Transactional
    public Pedagang daftar(@Valid @RequestBody Daftar b) {
        if (pedagang.findByNoWa(b.noWa()).isPresent())
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Nomor WA sudah terdaftar, silakan masuk");
        String mail;
        String sub = null;
        if (b.googleIdToken() != null || b.googleAccessToken() != null) {
            GoogleVerifier.AkunGoogle g = google.periksa(b.googleIdToken(), b.googleAccessToken());
            mail = g.email();
            sub = g.sub();
        } else {
            mail = normalEmail(b.email());
            cekKode(mail, DAFTAR, b.kode());
        }
        if (pedagang.findByEmailIgnoreCase(mail).isPresent())
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email sudah terdaftar, silakan masuk");
        cekPinKuat(b.pin());
        Pedagang p = new Pedagang();
        p.setNama(b.nama().trim());
        p.setNamaUsaha(b.namaUsaha() == null ? null : b.namaUsaha().trim());
        p.setNoWa(b.noWa());
        p.setEmail(mail);
        p.setEmailTerverifikasi(true);
        p.setGoogleSub(sub);
        p.setPinHash(PinHasher.hash(b.pin()));
        return pedagang.save(p);
    }

    // ---------------- masuk ----------------

    public record Masuk(@NotBlank String identitas, @Pattern(regexp = "^\\d{6}$", message = "PIN 6 angka") String pin) {}

    @PostMapping("/masuk")
    @Transactional
    public Pedagang masuk(@Valid @RequestBody Masuk b) {
        Pedagang p = cari(b.identitas());
        if (p.getKunciSampai() != null && p.getKunciSampai().isAfter(OffsetDateTime.now()))
            throw new ResponseStatusException(HttpStatus.LOCKED, "PIN salah 5 kali. Coba lagi pukul "
                    + p.getKunciSampai().atZoneSameInstant(ZoneId.of("Asia/Jakarta")).format(JAM) + " WIB atau pakai Lupa PIN");
        if (p.getPinHash() == null)
            throw new ResponseStatusException(HttpStatus.CONFLICT, "PIN_BELUM_ADA");
        if (!PinHasher.cocok(b.pin(), p.getPinHash())) {
            p.setGagalPin(p.getGagalPin() + 1);
            if (p.getGagalPin() >= 5) {
                p.setGagalPin(0);
                p.setKunciSampai(OffsetDateTime.now().plusMinutes(15));
            }
            pedagang.save(p);
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "PIN salah");
        }
        p.setGagalPin(0);
        p.setKunciSampai(null);
        return pedagang.save(p);
    }

    // ---------------- lupa PIN ----------------

    public record AturPin(@NotBlank String identitas, String kode, String googleIdToken, String googleAccessToken,
                          @Pattern(regexp = "^\\d{6}$", message = "PIN 6 angka") String pinBaru) {}

    @PostMapping("/lupa-pin")
    @Transactional
    public Pedagang lupaPin(@Valid @RequestBody AturPin b) {
        Pedagang p = cari(b.identitas());
        if (b.googleIdToken() != null || b.googleAccessToken() != null) {
            GoogleVerifier.AkunGoogle g = google.periksa(b.googleIdToken(), b.googleAccessToken());
            if (!g.email().equalsIgnoreCase(p.getEmail() == null ? "" : p.getEmail()) && !g.sub().equals(p.getGoogleSub()))
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Akun Google ini bukan milik akun VoKas tersebut");
        } else if (p.getEmail() != null) {
            cekKode(p.getEmail(), LUPA_PIN, b.kode());
        } else if (!KODE_DEMO_WA.equals(b.kode())) {
            // akun lama tanpa email: OTP WhatsApp belum aktif, jadi memakai kode demo
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Kode salah");
        }
        cekPinKuat(b.pinBaru());
        p.setPinHash(PinHasher.hash(b.pinBaru()));
        p.setGagalPin(0);
        p.setKunciSampai(null);
        return pedagang.save(p);
    }

    // ---------------- Google ----------------

    public record TokenGoogle(String idToken, String accessToken) {}

    @PostMapping("/google")
    @Transactional
    public Map<String, Object> google(@RequestBody TokenGoogle b) {
        GoogleVerifier.AkunGoogle g = google.periksa(b.idToken(), b.accessToken());
        Optional<Pedagang> ada = pedagang.findByGoogleSub(g.sub()).or(() -> pedagang.findByEmailIgnoreCase(g.email()));
        Map<String, Object> out = new LinkedHashMap<>();
        if (ada.isPresent()) {
            Pedagang p = ada.get();
            if (p.getGoogleSub() == null) p.setGoogleSub(g.sub());
            p.setEmailTerverifikasi(true);
            out.put("terdaftar", true);
            out.put("pedagang", pedagang.save(p));
        } else {
            out.put("terdaftar", false);
            out.put("email", g.email());
            out.put("nama", g.nama() == null ? "" : g.nama());
        }
        return out;
    }

    /** Info login Google untuk aplikasi (client ID tidak rahasia). */
    @GetMapping("/info")
    public Map<String, Object> info() {
        return Map.of("google", google.aktif(), "email", email.aktif());
    }

    // ---------------- pembantu ----------------

    private Pedagang cari(String identitas) {
        String s = identitas.trim();
        Optional<Pedagang> p;
        if (s.contains("@")) {
            p = pedagang.findByEmailIgnoreCase(s.toLowerCase());
        } else {
            String d = s.replaceAll("\\D", "");
            if (d.startsWith("0")) d = "62" + d.substring(1);
            if (d.startsWith("8")) d = "62" + d;
            p = pedagang.findByNoWa(d);
        }
        return p.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Akun belum terdaftar"));
    }

    private void cekKode(String mail, String keperluan, String k) {
        KodeOtp o = kode.findFirstByEmailIgnoreCaseAndKeperluanOrderByDibuatDesc(mail, keperluan)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Minta kode dulu"));
        if (o.getKedaluwarsa().isBefore(OffsetDateTime.now()) || o.getPercobaan() >= 5)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Kode kedaluwarsa, minta kode baru");
        boolean ok = k != null && MessageDigest.isEqual(o.getKodeHash().getBytes(StandardCharsets.UTF_8),
                hashKode(mail, keperluan, k.trim()).getBytes(StandardCharsets.UTF_8));
        if (!ok) {
            o.setPercobaan(o.getPercobaan() + 1);
            kode.save(o);
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Kode salah");
        }
        o.setKedaluwarsa(OffsetDateTime.now());   // sekali pakai
        kode.save(o);
    }

    private static void cekPinKuat(String pin) {
        if (pin == null || !pin.matches("\\d{6}") || pin.matches("(\\d)\\1{5}")
                || "0123456789".contains(pin) || "9876543210".contains(pin))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "PIN terlalu mudah ditebak");
    }

    private static String normalEmail(String e) {
        if (e == null || !e.trim().matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Format email belum benar");
        return e.trim().toLowerCase();
    }

    static String samarkan(String e) {
        int at = e.indexOf('@');
        if (at <= 1) return e;
        return e.charAt(0) + "*".repeat(Math.min(5, at - 1)) + e.substring(at);
    }

    private static String hashKode(String mail, String keperluan, String k) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest((mail.toLowerCase() + "|" + keperluan + "|" + k).getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
