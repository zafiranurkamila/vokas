package id.vokas.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Satu entri riwayat: pertanyaan Tanya AI beserta jawabannya, atau satu catatan suara/teks beserta hasilnya. */
@Entity
@Table(name = "riwayat_ai")
public class RiwayatAi {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private UUID pedagangId;

    @Column(nullable = false)
    private String jenis;

    private String sumber;
    private String masukan;
    private String jawaban;
    private String galat;

    /** true bila rekaman suaranya tersimpan di tabel riwayat_audio (bisa diputar ulang). */
    @Column(nullable = false)
    private boolean adaAudio;

    @Column(nullable = false, updatable = false, insertable = false)
    private OffsetDateTime dibuat;

    public RiwayatAi() {}

    public RiwayatAi(UUID pedagangId, String jenis, String sumber, String masukan, String jawaban, String galat) {
        this.pedagangId = pedagangId;
        this.jenis = jenis;
        this.sumber = sumber;
        this.masukan = masukan;
        this.jawaban = jawaban;
        this.galat = galat;
    }

    public UUID getId() { return id; }
    public UUID getPedagangId() { return pedagangId; }
    public String getJenis() { return jenis; }
    public String getSumber() { return sumber; }
    public String getMasukan() { return masukan; }
    public String getJawaban() { return jawaban; }
    public String getGalat() { return galat; }
    public OffsetDateTime getDibuat() { return dibuat; }
    public boolean isAdaAudio() { return adaAudio; }
    public void setAdaAudio(boolean v) { adaAudio = v; }
}
