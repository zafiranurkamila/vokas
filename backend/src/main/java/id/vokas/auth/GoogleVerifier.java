package id.vokas.auth;

import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.server.ResponseStatusException;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * Memeriksa token dari Google Sign-In langsung ke Google.
 * Android memberi ID token; web (Google Identity Services) memberi access token. Keduanya dicek ke endpoint
 * tokeninfo Google dan harus diterbitkan untuk client ID milik VoKas (GOOGLE_CLIENT_ID).
 */
@Component
public class GoogleVerifier {

    private static final Logger log = LoggerFactory.getLogger(GoogleVerifier.class);

    public record AkunGoogle(String sub, String email, String nama) {}

    private final String clientId;
    private final RestClient http;

    public GoogleVerifier(@Value("${vokas.google.client-id:}") String clientId) {
        this.clientId = clientId;
        SimpleClientHttpRequestFactory f = new SimpleClientHttpRequestFactory();
        f.setConnectTimeout(10_000);
        f.setReadTimeout(15_000);
        this.http = RestClient.builder().requestFactory(f).build();
    }

    public boolean aktif() { return clientId != null && !clientId.isBlank(); }

    public AkunGoogle periksa(String idToken, String accessToken) {
        if (!aktif()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Login Google belum diaktifkan di server");
        try {
            if (idToken != null && !idToken.isBlank()) {
                JsonNode t = ambil("https://oauth2.googleapis.com/tokeninfo?id_token=" + enc(idToken), null);
                cekAudiens(t.path("aud").asText());
                return hasil(t.path("sub").asText(null), t.path("email").asText(null), t.path("email_verified").asText(""),
                        t.path("name").asText(null));
            }
            if (accessToken != null && !accessToken.isBlank()) {
                JsonNode t = ambil("https://oauth2.googleapis.com/tokeninfo?access_token=" + enc(accessToken), null);
                String aud = t.path("aud").asText(t.path("azp").asText(""));
                cekAudiens(aud);
                JsonNode u = ambil("https://openidconnect.googleapis.com/v1/userinfo", accessToken);
                return hasil(u.path("sub").asText(null), u.path("email").asText(null), u.path("email_verified").asText(""),
                        u.path("name").asText(null));
            }
        } catch (RestClientException e) {
            log.warn("Token Google ditolak: {}", e.getMessage());
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Login Google gagal, coba lagi");
        }
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Token Google tidak ada");
    }

    private void cekAudiens(String aud) {
        if (!clientId.equals(aud)) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Token Google bukan untuk VoKas");
    }

    private static AkunGoogle hasil(String sub, String email, String terverifikasi, String nama) {
        if (sub == null || email == null || !"true".equalsIgnoreCase(terverifikasi))
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Email Google belum terverifikasi");
        return new AkunGoogle(sub, email.toLowerCase(), nama);
    }

    private JsonNode ambil(String url, String bearer) {
        var req = http.get().uri(URI.create(url));
        if (bearer != null) req = req.header("Authorization", "Bearer " + bearer);
        return req.retrieve().body(JsonNode.class);
    }

    private static String enc(String s) { return URLEncoder.encode(s, StandardCharsets.UTF_8); }
}
