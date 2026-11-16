package id.vokas.service;

import com.fasterxml.jackson.databind.JsonNode;
import id.vokas.model.Jenis;
import id.vokas.model.Kasbon;
import id.vokas.model.Metode;
import id.vokas.model.Sumber;
import id.vokas.model.Transaksi;
import id.vokas.parser.PembacaGemini;
import id.vokas.repo.KasbonRepo;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Kasbon: pelanggan yang "ngebon" atau berutang. Bisa dicatat lewat kalimat/suara seperti
 * "Bu Ani ngutang 20 ribu buat beras". Saat lunas, uangnya otomatis tercatat sebagai pemasukan.
 */
@Service
public class KasbonService {

    private final KasbonRepo repo;
    private final TransaksiService transaksi;
    private final PembacaGemini gemini;

    public KasbonService(KasbonRepo repo, TransaksiService transaksi, PembacaGemini gemini) {
        this.repo = repo;
        this.transaksi = transaksi;
        this.gemini = gemini;
    }

    public record Draf(String namaPelanggan, Long nominal, String keterangan, String transkrip, String galat) {}

    public record Ringkasan(long totalBelumLunas, int jumlahPelanggan, List<Kasbon> belumLunas, List<Kasbon> lunas) {}

    public Ringkasan daftar(UUID pedagangId) {
        transaksi.pedagang(pedagangId);
        List<Kasbon> belum = repo.findByPedagangIdAndLunasFalseOrderByDibuatAsc(pedagangId);
        long total = belum.stream().mapToLong(Kasbon::getNominal).sum();
        int orang = (int) belum.stream().map(k -> k.getNamaPelanggan().toLowerCase(Locale.ROOT)).distinct().count();
        return new Ringkasan(total, orang, belum, repo.findTop20ByPedagangIdAndLunasTrueOrderByDilunasiDesc(pedagangId));
    }

    @Transactional
    public Kasbon tambah(UUID pedagangId, String nama, long nominal, String keterangan, String noWa) {
        transaksi.pedagang(pedagangId);
        if (nominal <= 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Nominal kasbon harus lebih dari 0");
        Kasbon k = new Kasbon();
        k.setPedagangId(pedagangId);
        k.setNamaPelanggan(rapikanNama(nama));
        k.setNominal(nominal);
        k.setKeterangan(keterangan == null || keterangan.isBlank() ? null : keterangan.trim());
        k.setNoWa(noWa == null || noWa.isBlank() ? null : noWa.replaceAll("[^0-9+]", ""));
        return repo.save(k);
    }

    /** Tandai lunas, lalu catat uang yang diterima sebagai pemasukan hari ini. */
    @Transactional
    public Kasbon lunas(UUID pedagangId, UUID kasbonId) {
        Kasbon k = ambil(pedagangId, kasbonId);
        if (k.isLunas()) return k;
        k.setLunas(true);
        k.setDilunasi(OffsetDateTime.now());
        Transaksi t = new Transaksi();
        t.setJenis(Jenis.MASUK);
        t.setNamaItem("Kasbon " + k.getNamaPelanggan() + " dibayar");
        t.setTotal(k.getNominal());
        t.setMetode(Metode.TUNAI);
        t.setSumber(Sumber.MANUAL);
        t.setCatatanAsli("kasbon:" + k.getId());
        transaksi.simpanManual(pedagangId, t);
        return repo.save(k);
    }

    @Transactional
    public void hapus(UUID pedagangId, UUID kasbonId) {
        repo.delete(ambil(pedagangId, kasbonId));
    }

    private Kasbon ambil(UUID pedagangId, UUID kasbonId) {
        return repo.findByIdAndPedagangId(kasbonId, pedagangId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Kasbon tidak ditemukan"));
    }

    // ---------------- membaca kalimat / suara ----------------

    private static final String INSTRUKSI = """
            Kamu membaca catatan kasbon (utang pelanggan) pedagang kecil Indonesia. Contoh: "Bu Ani ngutang 20 ribu
            buat beras", "Pak Budi ngebon rokok 2 bungkus 50rb". Ambil nama pelanggan (dengan sapaannya, misal "Bu Ani"),
            nominal rupiah (bilangan bulat, "20 ribu"/"20rb"/"20k" = 20000), dan keterangan barang singkat bila ada.
            transkrip berisi kalimat yang didengar atau teks masukan apa adanya. Bila nama atau nominal tidak ada, isi null.""";

    private static final Map<String, Object> SKEMA = Map.of(
            "type", "OBJECT",
            "properties", Map.of(
                    "transkrip", Map.of("type", "STRING"),
                    "nama", Map.of("type", "STRING", "nullable", true),
                    "nominal", Map.of("type", "INTEGER", "nullable", true),
                    "keterangan", Map.of("type", "STRING", "nullable", true)),
            "required", List.of("transkrip"));

    public Draf bacaTeks(String teks) {
        Draf aturan = bacaAturan(teks);
        if (aturan.galat() == null) return aturan;
        JsonNode j = gemini.jsonBebas(INSTRUKSI, List.of(Map.of("text", teks)), SKEMA);
        return j == null ? aturan : dariJson(j, teks);
    }

    public Draf bacaSuara(byte[] audio, String mime) {
        String m = mime == null ? "audio/wav" : mime.split(";")[0].trim();
        JsonNode j = gemini.jsonBebas(INSTRUKSI, List.of(
                Map.of("inlineData", Map.of("mimeType", m, "data", Base64.getEncoder().encodeToString(audio))),
                Map.of("text", "Ini voice note catatan kasbon. Dengarkan lalu uraikan.")), SKEMA);
        if (j == null) return new Draf(null, null, null, "", "AI sedang tidak bisa dihubungi, coba ketik saja");
        return dariJson(j, null);
    }

    private Draf dariJson(JsonNode j, String asli) {
        String transkrip = j.path("transkrip").asText(asli == null ? "" : asli);
        String nama = j.hasNonNull("nama") ? j.get("nama").asText().trim() : null;
        Long nominal = j.hasNonNull("nominal") && j.get("nominal").asLong() > 0 ? j.get("nominal").asLong() : null;
        String ket = j.hasNonNull("keterangan") ? j.get("keterangan").asText().trim() : null;
        String galat = nama == null || nama.isBlank() ? "Nama pelanggan belum terdengar"
                : nominal == null ? "Nominal kasbon belum terdengar" : null;
        return new Draf(nama == null ? null : rapikanNama(nama), nominal, ket == null || ket.isBlank() ? null : ket, transkrip, galat);
    }

    private static final Pattern KATA_UTANG = Pattern.compile("\\b(ngutang|utang|hutang|ngebon|kasbon|bon|minjem|pinjam)\\b",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern UANG = Pattern.compile("(\\d+(?:[.,]\\d+)*)\\s*(rb|ribu|k|jt|juta)?\\b", Pattern.CASE_INSENSITIVE);

    /** Pembaca sederhana tanpa AI untuk kalimat pola "<nama> ngutang <nominal> [buat <barang>]". */
    static Draf bacaAturan(String teks) {
        String t = teks == null ? "" : teks.trim();
        Matcher ku = KATA_UTANG.matcher(t);
        if (!ku.find()) return new Draf(null, null, null, t, "Kalimat tidak dikenali");
        String nama = t.substring(0, ku.start()).trim();
        String sisa = t.substring(ku.end());
        Matcher u = UANG.matcher(sisa);
        Long nominal = null;
        int akhirAngka = 0, awalAngka = 0;
        while (u.find()) {
            String raw = u.group(1);
            String s = u.group(2) == null ? "" : u.group(2).toLowerCase(Locale.ROOT);
            boolean ribuan = raw.matches("\\d{1,3}(\\.\\d{3})+");   // 20.000 atau 1.500.000
            double v = ribuan ? Long.parseLong(raw.replace(".", "")) : Double.parseDouble(raw.replace(',', '.'));
            long n = switch (s) {
                case "rb", "ribu", "k" -> Math.round(v * 1_000);
                case "jt", "juta" -> Math.round(v * 1_000_000);
                default -> v >= 1000 ? Math.round(v) : -1;   // angka kecil tanpa "ribu" dianggap jumlah barang
            };
            if (n > 0) {
                nominal = n;
                awalAngka = u.start();
                akhirAngka = u.end();
                break;
            }
        }
        if (nama.isBlank() || nominal == null) return new Draf(null, null, null, t, "Belum lengkap");
        // keterangan: setelah nominal ("... 20 ribu buat beras") atau sebelumnya ("ngebon rokok 2 bungkus 50rb")
        String ket = sisa.substring(akhirAngka).replaceAll("^\\s*(buat|untuk|beli|utk)\\s+", "").trim();
        if (ket.isBlank()) ket = sisa.substring(0, awalAngka).replaceAll("^\\s*(buat|untuk|beli|utk)\\s+", "").trim();
        return new Draf(rapikanNama(nama), nominal, ket.isBlank() ? null : ket, t, null);
    }

    static String rapikanNama(String nama) {
        String n = nama.trim().replaceAll("\\s+", " ");
        if (n.length() > 80) n = n.substring(0, 80);
        StringBuilder sb = new StringBuilder();
        for (String w : n.split(" ")) {
            if (w.isEmpty()) continue;
            if (!sb.isEmpty()) sb.append(' ');
            sb.append(Character.toUpperCase(w.charAt(0))).append(w.substring(1));
        }
        return sb.toString();
    }
}
