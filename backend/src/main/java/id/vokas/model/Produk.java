package id.vokas.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "produk")
public class Produk {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private UUID pedagangId;

    @Column(nullable = false)
    private String nama;

    private String satuan;
    private Long hargaJual;

    public UUID getId() { return id; }
    public UUID getPedagangId() { return pedagangId; }
    public void setPedagangId(UUID pedagangId) { this.pedagangId = pedagangId; }
    public String getNama() { return nama; }
    public void setNama(String nama) { this.nama = nama; }
    public String getSatuan() { return satuan; }
    public void setSatuan(String satuan) { this.satuan = satuan; }
    public Long getHargaJual() { return hargaJual; }
    public void setHargaJual(Long hargaJual) { this.hargaJual = hargaJual; }
}
