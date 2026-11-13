package id.vokas.web;

import id.vokas.model.Pedagang;
import id.vokas.model.Produk;
import id.vokas.repo.PedagangRepo;
import id.vokas.repo.ProdukRepo;
import id.vokas.service.TransaksiService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/pedagang")
public class PedagangController {

    private final PedagangRepo repo;
    private final ProdukRepo produkRepo;
    private final TransaksiService transaksi;

    public PedagangController(PedagangRepo repo, ProdukRepo produkRepo, TransaksiService transaksi) {
        this.repo = repo;
        this.produkRepo = produkRepo;
        this.transaksi = transaksi;
    }

    public record PedagangBaru(@NotBlank String nama, String namaUsaha,
                               @Pattern(regexp = "^62\\d{8,13}$", message = "format 62xxxxxxxxxx") String noWa,
                               boolean rekeningTerpisah) {}

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Pedagang buat(@Valid @RequestBody PedagangBaru b) {
        Pedagang p = new Pedagang();
        p.setNama(b.nama());
        p.setNamaUsaha(b.namaUsaha());
        p.setNoWa(b.noWa());
        p.setRekeningTerpisah(b.rekeningTerpisah());
        return repo.save(p);
    }

    @GetMapping("/{id}")
    public Pedagang ambil(@PathVariable UUID id) {
        return transaksi.pedagang(id);
    }

    @PatchMapping("/{id}")
    public Pedagang ubah(@PathVariable UUID id, @RequestBody PedagangBaru b) {
        Pedagang p = transaksi.pedagang(id);
        if (b.nama() != null && !b.nama().isBlank()) p.setNama(b.nama());
        if (b.namaUsaha() != null) p.setNamaUsaha(b.namaUsaha());
        p.setRekeningTerpisah(b.rekeningTerpisah());
        return repo.save(p);
    }

    @GetMapping("/{id}/produk")
    public List<Produk> produk(@PathVariable UUID id) {
        return produkRepo.findByPedagangIdOrderByNama(id);
    }

    public record ProdukBaru(@NotBlank String nama, String satuan, Long hargaJual) {}

    @PostMapping("/{id}/produk")
    @ResponseStatus(HttpStatus.CREATED)
    public Produk tambahProduk(@PathVariable UUID id, @Valid @RequestBody ProdukBaru b) {
        transaksi.pedagang(id);
        Produk pr = new Produk();
        pr.setPedagangId(id);
        pr.setNama(b.nama().toLowerCase().trim());
        pr.setSatuan(b.satuan());
        pr.setHargaJual(b.hargaJual());
        return produkRepo.save(pr);
    }
}
