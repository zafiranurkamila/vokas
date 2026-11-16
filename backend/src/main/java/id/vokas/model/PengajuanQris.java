package id.vokas.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Pengajuan merchant QRIS BRI yang dikirim lewat VoKas. */
@Entity
@Table(name = "pengajuan_qris")
public class PengajuanQris {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(nullable = false, unique = true)
    private UUID pedagangId;
    @Column(nullable = false) private String namaPemilik;
    @Column(nullable = false) private String namaUsaha;
    @Column(nullable = false) private String kategori;
    @Column(nullable = false) private String alamat;
    @Column(nullable = false) private String kota;
    @Column(nullable = false) private String kisaranOmzet;
    @Column(nullable = false) private String rekeningAkhir;
    private String jenisRekening;
    @Column(nullable = false) private String status = "DIAJUKAN";
    private String nmid;
    @Column(nullable = false) private String referensi;
    @Column(nullable = false, updatable = false, insertable = false)
    private OffsetDateTime dibuat;
    @Column(nullable = false)
    private OffsetDateTime diperbarui = OffsetDateTime.now();

    public UUID getId() { return id; }
    public UUID getPedagangId() { return pedagangId; }
    public void setPedagangId(UUID v) { pedagangId = v; }
    public String getNamaPemilik() { return namaPemilik; }
    public void setNamaPemilik(String v) { namaPemilik = v; }
    public String getNamaUsaha() { return namaUsaha; }
    public void setNamaUsaha(String v) { namaUsaha = v; }
    public String getKategori() { return kategori; }
    public void setKategori(String v) { kategori = v; }
    public String getAlamat() { return alamat; }
    public void setAlamat(String v) { alamat = v; }
    public String getKota() { return kota; }
    public void setKota(String v) { kota = v; }
    public String getKisaranOmzet() { return kisaranOmzet; }
    public void setKisaranOmzet(String v) { kisaranOmzet = v; }
    public String getRekeningAkhir() { return rekeningAkhir; }
    public void setRekeningAkhir(String v) { rekeningAkhir = v; }
    public String getJenisRekening() { return jenisRekening; }
    public void setJenisRekening(String v) { jenisRekening = v; }
    public String getStatus() { return status; }
    public void setStatus(String v) { status = v; }
    public String getNmid() { return nmid; }
    public void setNmid(String v) { nmid = v; }
    public String getReferensi() { return referensi; }
    public void setReferensi(String v) { referensi = v; }
    public OffsetDateTime getDibuat() { return dibuat; }
    public OffsetDateTime getDiperbarui() { return diperbarui; }
    public void setDiperbarui(OffsetDateTime v) { diperbarui = v; }
}
