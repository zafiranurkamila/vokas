package id.vokas.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Target tabungan pedagang, misalnya untuk DP atau cicilan KUR. Satu pedagang satu celengan. */
@Entity
@Table(name = "celengan")
public class Celengan {
    @Id
    private UUID pedagangId;
    @Column(nullable = false) private String nama;
    @Column(nullable = false) private long target;
    @Column(nullable = false) private int persen = 10;
    @Column(nullable = false) private OffsetDateTime diubah = OffsetDateTime.now();

    public UUID getPedagangId() { return pedagangId; }
    public void setPedagangId(UUID v) { pedagangId = v; }
    public String getNama() { return nama; }
    public void setNama(String v) { nama = v; }
    public long getTarget() { return target; }
    public void setTarget(long v) { target = v; }
    public int getPersen() { return persen; }
    public void setPersen(int v) { persen = v; }
    public OffsetDateTime getDiubah() { return diubah; }
    public void setDiubah(OffsetDateTime v) { diubah = v; }
}
