package id.vokas.web;

import id.vokas.config.VokasProperties;
import id.vokas.parser.HasilBaca;
import id.vokas.parser.PembacaGemini;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

/** Alat cek: apakah Gemini bisa dipanggil dengan API key dan model yang terpasang. */
@RestController
@RequestMapping("/api/ai")
public class AiController {

    private final PembacaGemini gemini;
    private final VokasProperties props;
    private final id.vokas.service.TanyaService tanyaService;
    private final id.vokas.service.RiwayatService riwayat;

    public AiController(PembacaGemini gemini, VokasProperties props, id.vokas.service.TanyaService tanyaService,
                        id.vokas.service.RiwayatService riwayat) {
        this.riwayat = riwayat;
        this.gemini = gemini;
        this.props = props;
        this.tanyaService = tanyaService;
    }

    public record Pertanyaan(@jakarta.validation.constraints.NotBlank
                             @jakarta.validation.constraints.Size(max = 500) String pertanyaan) {}

    /** Tanya AI tentang usaha sendiri. */
    @org.springframework.web.bind.annotation.PostMapping("/pedagang/{id}/tanya")
    public PembacaGemini.Jawaban tanya(@org.springframework.web.bind.annotation.PathVariable java.util.UUID id,
                                       @jakarta.validation.Valid @org.springframework.web.bind.annotation.RequestBody Pertanyaan p) {
        PembacaGemini.Jawaban j = tanyaService.tanya(id, p.pertanyaan());
        riwayat.simpanTanya(id, p.pertanyaan(), j);
        return j;
    }

    @GetMapping("/cek")
    public Map<String, Object> cek() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("apiKeyTerisi", gemini.aktif());
        out.put("model", props.gemini().model());
        out.put("urutanModel", gemini.daftarModel());
        if (!gemini.aktif()) {
            out.put("ok", false);
            out.put("galat", "GEMINI_API_KEY belum diisi di server");
            return out;
        }
        HasilBaca h = gemini.bacaTeks("jual cilok dua bungkus dua ribuan");
        out.put("ok", h.galat() == null && !h.items().isEmpty());
        out.put("galat", h.galat());
        out.put("contohHasil", h.items());
        return out;
    }
}
