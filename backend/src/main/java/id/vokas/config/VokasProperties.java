package id.vokas.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "vokas")
public record VokasProperties(String apiKey, String corsOrigins, String zonaWaktu, Gemini gemini, Wa wa) {

    public record Gemini(String apiKey, String model) {
        public boolean aktif() { return apiKey != null && !apiKey.isBlank(); }
    }

    public record Wa(String verifyToken, String accessToken, String phoneNumberId, String appSecret, String graphVersion) {
        public boolean aktif() { return accessToken != null && !accessToken.isBlank(); }
    }
}
