package id.vokas.parser;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import id.vokas.config.VokasProperties;
import id.vokas.model.Jenis;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.*;

/**
 * Membaca catatan lewat Gemini API (generateContent). Audio voice note dikirim langsung, sehingga
 * transkripsi dan penguraian terjadi dalam satu panggilan dan hasilnya JSON sesuai skema.
 * Catatan: data pada free tier Gemini dapat dipakai Google untuk perbaikan produk; cantumkan di kebijakan privasi.
 */
@Component
public class PembacaGemini implements PembacaCatatan {

    private static final Logger log = LoggerFactory.getLogger(PembacaGemini.class);
    private static final String BASE = "https://generativelanguage.googleapis.com/v1beta/models/";

    private static final String INSTRUKSI = """
            Kamu membaca catatan keuangan pedagang kecil Indonesia (bahasa sehari-hari, boleh campur bahasa daerah).
            Ubah catatan menjadi daftar transaksi. Aturan:
            - jenis MASUK untuk penjualan atau uang diterima, KELUAR untuk belanja, bayar, atau biaya.
            - total adalah rupiah untuk baris itu (bilangan bulat, tanpa titik). "dua ribuan" berarti harga per satuan,
              jadi total = jumlah x harga.
            - jumlah dan satuan diisi bila disebut (contoh 30 bungkus); bila tidak, kosongkan.
            - nama adalah nama barang singkat huruf kecil, contoh "cilok", "gas melon".
            - Jangan mengarang transaksi yang tidak disebut. Bila tidak ada nominal, jangan buat barisnya.
            - transkrip adalah teks yang kamu dengar (untuk audio) atau teks masukan apa adanya.
            """;

    private final VokasProperties.Gemini cfg;
    private final RestClient http;
    private final ObjectMapper json;

    public PembacaGemini(VokasProperties props, ObjectMapper json) {
        this.cfg = props.gemini();
        this.json = json;
        SimpleClientHttpRequestFactory f = new SimpleClientHttpRequestFactory();
        f.setConnectTimeout(10_000);
        f.setReadTimeout(60_000);
        this.http = RestClient.builder().requestFactory(f).baseUrl(BASE).build();
    }

    @Override
    public String nama() { return "gemini"; }

    public boolean aktif() { return cfg != null && cfg.aktif(); }

    @Override
    public HasilBaca bacaTeks(String teks) {
        return panggil(List.of(Map.of("text", "Catatan pedagang:\n" + teks)));
    }

    @Override
    public HasilBaca bacaSuara(byte[] audio, String mimeType) {
        String mime = mimeType == null ? "audio/ogg" : mimeType.split(";")[0].trim();  // WhatsApp: "audio/ogg; codecs=opus"
        return panggil(List.of(
                Map.of("inlineData", Map.of("mimeType", mime, "data", Base64.getEncoder().encodeToString(audio))),
                Map.of("text", "Ini voice note catatan pedagang. Dengarkan lalu uraikan.")));
    }

    private HasilBaca panggil(List<Map<String, Object>> parts) {
        if (!aktif()) return HasilBaca.gagal(nama(), "GEMINI_API_KEY belum diisi");
        Map<String, Object> body = Map.of(
                "systemInstruction", Map.of("parts", List.of(Map.of("text", INSTRUKSI))),
                "contents", List.of(Map.of("role", "user", "parts", parts)),
                "generationConfig", Map.of(
                        "temperature", 0,
                        "responseMimeType", "application/json",
                        "responseSchema", skema()));
        try {
            JsonNode res = http.post()
                    .uri(cfg.model() + ":generateContent")
                    .header("x-goog-api-key", cfg.apiKey())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(JsonNode.class);
            String teks = res == null ? null : res.at("/candidates/0/content/parts/0/text").asText(null);
            if (teks == null) return HasilBaca.gagal(nama(), "Gemini tidak mengembalikan jawaban");
            return uraiJawaban(json.readTree(teks));
        } catch (HttpClientErrorException.TooManyRequests e) {
            log.warn("Kuota Gemini habis: {}", e.getStatusText());
            return HasilBaca.gagal(nama(), "Kuota AI gratis sedang penuh, coba lagi sebentar");
        } catch (RestClientException | java.io.IOException e) {
            log.warn("Panggilan Gemini gagal: {}", e.getMessage());
            return HasilBaca.gagal(nama(), "AI sedang tidak bisa dihubungi");
        }
    }

    HasilBaca uraiJawaban(JsonNode root) {
        List<ItemCatatan> items = new ArrayList<>();
        for (JsonNode n : root.path("transaksi")) {
            long total = n.path("total").asLong(0);
            if (total <= 0) continue;
            Jenis jenis = "KELUAR".equalsIgnoreCase(n.path("jenis").asText()) ? Jenis.KELUAR : Jenis.MASUK;
            Integer jumlah = n.hasNonNull("jumlah") && n.get("jumlah").asInt() > 0 ? n.get("jumlah").asInt() : null;
            String satuan = n.hasNonNull("satuan") && !n.get("satuan").asText().isBlank() ? n.get("satuan").asText() : null;
            String namaItem = n.path("nama").asText("").trim();
            if (namaItem.isEmpty()) namaItem = jenis == Jenis.MASUK ? "Penjualan" : "Pengeluaran";
            Long harga = jumlah != null ? Math.round((double) total / jumlah) : null;
            items.add(new ItemCatatan(jenis, namaItem, jumlah, satuan, harga, total));
        }
        return new HasilBaca(items, !items.isEmpty(), nama(), root.path("transkrip").asText(""), null);
    }

    private static Map<String, Object> skema() {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("type", "OBJECT");
        item.put("properties", Map.of(
                "jenis", Map.of("type", "STRING", "enum", List.of("MASUK", "KELUAR")),
                "nama", Map.of("type", "STRING"),
                "jumlah", Map.of("type", "INTEGER", "nullable", true),
                "satuan", Map.of("type", "STRING", "nullable", true),
                "total", Map.of("type", "INTEGER")));
        item.put("required", List.of("jenis", "nama", "total"));
        return Map.of(
                "type", "OBJECT",
                "properties", Map.of(
                        "transkrip", Map.of("type", "STRING"),
                        "transaksi", Map.of("type", "ARRAY", "items", item)),
                "required", List.of("transkrip", "transaksi"));
    }
}
