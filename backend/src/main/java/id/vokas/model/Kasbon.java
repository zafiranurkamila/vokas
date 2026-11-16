package id.vokas.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Utang pelanggan ke pedagang (kasbon / ngebon). */
@Entity
@Table(name = "kasbon")
public class Kasbon {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(nullable = false) private UUID pedagangId;
    @Column(nullable = false) private String namaPelanggan;
    @Column(nullable = false) private long nominal;
    private String keterangan;
    private String noWa;
    @Column(nullable = false) private boolean lunas;
    @Column(nullable = false, updatable = false, insertable = false)
    private OffsetDateTime dibuat;
    private OffsetDateTime dilunasi;

    public UUID getId() { return id; }
    public UUID getPedagangId() { return pedagangId; }
    public void setPedagangId(UUID v) { pedagangId = v; }
    public String getNamaPelanggan() { return namaPelanggan; }
    public void setNamaPelanggan(String v) { namaPelanggan = v; }
    public long getNominal() { return nominal; }
    public void setNominal(long v) { nominal = v; }
    public String getKeterangan() { return keterangan; }
    public void setKeterangan(String v) { keterangan = v; }
    public String getNoWa() { return noWa; }
    public void setNoWa(String v) { noWa = v; }
    public boolean isLunas() { return lunas; }
    public void setLunas(boolean v) { lunas = v; }
    public OffsetDateTime getDibuat() { return dibuat; }
    public OffsetDateTime getDilunasi() { return dilunasi; }
    public void setDilunasi(OffsetDateTime v) { dilunasi = v; }
}
