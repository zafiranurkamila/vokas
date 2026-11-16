package id.vokas.web;

import id.vokas.model.PengajuanQris;
import id.vokas.repo.PengajuanQrisRepo;
import id.vokas.service.TransaksiService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Pengajuan merchant QRIS BRI lewat VoKas.
 * Skema kerja sama: VoKas mengumpulkan data usaha lalu meneruskannya ke BRI; BRI memverifikasi identitas dan
 * rekening, lalu menerbitkan QRIS (NMID). Selama belum terhubung ke API onboarding BRI, tahap verifikasi
 * disimulasikan berdasarkan waktu (diajukan -> diverifikasi BRI -> aktif) dan ditandai "simulasi".
 */
@RestController
@RequestMapping("/api/pedagang/{id}/qris")
public class QrisController {

    static final Duration KE_VERIFIKASI = Duration.ofMinutes(1);
    static final Duration KE_AKTIF = Duration.ofMinutes(3);

    private final PengajuanQrisRepo repo;
    private final TransaksiService transaksi;

    public QrisController(PengajuanQrisRepo repo, TransaksiService transaksi) {
        this.repo = repo;
        this.transaksi = transaksi;
    }

    public record Pengajuan(@NotBlank @Size(max = 120) String namaPemilik, @NotBlank @Size(max = 160) String namaUsaha,
                            @NotBlank String kategori, @NotBlank @Size(max = 300) String alamat, @NotBlank String kota,
                            @NotBlank String kisaranOmzet,
                            @Pattern(regexp = "^\\d{10,16}$", message = "nomor rekening BRI 10-16 angka") String nomorRekening,
                            @AssertTrue(message = "persetujuan wajib") boolean setuju) {}

    @PostMapping
    public Map<String, Object> ajukan(@PathVariable UUID id, @Valid @RequestBody Pengajuan b) {
        transaksi.pedagang(id);
        if (repo.findByPedagangId(id).isPresent())
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Pengajuan QRIS sudah ada");
        PengajuanQris q = new PengajuanQris();
        q.setPedagangId(id);
        q.setNamaPemilik(b.namaPemilik().trim());
        q.setNamaUsaha(b.namaUsaha().trim());
        q.setKategori(b.kategori());
        q.setAlamat(b.alamat().trim());
        q.setKota(b.kota().trim());
        q.setKisaranOmzet(b.kisaranOmzet());
        q.setRekeningAkhir(b.nomorRekening().substring(b.nomorRekening().length() - 4));   // nomor lengkap tidak disimpan
        q.setReferensi("VKQ-" + Long.toString(Math.abs(UUID.randomUUID().getMostSignificantBits()) % 100_000_000L, 36).toUpperCase());
        q.setDiperbarui(OffsetDateTime.now());
        return tampil(repo.save(q));
    }

    @GetMapping
    public Map<String, Object> status(@PathVariable UUID id) {
        return repo.findByPedagangId(id).map(this::tampil)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Belum ada pengajuan QRIS"));
    }

    /** Hapus pengajuan (demo): supaya alur bisa diulang. */
    @DeleteMapping
    public Map<String, Object> batal(@PathVariable UUID id) {
        repo.findByPedagangId(id).ifPresent(repo::delete);
        return Map.of("dihapus", true);
    }

    private Map<String, Object> tampil(PengajuanQris q) {
        OffsetDateTime awal = q.getDiperbarui();
        Duration lama = Duration.between(awal, OffsetDateTime.now());
        String status = lama.compareTo(KE_AKTIF) >= 0 ? "AKTIF" : lama.compareTo(KE_VERIFIKASI) >= 0 ? "VERIFIKASI" : "DIAJUKAN";
        if (!status.equals(q.getStatus())) {
            q.setStatus(status);
            if ("AKTIF".equals(status) && q.getNmid() == null)
                q.setNmid("ID1026" + String.format("%09d", Math.abs(q.getId().getLeastSignificantBits()) % 1_000_000_000L));
            q = repo.save(q);
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("referensi", q.getReferensi());
        out.put("status", q.getStatus());
        out.put("nmid", q.getNmid());
        out.put("namaUsaha", q.getNamaUsaha());
        out.put("namaPemilik", q.getNamaPemilik());
        out.put("kategori", q.getKategori());
        out.put("kota", q.getKota());
        out.put("rekeningAkhir", q.getRekeningAkhir());
        out.put("diajukan", awal.toString());
        out.put("simulasi", true);
        out.put("tahap", List.of(
                tahap("Pengajuan diterima VoKas", "Data usaha dan rekening BRI dikirim ke BRI.", true, awal),
                tahap("Verifikasi BRI", "BRI memeriksa identitas pemilik dan rekening penampung dana.",
                        !"DIAJUKAN".equals(q.getStatus()), awal.plus(KE_VERIFIKASI)),
                tahap("QRIS aktif", q.getNmid() == null ? "QRIS BRI terbit dan siap dipasang di lapak."
                        : "NMID " + q.getNmid() + ". Pembayaran masuk ke rekening BRI ****" + q.getRekeningAkhir() + ".",
                        "AKTIF".equals(q.getStatus()), awal.plus(KE_AKTIF))));
        return out;
    }

    private static Map<String, Object> tahap(String judul, String ket, boolean selesai, OffsetDateTime waktu) {
        return Map.of("judul", judul, "keterangan", ket, "selesai", selesai, "waktu", waktu.toString());
    }
}
