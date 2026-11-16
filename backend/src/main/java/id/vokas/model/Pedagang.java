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

    private String email;

    @Column(nullable = false)
    private boolean emailTerverifikasi;

    @com.fasterxml.jackson.annotation.JsonIgnore
    private String emailKodeHash;

    @com.fasterxml.jackson.annotation.JsonIgnore
    private OffsetDateTime emailKodeSampai;

    @Column(nullable = false)
    private boolean laporanEmail = true;

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
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public boolean isEmailTerverifikasi() { return emailTerverifikasi; }
    public void setEmailTerverifikasi(boolean v) { this.emailTerverifikasi = v; }
    public String getEmailKodeHash() { return emailKodeHash; }
    public void setEmailKodeHash(String v) { this.emailKodeHash = v; }
    public OffsetDateTime getEmailKodeSampai() { return emailKodeSampai; }
    public void setEmailKodeSampai(OffsetDateTime v) { this.emailKodeSampai = v; }
    public boolean isLaporanEmail() { return laporanEmail; }
    public void setLaporanEmail(boolean v) { this.laporanEmail = v; }
}
