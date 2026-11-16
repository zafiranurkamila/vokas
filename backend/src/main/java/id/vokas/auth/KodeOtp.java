package id.vokas.auth;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Kode verifikasi 6 angka yang dikirim ke email (daftar, masuk tanpa PIN, lupa PIN). Disimpan sebagai hash. */
@Entity
@Table(name = "kode_otp")
public class KodeOtp {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String email;

    @Column(nullable = false)
    private String keperluan;

    @Column(nullable = false)
    private String kodeHash;

    @Column(nullable = false)
    private int percobaan;

    @Column(nullable = false)
    private OffsetDateTime kedaluwarsa;

    @Column(nullable = false, updatable = false, insertable = false)
    private OffsetDateTime dibuat;

    public KodeOtp() {}

    public KodeOtp(String email, String keperluan, String kodeHash, OffsetDateTime kedaluwarsa) {
        this.email = email;
        this.keperluan = keperluan;
        this.kodeHash = kodeHash;
        this.kedaluwarsa = kedaluwarsa;
    }

    public UUID getId() { return id; }
    public String getEmail() { return email; }
    public String getKeperluan() { return keperluan; }
    public String getKodeHash() { return kodeHash; }
    public int getPercobaan() { return percobaan; }
    public void setPercobaan(int percobaan) { this.percobaan = percobaan; }
    public OffsetDateTime getKedaluwarsa() { return kedaluwarsa; }
    public void setKedaluwarsa(OffsetDateTime kedaluwarsa) { this.kedaluwarsa = kedaluwarsa; }
    public OffsetDateTime getDibuat() { return dibuat; }
}
