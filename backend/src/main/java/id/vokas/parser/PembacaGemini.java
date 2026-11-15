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
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.ResourceAccessException;
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

    /** Model yang dijawab 404 (sudah pensiun) tidak dicoba lagi selama server menyala. */
    private final Set<String> pensiun = java.util.concurrent.ConcurrentHashMap.newKeySet();

    /** Model terakhir yang berhasil menjawab; dicoba paling awal supaya tidak mengulang model yang gagal. */
    private volatile String terakhirBerhasil;

    public PembacaGemini(VokasProperties props, ObjectMapper json) {
        this.cfg = props.gemini();
        this.json = json;
        SimpleClientHttpRequestFactory f = new SimpleClientHttpRequestFactory();
        f.setConnectTimeout(10_000);
        f.setReadTimeout(30_000);
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

    public record Jawaban(String teks, String galat) {}

    /**
     * Jawaban teks bebas (untuk fitur Tanya AI). Memakai urutan model yang sama dengan pembaca catatan.
     * @param instruksi peran dan aturan asisten, termasuk data usaha sebagai konteks
     */
    public Jawaban jawab(String instruksi, String pertanyaan) {
        if (!aktif()) return new Jawaban(null, "GEMINI_API_KEY belum diisi");
        String galat = "AI sedang tidak bisa dihubungi";
        long mulai = System.currentTimeMillis();
        for (String model : urutanModel().stream().distinct().toList()) {
            if (System.currentTimeMillis() - mulai > 60_000) break;
            Map<String, Object> gen = new LinkedHashMap<>();
            gen.put("temperature", 0.4);
            gen.put("maxOutputTokens", 500);
            if (model.startsWith("gemini-2.5")) gen.put("thinkingConfig", Map.of("thinkingBudget", 0));
            Map<String, Object> body = Map.of(
                    "systemInstruction", Map.of("parts", List.of(Map.of("text", instruksi))),
                    "contents", List.of(Map.of("role", "user", "parts", List.of(Map.of("text", pertanyaan)))),
                    "generationConfig", gen);
            try {
                JsonNode res = http.post().uri(java.net.URI.create(BASE + model + ":generateContent"))
                        .header("x-goog-api-key", cfg.apiKey())
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(body).retrieve().body(JsonNode.class);
                StringBuilder sb = new StringBuilder();
                if (res != null) for (JsonNode p : res.at("/candidates/0/content/parts")) sb.append(p.path("text").asText(""));
                if (!sb.isEmpty()) {
                    terakhirBerhasil = model;
                    return new Jawaban(sb.toString().trim(), null);
                }
                galat = "AI tidak memberi jawaban, coba tanya dengan kalimat lain";
            } catch (HttpClientErrorException.TooManyRequests e) {
                return new Jawaban(null, "Kuota AI gratis sedang penuh, coba lagi sebentar");
            } catch (HttpClientErrorException e) {
                int s = e.getStatusCode().value();
                log.warn("Tanya AI ({}) ditolak {}: {}", model, s, e.getResponseBodyAsString());
                if (s == 401 || s == 403) return new Jawaban(null, "API key Gemini salah atau belum aktif");
                if (s == 404) pensiun.add(model);
                galat = "AI menolak permintaan (" + s + ")";
            } catch (RestClientException e) {
                log.warn("Tanya AI ({}) gagal: {}", model, e.toString());
                galat = "AI sedang sibuk atau lambat, coba lagi sebentar";
            }
        }
        return new Jawaban(null, galat);
    }

    private HasilBaca panggil(List<Map<String, Object>> parts) {
        if (!aktif()) return HasilBaca.gagal(nama(), "GEMINI_API_KEY belum diisi");
        // Free tier sering "overloaded" (503), lambat, atau modelnya sudah pensiun (404).
        // Urutan: model utama 2x, lalu tiap model cadangan sekali. Model 404 dilewati tanpa jeda.
        // Bila model utama timeout, percobaan kedua model yang sama dilewati: langsung ke model yang lebih ringan.
        List<String> urutan = urutanModel();
        HasilBaca terakhir = HasilBaca.gagal(nama(), "AI sedang tidak bisa dihubungi");
        boolean perluJeda = false;
        String timeoutDi = null;
        long mulai = System.currentTimeMillis();
        for (String model : urutan) {
            if (System.currentTimeMillis() - mulai > 100_000) break;   // jangan biarkan pengguna menunggu terlalu lama
            if (model.equals(timeoutDi)) continue;
            if (perluJeda) jeda(1200);
            HasilBaca h = panggilSekali(model, isiPermintaan(model, parts));
            if (h.galat() != null && h.galat().startsWith(LAMBAT)) timeoutDi = model;
            if (h.galat() == null) {
                if (!model.equals(cfg.model())) log.info("Gemini memakai model cadangan {}", model);
                terakhirBerhasil = model;
                return h;
            }
            boolean sementara = h.galat().startsWith(SEMENTARA);
            boolean tidakAda = h.galat().startsWith("Model AI");
            if (!sementara && !tidakAda) return h;   // API key salah, kuota habis, dsb.: model lain tidak membantu
            perluJeda = sementara;
            terakhir = h;
        }
        return terakhir;
    }

    private static final String LAMBAT = "AI sedang lambat";

    /**
     * Mode "thinking" pada Gemini 2.5 menyala bawaan dan bisa menambah puluhan detik. Untuk mengurai catatan
     * transaksi tidak diperlukan, jadi dimatikan (thinkingBudget 0). Model lain tidak diberi thinkingConfig
     * karena bisa menolak parameter itu.
     */
    private Map<String, Object> isiPermintaan(String model, List<Map<String, Object>> parts) {
        Map<String, Object> gen = new LinkedHashMap<>();
        gen.put("temperature", 0);
        gen.put("responseMimeType", "application/json");
        gen.put("responseSchema", skema());
        if (model.startsWith("gemini-2.5")) gen.put("thinkingConfig", Map.of("thinkingBudget", 0));
        return Map.of(
                "systemInstruction", Map.of("parts", List.of(Map.of("text", INSTRUKSI))),
                "contents", List.of(Map.of("role", "user", "parts", parts)),
                "generationConfig", gen);
    }

    List<String> urutanModel() {
        List<String> semua = new ArrayList<>();
        String awal = terakhirBerhasil != null ? terakhirBerhasil : cfg.model();
        semua.add(awal);
        semua.add(awal);
        if (!cfg.model().equals(awal)) semua.add(cfg.model());
        if (cfg.modelCadangan() != null) {
            for (String m : cfg.modelCadangan().split(",")) {
                String t = m.trim();
                if (!t.isEmpty() && !semua.contains(t)) semua.add(t);
            }
        }
        List<String> aktif = semua.stream().filter(m -> !pensiun.contains(m)).toList();
        return aktif.isEmpty() ? semua : new ArrayList<>(aktif);   // semua pensiun: coba ulang, siapa tahu salah sesaat
    }

    /** Model yang dicoba berurutan; dipakai juga oleh endpoint cek. */
    public List<String> daftarModel() {
        return urutanModel().stream().distinct().toList();
    }

    /** Awalan pesan untuk gangguan sementara yang layak dicoba ulang. */
    private static final String SEMENTARA = "AI sedang";

    private static void jeda(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private HasilBaca panggilSekali(String model, Map<String, Object> body) {
        try {
            JsonNode res = http.post()
                    .uri(java.net.URI.create(BASE + model + ":generateContent"))
                    .header("x-goog-api-key", cfg.apiKey())
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(JsonNode.class);
            String teks = res == null ? null : res.at("/candidates/0/content/parts/0/text").asText(null);
            if (teks == null) {
                String alasan = res == null ? "kosong" : res.at("/promptFeedback/blockReason").asText(res.at("/candidates/0/finishReason").asText("?"));
                log.warn("Gemini ({}) tanpa teks jawaban, alasan: {}", model, alasan);
                return HasilBaca.gagal(nama(), "AI sedang tidak memberi jawaban (" + alasan + "), coba lagi");
            }
            try {
                return uraiJawaban(json.readTree(teks));
            } catch (java.io.IOException e) {
                log.warn("Jawaban Gemini ({}) bukan JSON: {}", model, teks.length() > 300 ? teks.substring(0, 300) : teks);
                return HasilBaca.gagal(nama(), "Jawaban AI tidak terbaca, coba ucapkan lagi lebih jelas");
            }
        } catch (HttpServerErrorException e) {
            log.warn("Gemini ({}) error server {}: {}", model, e.getStatusCode().value(), e.getResponseBodyAsString());
            return HasilBaca.gagal(nama(), "AI sedang sibuk (" + e.getStatusCode().value() + "), coba lagi sebentar");
        } catch (ResourceAccessException e) {
            log.warn("Gemini ({}) timeout/koneksi: {}", model, e.getMessage());
            return HasilBaca.gagal(nama(), "AI sedang lambat menjawab, coba lagi sebentar");
        } catch (HttpClientErrorException.TooManyRequests e) {
            log.warn("Kuota Gemini habis: {}", e.getStatusText());
            return HasilBaca.gagal(nama(), "Kuota AI gratis sedang penuh, coba lagi sebentar");
        } catch (HttpClientErrorException e) {
            // 400 = permintaan/format audio ditolak, 401/403 = API key salah, 404 = nama model tidak ada
            String isi = e.getResponseBodyAsString();
            log.warn("Gemini ({}) menolak ({}): {}", model, e.getStatusCode().value(), isi);
            if (e.getStatusCode().value() == 404) pensiun.add(model);
            String sebab = switch (e.getStatusCode().value()) {
                case 400 -> "AI menolak permintaan (400). Cek API key dan format audio.";
                case 401, 403 -> "API key Gemini salah atau belum aktif (" + e.getStatusCode().value() + ").";
                case 404 -> "Model AI '" + model + "' tidak ditemukan (404). Ganti GEMINI_MODEL.";
                default -> "AI menolak permintaan (" + e.getStatusCode().value() + ").";
            };
            return HasilBaca.gagal(nama(), sebab);
        } catch (RestClientException e) {
            log.warn("Panggilan Gemini ({}) gagal: {}", model, e.toString());
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
