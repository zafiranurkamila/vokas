package id.vokas.web;

import id.vokas.model.Kasbon;
import id.vokas.service.CelenganService;
import id.vokas.service.KasbonService;
import id.vokas.service.WawasanService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

/** Fitur usaha: kasbon pelanggan, celengan, saran belanja besok, dan peringatan pintar. */
@RestController
@RequestMapping("/api/pedagang/{id}")
public class UsahaController {

    private final KasbonService kasbon;
    private final CelenganService celengan;
    private final WawasanService wawasan;

    public UsahaController(KasbonService kasbon, CelenganService celengan, WawasanService wawasan) {
        this.kasbon = kasbon;
        this.celengan = celengan;
        this.wawasan = wawasan;
    }

    // ---------------- kasbon ----------------

    @GetMapping("/kasbon")
    public KasbonService.Ringkasan daftarKasbon(@PathVariable UUID id) {
        return kasbon.daftar(id);
    }

    public record KasbonBaru(@NotBlank @Size(max = 80) String namaPelanggan, @Positive long nominal,
                             @Size(max = 200) String keterangan, @Size(max = 20) String noWa) {}

    @PostMapping("/kasbon")
    @ResponseStatus(HttpStatus.CREATED)
    public Kasbon tambahKasbon(@PathVariable UUID id, @Valid @RequestBody KasbonBaru b) {
        return kasbon.tambah(id, b.namaPelanggan(), b.nominal(), b.keterangan(), b.noWa());
    }

    public record Kalimat(@NotBlank @Size(max = 300) String teks) {}

    /** Baca kalimat seperti "Bu Ani ngutang 20 ribu buat beras" menjadi draf (belum disimpan). */
    @PostMapping("/kasbon/baca")
    public KasbonService.Draf bacaKasbon(@PathVariable UUID id, @Valid @RequestBody Kalimat k) {
        return kasbon.bacaTeks(k.teks());
    }

    @PostMapping(value = "/kasbon/baca-suara", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public KasbonService.Draf bacaKasbonSuara(@PathVariable UUID id, @RequestParam("audio") MultipartFile audio) throws IOException {
        if (audio.isEmpty() || audio.getSize() > 6L * 1024 * 1024)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Audio kosong atau terlalu besar");
        return kasbon.bacaSuara(audio.getBytes(), audio.getContentType());
    }

    @PostMapping("/kasbon/{kasbonId}/lunas")
    public Kasbon lunasKasbon(@PathVariable UUID id, @PathVariable UUID kasbonId) {
        return kasbon.lunas(id, kasbonId);
    }

    @DeleteMapping("/kasbon/{kasbonId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void hapusKasbon(@PathVariable UUID id, @PathVariable UUID kasbonId) {
        kasbon.hapus(id, kasbonId);
    }

    // ---------------- celengan ----------------

    @GetMapping("/celengan")
    public CelenganService.Status statusCelengan(@PathVariable UUID id) {
        return celengan.status(id);
    }

    public record AturCelengan(@Size(max = 80) String nama, @Positive long target, int persen) {}

    @PutMapping("/celengan")
    public CelenganService.Status aturCelengan(@PathVariable UUID id, @Valid @RequestBody AturCelengan a) {
        return celengan.atur(id, a.nama(), a.target(), a.persen());
    }

    public record Setoran(long nominal, @Size(max = 120) String catatan) {}

    @PostMapping("/celengan/setor")
    public CelenganService.Status setor(@PathVariable UUID id, @Valid @RequestBody Setoran s) {
        return celengan.setor(id, s.nominal(), s.catatan());
    }

    // ---------------- wawasan ----------------

    @GetMapping("/saran-belanja")
    public WawasanService.Saran saranBelanja(@PathVariable UUID id) {
        return wawasan.saranBesok(id);
    }

    @GetMapping("/peringatan")
    public List<WawasanService.Peringatan> peringatan(@PathVariable UUID id) {
        return wawasan.peringatan(id);
    }
}
