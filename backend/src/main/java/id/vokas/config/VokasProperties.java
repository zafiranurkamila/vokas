package id.vokas.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "vokas")
public record VokasProperties(String apiKey, String corsOrigins, String zonaWaktu, Gemini gemini, Wa wa, Twilio twilio) {

    /**
     * Twilio WhatsApp (sandbox atau nomor resmi lewat Twilio).
     * @param nomor      pengirim, contoh whatsapp:+14155238886 (nomor sandbox)
     * @param webhookUrl URL publik webhook persis seperti di konsol Twilio, untuk cek tanda tangan
     */
    public record Twilio(String accountSid, String authToken, String nomor, String webhookUrl) {
        public boolean aktif() {
            return accountSid != null && !accountSid.isBlank() && authToken != null && !authToken.isBlank();
        }
    }

    public record Gemini(String apiKey, String model, String modelCadangan) {
        public boolean aktif() { return apiKey != null && !apiKey.isBlank(); }
    }

    public record Wa(String verifyToken, String accessToken, String phoneNumberId, String appSecret, String graphVersion) {
        public boolean aktif() { return accessToken != null && !accessToken.isBlank(); }
    }
}
