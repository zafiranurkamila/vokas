package id.vokas.model;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "transaksi")
public class Transaksi {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private UUID pedagangId;

    @Column(nullable = false)
    private LocalDate tanggal;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Jenis jenis;

    @Column(nullable = false)
    private String namaItem;

    private Integer jumlah;
    private String satuan;
    private Long hargaSatuan;

    @Column(nullable = false)
    private long total;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Metode metode = Metode.TUNAI;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Sumber sumber;

    private String catatanAsli;

    /** id mutasi QRIS dari ekspor rekening, untuk mencegah impor ganda */
    private String refEksternal;

    /** true = mutasi transfer yang belum dikonfirmasi sebagai uang usaha, tidak masuk laporan */
    @Column(nullable = false)
    private boolean perluCek;

    @Column(nullable = false, updatable = false, insertable = false)
    private OffsetDateTime dibuat;

    public UUID getId() { return id; }
    public UUID getPedagangId() { return pedagangId; }
    public void setPedagangId(UUID pedagangId) { this.pedagangId = pedagangId; }
    public LocalDate getTanggal() { return tanggal; }
    public void setTanggal(LocalDate tanggal) { this.tanggal = tanggal; }
    public Jenis getJenis() { return jenis; }
    public void setJenis(Jenis jenis) { this.jenis = jenis; }
    public String getNamaItem() { return namaItem; }
    public void setNamaItem(String namaItem) { this.namaItem = namaItem; }
    public Integer getJumlah() { return jumlah; }
    public void setJumlah(Integer jumlah) { this.jumlah = jumlah; }
    public String getSatuan() { return satuan; }
    public void setSatuan(String satuan) { this.satuan = satuan; }
    public Long getHargaSatuan() { return hargaSatuan; }
    public void setHargaSatuan(Long hargaSatuan) { this.hargaSatuan = hargaSatuan; }
    public long getTotal() { return total; }
    public void setTotal(long total) { this.total = total; }
    public Metode getMetode() { return metode; }
    public void setMetode(Metode metode) { this.metode = metode; }
    public Sumber getSumber() { return sumber; }
    public void setSumber(Sumber sumber) { this.sumber = sumber; }
    public String getCatatanAsli() { return catatanAsli; }
    public void setCatatanAsli(String catatanAsli) { this.catatanAsli = catatanAsli; }
    public String getRefEksternal() { return refEksternal; }
    public void setRefEksternal(String refEksternal) { this.refEksternal = refEksternal; }
    public boolean isPerluCek() { return perluCek; }
    public void setPerluCek(boolean perluCek) { this.perluCek = perluCek; }
    public OffsetDateTime getDibuat() { return dibuat; }
}
