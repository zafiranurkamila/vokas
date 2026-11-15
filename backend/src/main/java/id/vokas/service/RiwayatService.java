package id.vokas.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import id.vokas.model.RiwayatAi;
import id.vokas.parser.PembacaGemini;
import id.vokas.repo.RiwayatAiRepo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * Menyimpan riwayat Tanya AI dan catatan suara/teks. Kegagalan menyimpan riwayat tidak boleh
 * menggagalkan jawaban ke pengguna, jadi galatnya hanya dicatat di log.
 */
@Service
public class RiwayatService {

    public static final String TANYA = "TANYA";
    public static final String CATAT = "CATAT";
    private static final Logger log = LoggerFactory.getLogger(RiwayatService.class);

    private final RiwayatAiRepo repo;
    private final ObjectMapper json;

    public RiwayatService(RiwayatAiRepo repo, ObjectMapper json) {
        this.repo = repo;
        this.json = json;
    }

    public void simpanTanya(UUID pedagangId, String pertanyaan, PembacaGemini.Jawaban j) {
        simpan(new RiwayatAi(pedagangId, TANYA, null, pertanyaan, j.teks(), j.galat()));
    }

    public void simpanCatat(UUID pedagangId, String sumber, String masukan, TransaksiService.HasilCatat h) {
        try {
            String hasil = json.writeValueAsString(h);
            String galat = h.tersimpan().isEmpty() ? (h.baca().galat() != null ? h.baca().galat() : "Nominal belum terbaca") : null;
            String teks = h.baca().transkrip() != null && !h.baca().transkrip().isBlank() ? h.baca().transkrip() : masukan;
            simpan(new RiwayatAi(pedagangId, CATAT, sumber, teks, hasil, galat));
        } catch (Exception e) {
            log.warn("Riwayat catat tidak tersimpan: {}", e.getMessage());
        }
    }

    /** Riwayat terbaru (maks 50), diurutkan dari yang paling lama supaya enak dibaca seperti percakapan. */
    public List<RiwayatAi> daftar(UUID pedagangId, String jenis) {
        List<RiwayatAi> r = new ArrayList<>(repo.findTop50ByPedagangIdAndJenisOrderByDibuatDesc(pedagangId, jenis));
        Collections.reverse(r);
        return r;
    }

    public int hapus(UUID pedagangId, String jenis) {
        return repo.deleteByPedagangIdAndJenis(pedagangId, jenis);
    }

    private void simpan(RiwayatAi r) {
        try {
            repo.save(r);
        } catch (Exception e) {
            log.warn("Riwayat tidak tersimpan: {}", e.getMessage());
        }
    }
}
