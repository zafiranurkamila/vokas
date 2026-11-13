package id.vokas.whatsapp;

import com.fasterxml.jackson.databind.ObjectMapper;
import id.vokas.config.VokasProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;

/** Webhook WhatsApp Cloud API. Daftarkan URL https://<domain-railway>/webhook/whatsapp di Meta App Dashboard. */
@RestController
@RequestMapping("/webhook/whatsapp")
public class WhatsAppWebhook {

    private static final Logger log = LoggerFactory.getLogger(WhatsAppWebhook.class);

    private final VokasProperties.Wa cfg;
    private final WhatsAppHandler handler;
    private final ObjectMapper json;

    public WhatsAppWebhook(VokasProperties props, WhatsAppHandler handler, ObjectMapper json) {
        this.cfg = props.wa();
        this.handler = handler;
        this.json = json;
    }

    /** Verifikasi saat webhook didaftarkan. */
    @GetMapping
    public ResponseEntity<String> verifikasi(@RequestParam("hub.mode") String mode,
                                             @RequestParam("hub.verify_token") String token,
                                             @RequestParam("hub.challenge") String challenge) {
        boolean cocok = cfg.verifyToken() != null && !cfg.verifyToken().isBlank()
                && "subscribe".equals(mode) && cfg.verifyToken().equals(token);
        return cocok ? ResponseEntity.ok(challenge) : ResponseEntity.status(HttpStatus.FORBIDDEN).build();
    }

    @PostMapping
    public ResponseEntity<Void> terima(@RequestBody byte[] body,
                                       @RequestHeader(value = "X-Hub-Signature-256", required = false) String sig) {
        if (cfg.appSecret() == null || cfg.appSecret().isBlank()) {
            log.warn("WA_APP_SECRET kosong: tanda tangan webhook tidak diperiksa (hanya untuk uji lokal)");
        } else if (!tandaTanganSah(body, sig, cfg.appSecret())) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        try {
            handler.proses(json.readTree(body));
        } catch (Exception e) {
            log.warn("Payload webhook tidak valid: {}", e.getMessage());
        }
        return ResponseEntity.ok().build();
    }

    static boolean tandaTanganSah(byte[] body, String header, String secret) {
        if (header == null || !header.startsWith("sha256=")) return false;
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            String harap = HexFormat.of().formatHex(mac.doFinal(body));
            return MessageDigest.isEqual(harap.getBytes(StandardCharsets.UTF_8),
                    header.substring(7).getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            return false;
        }
    }
}
