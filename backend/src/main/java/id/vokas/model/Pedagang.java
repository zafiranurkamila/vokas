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

    @com.fasterxml.jackson.annotation.JsonIgnore
    private String pinHash;

    @com.fasterxml.jackson.annotation.JsonIgnore
    private String googleSub;

    @com.fasterxml.jackson.annotation.JsonIgnore
    @Column(nullable = false)
    private int gagalPin;

    @com.fasterxml.jackson.annotation.JsonIgnore
    private OffsetDateTime kunciSampai;

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
    public String getPinHash() { return pinHash; }
    public void setPinHash(String v) { this.pinHash = v; }
    /** Untuk aplikasi: apakah akun sudah punya PIN di server. */
    public boolean isPunyaPin() { return pinHash != null; }
    public String getGoogleSub() { return googleSub; }
    public void setGoogleSub(String v) { this.googleSub = v; }
    public int getGagalPin() { return gagalPin; }
    public void setGagalPin(int v) { this.gagalPin = v; }
    public OffsetDateTime getKunciSampai() { return kunciSampai; }
    public void setKunciSampai(OffsetDateTime v) { this.kunciSampai = v; }
}
