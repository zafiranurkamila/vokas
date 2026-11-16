package id.vokas;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import id.vokas.repo.PedagangRepo;
import id.vokas.service.AkunJuriRunner;
import io.zonky.test.db.postgres.embedded.EmbeddedPostgres;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.io.IOException;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Tes integrasi di PC: PostgreSQL sungguhan (embedded), migrasi Flyway V1..V9, validasi skema Hibernate,
 * lalu semua endpoint fitur baru dipanggil seperti dari aplikasi. AI dimatikan supaya tes tidak bergantung internet.
 */
@SpringBootTest(properties = {
        "vokas.gemini.api-key=", "vokas.api-key=", "spring.mail.host=", "vokas.mail.brevo-api-key="})
@AutoConfigureMockMvc
class FiturBaruIntegrasiTest {

    static final EmbeddedPostgres PG;

    static {
        try {
            PG = EmbeddedPostgres.builder().start();
        } catch (IOException e) {
            throw new IllegalStateException(e);
        }
    }

    @DynamicPropertySource
    static void db(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", () -> PG.getJdbcUrl("postgres", "postgres"));
        r.add("spring.datasource.username", () -> "postgres");
        r.add("spring.datasource.password", () -> "postgres");
    }

    @AfterAll
    static void tutup() throws IOException {
        PG.close();
    }

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired PedagangRepo pedagang;

    private UUID juri() {
        return pedagang.findByNoWa(AkunJuriRunner.NO_WA_JURI).orElseThrow().getId();
    }

    private JsonNode get(String url) throws Exception {
        return json.readTree(mvc.perform(MockMvcRequestBuilders_get(url)).andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString());
    }

    private static org.springframework.test.web.servlet.RequestBuilder MockMvcRequestBuilders_get(String url) {
        return org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get(url);
    }

    private JsonNode kirim(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder b, Object body,
                           int kode) throws Exception {
        if (body != null) b.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        String s = mvc.perform(b).andExpect(status().is(kode)).andReturn().getResponse().getContentAsString();
        return s.isEmpty() ? null : json.readTree(s);
    }

    @Test
    void kasbonDariKalimatSampaiLunas() throws Exception {
        String p = "/api/pedagang/" + juri();
        JsonNode draf = kirim(post(p + "/kasbon/baca"), java.util.Map.of("teks", "bu ani ngutang 20 ribu buat beras"), 200);
        assertEquals("Bu Ani", draf.get("namaPelanggan").asText());
        assertEquals(20000, draf.get("nominal").asLong());

        JsonNode k = kirim(post(p + "/kasbon"), java.util.Map.of("namaPelanggan", "Bu Ani", "nominal", 20000,
                "keterangan", "beras", "noWa", "0812-1111-2222"), 201);
        assertEquals("081211112222", k.get("noWa").asText());
        JsonNode daftar = get(p + "/kasbon");
        assertTrue(daftar.get("totalBelumLunas").asLong() >= 20000);

        int sebelum = get(p + "/transaksi").size();
        JsonNode lunas = kirim(post(p + "/kasbon/" + k.get("id").asText() + "/lunas"), null, 200);
        assertTrue(lunas.get("lunas").asBoolean());
        assertEquals(sebelum + 1, get(p + "/transaksi").size(), "pelunasan tercatat sebagai pemasukan");

        kirim(post(p + "/kasbon"), java.util.Map.of("namaPelanggan", "x", "nominal", 0), 400);
    }

    @Test
    void celenganAturSetorAmbil() throws Exception {
        String p = "/api/pedagang/" + juri();
        JsonNode s = kirim(put(p + "/celengan"), java.util.Map.of("nama", "DP KUR", "target", 1_000_000, "persen", 10), 200);
        assertEquals("DP KUR", s.at("/celengan/nama").asText());
        s = kirim(post(p + "/celengan/setor"), java.util.Map.of("nominal", 50_000), 200);
        assertEquals(50_000, s.get("terkumpul").asLong());
        assertTrue(s.get("sudahSetorHariIni").asBoolean());
        s = kirim(post(p + "/celengan/setor"), java.util.Map.of("nominal", -20_000, "catatan", "beli gas"), 200);
        assertEquals(30_000, s.get("terkumpul").asLong());
        kirim(post(p + "/celengan/setor"), java.util.Map.of("nominal", -999_999), 400);
    }

    @Test
    void saranBelanjaDanPeringatanDariDataContoh() throws Exception {
        String p = "/api/pedagang/" + juri();
        JsonNode saran = get(p + "/saran-belanja");
        assertTrue(saran.get("cukupData").asBoolean(), "akun juri punya data 90 hari");
        assertFalse(saran.get("barang").isEmpty());
        assertTrue(saran.get("perkiraanOmzet").asLong() > 0);
        assertTrue(get(p + "/peringatan").isArray());
    }

    @Test
    void voiceNoteTersimpanDanBisaDiputarUlang() throws Exception {
        String p = "/api/pedagang/" + juri();
        byte[] wav = new byte[4000];
        wav[0] = 'R'; wav[1] = 'I'; wav[2] = 'F'; wav[3] = 'F';
        mvc.perform(multipart(p + "/catat-suara").file(new MockMultipartFile("audio", "vn.wav", "audio/wav", wav)))
                .andExpect(status().isOk());
        JsonNode riwayat = get(p + "/riwayat-ai?jenis=CATAT");
        JsonNode terakhir = riwayat.get(riwayat.size() - 1);
        assertTrue(terakhir.get("adaAudio").asBoolean());
        assertNull(terakhir.get("audio"), "audio tidak ikut di daftar");
        byte[] diputar = mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .get(p + "/riwayat-ai/" + terakhir.get("id").asText() + "/audio"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray();
        assertArrayEquals(wav, diputar);
    }

    @Test
    void fotoNotaTanpaAiTidakMembuatServerGagal() throws Exception {
        String p = "/api/pedagang/" + juri();
        String s = mvc.perform(multipart(p + "/catat-foto")
                        .file(new MockMultipartFile("foto", "nota.jpg", "image/jpeg", new byte[]{1, 2, 3})))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        JsonNode h = json.readTree(s);
        assertEquals(0, h.get("tersimpan").size());
        assertFalse(h.at("/baca/galat").asText().isEmpty());
    }
}
