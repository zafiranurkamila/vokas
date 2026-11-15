package id.vokas.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "vokas")
public record VokasProperties(String apiKey, String corsOrigins, String zonaWaktu, Gemini gemini, Wa wa, Twilio twilio, Bri bri) {

    /** Kredensial BRIAPI (SNAP BI) dari portal developers.bri.co.id. privateKey: PEM PKCS#8, boleh dengan \n. */
    public record Bri(String baseUrl, String clientId, String clientSecret, String privateKey, String partnerId, String channelId,
                      String pathMutasi) {
        public boolean aktif() {
            return clientId != null && !clientId.isBlank() && clientSecret != null && !clientSecret.isBlank()
                    && privateKey != null && !privateKey.isBlank() && partnerId != null && !partnerId.isBlank()
                    && channelId != null && !channelId.isBlank();
        }
    }

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
