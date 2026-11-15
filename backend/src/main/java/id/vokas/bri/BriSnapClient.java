package id.vokas.bri;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import id.vokas.config.VokasProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Klien BRIAPI dengan standar SNAP BI (Bank Indonesia).
 * <ul>
 *   <li>Token B2B: POST /snap/v1.0/access-token/b2b, tanda tangan asimetris SHA256withRSA atas "clientId|X-TIMESTAMP"
 *       (dokumentasi "APIDOCS Oauth SNAP BI" BRI). Public key diunggah di portal: Aplikasi Saya > Manage Snap Key.</li>
 *   <li>Transaksi: tanda tangan simetris HMAC-SHA512 atas
 *       "METHOD:path:accessToken:lowercase(hex(sha256(body minified))):timestamp" memakai client secret.</li>
 *   <li>Bank Statement (mutasi): POST /snap/v1.1/bank-statement atau /snap/v2.1/bank-statement (BRI_PATH_MUTASI).</li>
 * </ul>
 * Kredensial berasal dari portal developers.bri.co.id (Aplikasi Saya), hanya lewat environment variable.
 */
@Component
public class BriSnapClient {

    private static final Logger log = LoggerFactory.getLogger(BriSnapClient.class);
    /** Untuk isi body (fromDateTime/toDateTime), sesuai contoh dokumentasi: tanpa milidetik. */
    private static final DateTimeFormatter WAKTU = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ssXXX");
    /** Untuk header X-TIMESTAMP: yyyy-MM-ddTHH:mm:ss.SSSTZD (dokumentasi Oauth SNAP BI BRI). */
    private static final DateTimeFormatter WAKTU_HEADER = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSXXX");
    static final String PATH_TOKEN = "/snap/v1.0/access-token/b2b";

    private final VokasProperties.Bri cfg;
    private final ObjectMapper json;
    private final RestClient http;

    private String token;
    private Instant tokenKedaluwarsa = Instant.EPOCH;

    public BriSnapClient(VokasProperties props, ObjectMapper json) {
        this.cfg = props.bri();
        this.json = json;
        SimpleClientHttpRequestFactory f = new SimpleClientHttpRequestFactory();
        f.setConnectTimeout(10_000);
        f.setReadTimeout(30_000);
        this.http = RestClient.builder().requestFactory(f).baseUrl(cfg == null ? "" : cfg.baseUrl()).build();
    }

    public boolean aktif() {
        return cfg != null && cfg.aktif();
    }

    static String sekarang() {
        return OffsetDateTime.now(ZoneOffset.ofHours(7)).truncatedTo(ChronoUnit.MILLIS).format(WAKTU_HEADER);
    }

    private String pathMutasi() {
        return cfg.pathMutasi() == null || cfg.pathMutasi().isBlank() ? "/snap/v1.1/bank-statement" : cfg.pathMutasi();
    }

    // ---------------- token ----------------

    synchronized String token() throws Exception {
        if (token != null && Instant.now().isBefore(tokenKedaluwarsa)) return token;
        String ts = sekarang();
        String sig = tandaTanganRsa(cfg.clientId() + "|" + ts);
        JsonNode r = http.post().uri(PATH_TOKEN)
                .header("X-TIMESTAMP", ts)
                .header("X-CLIENT-KEY", cfg.clientId())
                .header("X-SIGNATURE", sig)
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of("grantType", "client_credentials"))
                .retrieve().body(JsonNode.class);
        if (r == null || !r.hasNonNull("accessToken")) throw new IllegalStateException("Token BRI tidak didapat: " + r);
        token = r.get("accessToken").asText();
        long detik = r.path("expiresIn").asLong(900);
        tokenKedaluwarsa = Instant.now().plusSeconds(Math.max(60, detik - 60));
        return token;
    }

    private String tandaTanganRsa(String data) throws Exception {
        String pem = cfg.privateKey().replace("\\n", "\n")
                .replaceAll("-----BEGIN (RSA )?PRIVATE KEY-----", "")
                .replaceAll("-----END (RSA )?PRIVATE KEY-----", "")
                .replaceAll("\\s", "");
        PrivateKey kunci = KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(pem)));
        Signature s = Signature.getInstance("SHA256withRSA");
        s.initSign(kunci);
        s.update(data.getBytes(StandardCharsets.UTF_8));
        return Base64.getEncoder().encodeToString(s.sign());
    }

    /** Lowercase(HexEncode(SHA-256(minify(body)))) sesuai dokumentasi SNAP BI BRI. */
    static String hashBody(String bodyMinified) throws Exception {
        return HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(bodyMinified.getBytes(StandardCharsets.UTF_8))).toLowerCase();
    }

    static String tandaTanganHmac(String method, String path, String token, String bodyMinified, String ts, String secret)
            throws Exception {
        String data = method + ":" + path + ":" + token + ":" + hashBody(bodyMinified) + ":" + ts;
        Mac mac = Mac.getInstance("HmacSHA512");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA512"));
        return Base64.getEncoder().encodeToString(mac.doFinal(data.getBytes(StandardCharsets.UTF_8)));
    }

    // ---------------- mutasi ----------------

    /** Ambil mutasi rekening untuk rentang waktu tertentu. */
    public JsonNode mutasi(String accountNo, OffsetDateTime dari, OffsetDateTime sampai) throws Exception {
        String body = json.writeValueAsString(Map.of(
                "accountNo", accountNo,
                "fromDateTime", dari.truncatedTo(ChronoUnit.SECONDS).format(WAKTU),
                "toDateTime", sampai.truncatedTo(ChronoUnit.SECONDS).format(WAKTU)));
        String tok = token();
        String ts = sekarang();
        try {
            String path = pathMutasi();
            return http.post().uri(path)
                    .header("Authorization", "Bearer " + tok)
                    .header("X-TIMESTAMP", ts)
                    .header("X-SIGNATURE", tandaTanganHmac("POST", path, tok, body, ts, cfg.clientSecret()))
                    .header("X-PARTNER-ID", cfg.partnerId())
                    .header("CHANNEL-ID", cfg.channelId())
                    .header("X-EXTERNAL-ID", String.valueOf(ThreadLocalRandom.current().nextInt(100_000_000, 999_999_999)))
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve().body(JsonNode.class);
        } catch (RestClientResponseException e) {
            log.warn("BRI bank-statement {}: {}", e.getStatusCode().value(), e.getResponseBodyAsString());
            if (e.getStatusCode().value() == 401) token = null; // token mungkin kedaluwarsa
            throw e;
        }
    }
}
