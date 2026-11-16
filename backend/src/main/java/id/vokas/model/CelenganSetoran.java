package id.vokas.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Satu setoran (positif) atau pengambilan (negatif) celengan. */
@Entity
@Table(name = "celengan_setoran")
public class CelenganSetoran {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(nullable = false) private UUID pedagangId;
    @Column(nullable = false) private long nominal;
    private String catatan;
    @Column(nullable = false, updatable = false, insertable = false)
    private OffsetDateTime dibuat;

    public CelenganSetoran() {}

    public CelenganSetoran(UUID pedagangId, long nominal, String catatan) {
        this.pedagangId = pedagangId;
        this.nominal = nominal;
        this.catatan = catatan;
    }

    public UUID getId() { return id; }
    public long getNominal() { return nominal; }
    public String getCatatan() { return catatan; }
    public OffsetDateTime getDibuat() { return dibuat; }
}
