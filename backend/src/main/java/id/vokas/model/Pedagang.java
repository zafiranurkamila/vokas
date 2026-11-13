package id.vokas.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "pedagang")
public class Pedagang {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String nama;

    private String namaUsaha;

    @Column(unique = true)
    private String noWa;

    @Column(nullable = false)
    private boolean rekeningTerpisah;

    @Column(nullable = false, updatable = false, insertable = false)
    private OffsetDateTime dibuat;

    public UUID getId() { return id; }
    public String getNama() { return nama; }
    public void setNama(String nama) { this.nama = nama; }
    public String getNamaUsaha() { return namaUsaha; }
    public void setNamaUsaha(String namaUsaha) { this.namaUsaha = namaUsaha; }
    public String getNoWa() { return noWa; }
    public void setNoWa(String noWa) { this.noWa = noWa; }
    public boolean isRekeningTerpisah() { return rekeningTerpisah; }
    public void setRekeningTerpisah(boolean rekeningTerpisah) { this.rekeningTerpisah = rekeningTerpisah; }
    public OffsetDateTime getDibuat() { return dibuat; }
}
