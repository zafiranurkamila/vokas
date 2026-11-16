package id.vokas.service;

import id.vokas.config.VokasProperties;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;

/**
 * Kirim email HTML. Dua jalur:
 * 1. Brevo HTTP API (BREVO_API_KEY) lewat HTTPS. Dipakai di Render gratis, yang memblokir port SMTP keluar.
 * 2. SMTP biasa (SMTP_HOST) untuk server lain atau pengembangan lokal.
 */
@Service
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    public record Lampiran(String nama, byte[] isi, String mime) {}

    private final ObjectProvider<JavaMailSender> pengirim;
    private final VokasProperties.Mail cfg;
    private final String host;
    private final String brevoKey;
    private final RestClient http;

    public EmailService(ObjectProvider<JavaMailSender> pengirim, VokasProperties props,
                        @Value("${spring.mail.host:}") String host, @Value("${vokas.mail.brevo-api-key:}") String brevoKey) {
        this.pengirim = pengirim;
        this.cfg = props.mail();
        this.host = host;
        this.brevoKey = brevoKey;
        SimpleClientHttpRequestFactory f = new SimpleClientHttpRequestFactory();
        f.setConnectTimeout(10_000);
        f.setReadTimeout(30_000);
        this.http = RestClient.builder().requestFactory(f).build();
    }

    private boolean adaPengirim() { return cfg != null && cfg.from() != null && !cfg.from().isBlank(); }
    private boolean lewatBrevo() { return brevoKey != null && !brevoKey.isBlank(); }
    private boolean lewatSmtp() { return host != null && !host.isBlank() && pengirim.getIfAvailable() != null; }

    public boolean aktif() { return adaPengirim() && (lewatBrevo() || lewatSmtp()); }

    public boolean kirim(String ke, String judul, String html) {
        return kirim(ke, judul, html, List.of());
    }

    /** @return true bila terkirim */
    public boolean kirim(String ke, String judul, String html, List<Lampiran> lampiran) {
        if (!aktif()) {
            log.info("Email belum diatur, \"{}\" ke {} tidak dikirim", judul, ke);
            return false;
        }
        String nama = cfg.namaPengirim() == null || cfg.namaPengirim().isBlank() ? "VoKas" : cfg.namaPengirim();
        try {
            if (lewatBrevo()) {
                List<Map<String, String>> lamp = new ArrayList<>();
                for (Lampiran l : lampiran)
                    lamp.add(Map.of("name", l.nama(), "content", Base64.getEncoder().encodeToString(l.isi())));
                var body = new java.util.LinkedHashMap<String, Object>();
                body.put("sender", Map.of("name", nama, "email", cfg.from()));
                body.put("to", List.of(Map.of("email", ke)));
                body.put("subject", judul);
                body.put("htmlContent", html);
                if (!lamp.isEmpty()) body.put("attachment", lamp);
                http.post().uri("https://api.brevo.com/v3/smtp/email")
                        .header("api-key", brevoKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .accept(MediaType.APPLICATION_JSON)
                        .body(body).retrieve().toBodilessEntity();
                return true;
            }
            JavaMailSender s = pengirim.getObject();
            MimeMessage m = s.createMimeMessage();
            MimeMessageHelper h = new MimeMessageHelper(m, true, StandardCharsets.UTF_8.name());
            h.setFrom(new InternetAddress(cfg.from(), nama, "UTF-8"));
            h.setTo(ke);
            h.setSubject(judul);
            h.setText(html, true);
            for (Lampiran l : lampiran) h.addAttachment(l.nama(), new ByteArrayResource(l.isi()), l.mime());
            s.send(m);
            return true;
        } catch (Exception e) {
            log.warn("Gagal kirim email ke {}: {}", ke, e.getMessage());
            return false;
        }
    }
}
