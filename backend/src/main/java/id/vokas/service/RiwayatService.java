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
    private final id.vokas.repo.RiwayatAudioRepo audioRepo;
    private final ObjectMapper json;

    public RiwayatService(RiwayatAiRepo repo, id.vokas.repo.RiwayatAudioRepo audioRepo, ObjectMapper json) {
        this.repo = repo;
        this.audioRepo = audioRepo;
        this.json = json;
    }

    public void simpanTanya(UUID pedagangId, String pertanyaan, PembacaGemini.Jawaban j) {
        simpan(new RiwayatAi(pedagangId, TANYA, null, pertanyaan, j.teks(), j.galat()));
    }

    public void simpanCatat(UUID pedagangId, String sumber, String masukan, TransaksiService.HasilCatat h) {
        simpanCatat(pedagangId, sumber, masukan, h, null, null);
    }

    /** Sama seperti di atas, sekaligus menyimpan rekaman voice note supaya bisa diputar ulang. */
    public void simpanCatat(UUID pedagangId, String sumber, String masukan, TransaksiService.HasilCatat h,
                            byte[] audio, String mime) {
        try {
            String hasil = json.writeValueAsString(h);
            String galat = h.tersimpan().isEmpty() ? (h.baca().galat() != null ? h.baca().galat() : "Nominal belum terbaca") : null;
            String teks = h.baca().transkrip() != null && !h.baca().transkrip().isBlank() ? h.baca().transkrip() : masukan;
            RiwayatAi r = new RiwayatAi(pedagangId, CATAT, sumber, teks, hasil, galat);
            boolean pakaiAudio = audio != null && audio.length > 0;
            r.setAdaAudio(pakaiAudio);
            r = repo.save(r);
            if (pakaiAudio) {
                audioRepo.save(new id.vokas.model.RiwayatAudio(r.getId(), mime == null ? "audio/wav" : mime.split(";")[0], audio));
                audioRepo.pangkas(pedagangId);
                audioRepo.tandaiTerpangkas(pedagangId);
            }
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

    /** Rekaman suara satu entri riwayat milik pedagang ini, atau null. */
    public id.vokas.model.RiwayatAudio audio(UUID pedagangId, UUID riwayatId) {
        return repo.findById(riwayatId)
                .filter(r -> r.getPedagangId().equals(pedagangId))
                .flatMap(r -> audioRepo.findById(riwayatId))
                .orElse(null);
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
