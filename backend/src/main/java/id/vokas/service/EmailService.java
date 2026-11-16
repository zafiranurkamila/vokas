package id.vokas.service;

import id.vokas.config.VokasProperties;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;

/** Kirim email HTML lewat SMTP (Brevo, Gmail app password, dll). Tidak aktif bila SMTP_HOST kosong. */
@Service
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    private final ObjectProvider<JavaMailSender> pengirim;
    private final VokasProperties.Mail cfg;
    private final String host;

    public EmailService(ObjectProvider<JavaMailSender> pengirim, VokasProperties props,
                        @Value("${spring.mail.host:}") String host) {
        this.pengirim = pengirim;
        this.cfg = props.mail();
        this.host = host;
    }

    public boolean aktif() {
        return host != null && !host.isBlank() && cfg != null && cfg.from() != null && !cfg.from().isBlank()
                && pengirim.getIfAvailable() != null;
    }

    /** @return true bila terkirim */
    public boolean kirim(String ke, String judul, String html) {
        if (!aktif()) {
            log.info("SMTP belum diatur, email \"{}\" ke {} tidak dikirim", judul, ke);
            return false;
        }
        try {
            JavaMailSender s = pengirim.getObject();
            MimeMessage m = s.createMimeMessage();
            MimeMessageHelper h = new MimeMessageHelper(m, true, StandardCharsets.UTF_8.name());
            h.setFrom(new InternetAddress(cfg.from(), cfg.namaPengirim() == null ? "VoKas" : cfg.namaPengirim(), "UTF-8"));
            h.setTo(ke);
            h.setSubject(judul);
            h.setText(html, true);
            s.send(m);
            return true;
        } catch (Exception e) {
            log.warn("Gagal kirim email ke {}: {}", ke, e.getMessage());
            return false;
        }
    }
}
