package id.vokas.whatsapp;

import com.fasterxml.jackson.databind.JsonNode;
import id.vokas.config.VokasProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.Map;

/** Panggilan ke WhatsApp Cloud API (Graph API Meta): unduh media dan kirim pesan teks. */
@Component
public class WhatsAppClient {

    private static final Logger log = LoggerFactory.getLogger(WhatsAppClient.class);

    private final VokasProperties.Wa cfg;
    private final RestClient http;

    public WhatsAppClient(VokasProperties props) {
        this.cfg = props.wa();
        this.http = RestClient.builder().baseUrl("https://graph.facebook.com/" + cfg.graphVersion()).build();
    }

    public record Media(byte[] isi, String mimeType) {}

    public Media unduh(String mediaId) {
        JsonNode info = http.get().uri("/{id}", mediaId)
                .header("Authorization", "Bearer " + cfg.accessToken())
                .retrieve().body(JsonNode.class);
        if (info == null || !info.hasNonNull("url")) throw new IllegalStateException("URL media tidak ada");
        byte[] isi = RestClient.create().get().uri(info.get("url").asText())
                .header("Authorization", "Bearer " + cfg.accessToken())
                .retrieve().body(byte[].class);
        return new Media(isi, info.path("mime_type").asText("audio/ogg"));
    }

    /** true bila kredensial pengiriman sudah diisi. */
    public boolean aktif() { return cfg.aktif(); }

    public void kirimTeks(String ke, String teks) {
        if (!cfg.aktif()) {
            log.info("WA belum aktif, balasan ke {} tidak dikirim:\n{}", ke, teks);
            return;
        }
        try {
            http.post().uri("/{pid}/messages", cfg.phoneNumberId())
                    .header("Authorization", "Bearer " + cfg.accessToken())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of("messaging_product", "whatsapp", "to", ke, "type", "text",
                            "text", Map.of("body", teks)))
                    .retrieve().toBodilessEntity();
        } catch (RestClientException e) {
            log.warn("Gagal kirim WA ke {}: {}", ke, e.getMessage());
        }
    }
}
