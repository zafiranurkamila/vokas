package id.vokas.whatsapp;

import id.vokas.config.VokasProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;

/** Panggilan ke API Twilio: kirim pesan WhatsApp dan unduh media (voice note). */
@Component
public class TwilioClient {

    private static final Logger log = LoggerFactory.getLogger(TwilioClient.class);

    private final VokasProperties.Twilio cfg;
    private final RestClient http = RestClient.create();

    public TwilioClient(VokasProperties props) {
        this.cfg = props.twilio();
    }

    private String basicAuth() {
        String kred = cfg.accountSid() + ":" + cfg.authToken();
        return "Basic " + Base64.getEncoder().encodeToString(kred.getBytes(StandardCharsets.UTF_8));
    }

    /** ke: nomor 62xxxxxxxx. Pesan WhatsApp maksimal 1600 karakter. */
    public void kirimTeks(String ke, String teks) {
        if (!cfg.aktif()) {
            log.info("Twilio belum aktif, balasan ke {} tidak dikirim:\n{}", ke, teks);
            return;
        }
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("From", cfg.nomor());
        form.add("To", "whatsapp:+" + ke);
        form.add("Body", teks.length() > 1600 ? teks.substring(0, 1600) : teks);
        try {
            http.post()
                    .uri("https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json", cfg.accountSid())
                    .header("Authorization", basicAuth())
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(form)
                    .retrieve()
                    .toBodilessEntity();
        } catch (RestClientException e) {
            log.warn("Gagal kirim WA lewat Twilio ke {}: {}", ke, e.getMessage());
        }
    }

    /**
     * Media Twilio dilindungi Basic Auth lalu dialihkan (redirect) ke penyimpanan file sementara.
     * Redirect diikuti manual supaya header Authorization tidak ikut terkirim ke host penyimpanan.
     */
    public WhatsAppClient.Media unduh(String url, String mimeType) {
        try {
            HttpClient klien = HttpClient.newBuilder()
                    .followRedirects(HttpClient.Redirect.NEVER)
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();
            HttpResponse<byte[]> r = klien.send(
                    HttpRequest.newBuilder(URI.create(url)).header("Authorization", basicAuth())
                            .timeout(Duration.ofSeconds(30)).GET().build(),
                    HttpResponse.BodyHandlers.ofByteArray());
            for (int i = 0; i < 3 && r.statusCode() / 100 == 3; i++) {
                String lokasi = r.headers().firstValue("Location").orElseThrow();
                r = klien.send(HttpRequest.newBuilder(URI.create(url).resolve(lokasi))
                                .timeout(Duration.ofSeconds(30)).GET().build(),
                        HttpResponse.BodyHandlers.ofByteArray());
            }
            if (r.statusCode() != 200) throw new IllegalStateException("Unduh media Twilio gagal: HTTP " + r.statusCode());
            return new WhatsAppClient.Media(r.body(), mimeType == null ? "audio/ogg" : mimeType);
        } catch (java.io.IOException e) {
            throw new IllegalStateException("Unduh media Twilio gagal", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Unduh media Twilio terputus", e);
        }
    }
}
