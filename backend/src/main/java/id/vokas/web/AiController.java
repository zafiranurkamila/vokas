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

    public AiController(PembacaGemini gemini, VokasProperties props) {
        this.gemini = gemini;
        this.props = props;
    }

    @GetMapping("/cek")
    public Map<String, Object> cek() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("apiKeyTerisi", gemini.aktif());
        out.put("model", props.gemini().model());
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
