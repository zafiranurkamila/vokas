package id.vokas.parser;

import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

/**
 * Teks: coba aturan dulu (gratis, instan). Bila ada potongan yang tidak terbaca, minta Gemini.
 * Suara: langsung ke Gemini, karena aturan tidak bisa mendengar.
 * Dengan begini kuota gratis Gemini hanya terpakai untuk kalimat yang memang sulit dan untuk voice note.
 */
@Component
@Primary
public class PembacaGabungan implements PembacaCatatan {

    private final PembacaAturan aturan;
    private final PembacaGemini gemini;

    public PembacaGabungan(PembacaAturan aturan, PembacaGemini gemini) {
        this.aturan = aturan;
        this.gemini = gemini;
    }

    @Override
    public String nama() { return "gabungan"; }

    @Override
    public HasilBaca bacaTeks(String teks) {
        HasilBaca h = aturan.bacaTeks(teks);
        if (h.lengkap() || !gemini.aktif()) return h;
        HasilBaca g = gemini.bacaTeks(teks);
        return g.items().isEmpty() ? h : g;   // bila Gemini gagal, pakai hasil aturan yang sebagian
    }

    @Override
    public HasilBaca bacaSuara(byte[] audio, String mimeType) {
        return gemini.bacaSuara(audio, mimeType);
    }
}
