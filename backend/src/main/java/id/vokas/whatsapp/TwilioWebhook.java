package id.vokas.whatsapp;

import id.vokas.config.VokasProperties;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.Map;
import java.util.TreeMap;

/**
 * Webhook Twilio WhatsApp. Di konsol Twilio (Messaging > Try it out > Send a WhatsApp message > Sandbox settings),
 * isi "When a message comes in" dengan https://<domain-backend>/webhook/twilio, metode POST.
 */
@RestController
@RequestMapping("/webhook/twilio")
public class TwilioWebhook {

    private static final Logger log = LoggerFactory.getLogger(TwilioWebhook.class);
    private static final String TWIML_KOSONG = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response></Response>";

    private final VokasProperties.Twilio cfg;
    private final Pemroses pemroses;

    public TwilioWebhook(VokasProperties props, Pemroses pemroses) {
        this.cfg = props.twilio();
        this.pemroses = pemroses;
    }

    @PostMapping(consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE)
    public ResponseEntity<String> terima(HttpServletRequest req,
                                         @RequestHeader(value = "X-Twilio-Signature", required = false) String sig) {
        Map<String, String> p = new TreeMap<>();
        req.getParameterMap().forEach((k, v) -> p.put(k, v.length > 0 ? v[0] : ""));

        if (cfg.webhookUrl() == null || cfg.webhookUrl().isBlank() || !cfg.aktif()) {
            log.warn("TWILIO_WEBHOOK_URL/token kosong: tanda tangan Twilio tidak diperiksa (hanya untuk uji)");
        } else if (!tandaTanganSah(cfg.webhookUrl(), p, sig, cfg.authToken())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        // Twilio menunggu jawaban maksimal 15 detik; Gemini bisa lebih lama, jadi diproses di belakang
        // dan balasan dikirim lewat API.
        pemroses.proses(p);
        return ResponseEntity.ok().contentType(MediaType.APPLICATION_XML).body(TWIML_KOSONG);
    }

    /** Aturan Twilio: HMAC-SHA1(URL + semua parameter terurut nama+nilai, auth token), base64. */
    static boolean tandaTanganSah(String url, Map<String, String> parameterTerurut, String sig, String token) {
        if (sig == null) return false;
        try {
            StringBuilder data = new StringBuilder(url);
            parameterTerurut.forEach((k, v) -> data.append(k).append(v));
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(new SecretKeySpec(token.getBytes(StandardCharsets.UTF_8), "HmacSHA1"));
            String harap = Base64.getEncoder().encodeToString(mac.doFinal(data.toString().getBytes(StandardCharsets.UTF_8)));
            return MessageDigest.isEqual(harap.getBytes(StandardCharsets.UTF_8), sig.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            return false;
        }
    }

    @Component
    public static class Pemroses {
        private final WhatsAppHandler handler;
        private final TwilioClient twilio;

        public Pemroses(WhatsAppHandler handler, TwilioClient twilio) {
            this.handler = handler;
            this.twilio = twilio;
        }

        @Async
        public void proses(Map<String, String> p) {
            String dari = p.getOrDefault("From", "").replace("whatsapp:", "").replace("+", "").trim();
            if (dari.isEmpty()) return;
            try {
                int jumlahMedia = Integer.parseInt(p.getOrDefault("NumMedia", "0"));
                String mime = p.get("MediaContentType0");
                boolean suara = jumlahMedia > 0 && mime != null && mime.startsWith("audio");
                handler.tanggapi(
                        dari,
                        p.getOrDefault("ProfileName", "Pedagang"),
                        suara ? null : p.get("Body"),
                        suara ? () -> twilio.unduh(p.get("MediaUrl0"), mime) : null,
                        isi -> twilio.kirimTeks(dari, isi));
            } catch (Exception e) {
                log.error("Gagal memproses pesan Twilio dari {}", dari, e);
                twilio.kirimTeks(dari, "Maaf, catatan belum bisa diproses. Coba kirim lagi ya.");
            }
        }
    }
}
