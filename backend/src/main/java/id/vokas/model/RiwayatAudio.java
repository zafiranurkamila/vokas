package id.vokas.model;

import jakarta.persistence.*;
import java.util.UUID;

/** Rekaman voice note untuk satu entri riwayat catat. Dipisah supaya daftar riwayat tidak ikut memuat audio. */
@Entity
@Table(name = "riwayat_audio")
public class RiwayatAudio {
    @Id
    private UUID riwayatId;
    @Column(nullable = false)
    private String mime;
    @Column(nullable = false)
    private byte[] audio;

    public RiwayatAudio() {}

    public RiwayatAudio(UUID riwayatId, String mime, byte[] audio) {
        this.riwayatId = riwayatId;
        this.mime = mime;
        this.audio = audio;
    }

    public UUID getRiwayatId() { return riwayatId; }
    public String getMime() { return mime; }
    public byte[] getAudio() { return audio; }
}
