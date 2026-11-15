package id.vokas.bri;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/bri")
public class BriController {

    private final BriService bri;
    private final BriSnapClient klien;

    public BriController(BriService bri, BriSnapClient klien) {
        this.bri = bri;
        this.klien = klien;
    }

    /** Apakah kredensial BRIAPI sudah dipasang di server. */
    @GetMapping("/status")
    public Map<String, Object> status() {
        return Map.of("aktif", klien.aktif(), "lingkungan", "sandbox");
    }

    public record PermintaanSinkron(@NotBlank String accountNo, Integer hari) {}

    /** Ambil mutasi rekening dari BRIAPI lalu catat ke VoKas (ref yang sama tidak dicatat dua kali). */
    @PostMapping("/pedagang/{id}/sinkron-mutasi")
    public BriService.HasilSinkron sinkron(@PathVariable UUID id, @Valid @RequestBody PermintaanSinkron p) {
        return bri.sinkron(id, p.accountNo().replaceAll("\\D", ""), p.hari() == null ? 7 : p.hari());
    }
}
