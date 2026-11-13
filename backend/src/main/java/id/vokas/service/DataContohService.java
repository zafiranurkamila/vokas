package id.vokas.service;

import id.vokas.model.*;
import id.vokas.repo.TransaksiRepo;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.UUID;

/**
 * Mengisi 90 hari data contoh untuk akun demo (warung cilok/cireng), supaya laporan dan Rapor KUR bisa
 * ditunjukkan saat presentasi. Semua baris ditandai catatanAsli = "[contoh]" dan bisa dihapus lagi.
 */
@Service
public class DataContohService {

    public static final String PENANDA = "[contoh]";

    private final TransaksiRepo repo;
    private final TransaksiService transaksi;

    public DataContohService(TransaksiRepo repo, TransaksiService transaksi) {
        this.repo = repo;
        this.transaksi = transaksi;
    }

    private record Barang(String nama, String satuan, long harga, int min, int max) {}

    private static final List<Barang> JUALAN = List.of(
            new Barang("cilok", "bungkus", 2_000, 25, 45),
            new Barang("cireng", "bungkus", 2_500, 15, 30),
            new Barang("es teh", "gelas", 3_000, 10, 25));

    @Transactional
    public int isi(UUID pedagangId) {
        transaksi.pedagang(pedagangId);
        hapus(pedagangId);
        Random r = new Random(pedagangId.getMostSignificantBits());   // sama untuk akun yang sama
        LocalDate hariIni = transaksi.hariIni();
        List<Transaksi> semua = new ArrayList<>();
        for (int d = 89; d >= 1; d--) {          // hari ini dibiarkan kosong untuk dicatat sendiri saat demo
            if (r.nextInt(100) < 8) continue;     // sekitar 8% hari libur / lupa mencatat
            LocalDate tgl = hariIni.minusDays(d);
            double tren = 1 + (89 - d) * 0.004;   // omzet naik pelan sekitar 35% dalam 3 bulan
            double qrisPorsi = 0.25 + (89 - d) * 0.003;
            for (Barang b : JUALAN) {
                int qty = (int) Math.round((b.min() + r.nextInt(b.max() - b.min() + 1)) * tren);
                int qtyQris = (int) Math.round(qty * Math.min(0.55, qrisPorsi));
                if (qty - qtyQris > 0) semua.add(jual(pedagangId, tgl, b, qty - qtyQris, Metode.TUNAI));
                if (qtyQris > 0) semua.add(jual(pedagangId, tgl, b, qtyQris, Metode.QRIS));
            }
            semua.add(beli(pedagangId, tgl, "tepung tapioka", 40_000 + r.nextInt(4) * 5_000));
            if (d % 3 == 0) semua.add(beli(pedagangId, tgl, "gas melon", 22_000));
            if (d % 4 == 0) semua.add(beli(pedagangId, tgl, "minyak goreng", 38_000));
            if (d % 7 == 0) semua.add(beli(pedagangId, tgl, "plastik", 15_000));
            if (d % 2 == 0) semua.add(beli(pedagangId, tgl, "gula dan teh", 18_000));
        }
        repo.saveAll(semua);
        return semua.size();
    }

    @Transactional
    public int hapus(UUID pedagangId) {
        return repo.deleteByPedagangIdAndCatatanAsli(pedagangId, PENANDA);
    }

    private static Transaksi jual(UUID pid, LocalDate tgl, Barang b, int qty, Metode m) {
        Transaksi t = dasar(pid, tgl, Jenis.MASUK, b.nama(), (long) qty * b.harga(), m);
        t.setJumlah(qty);
        t.setSatuan(b.satuan());
        t.setHargaSatuan(b.harga());
        return t;
    }

    private static Transaksi beli(UUID pid, LocalDate tgl, String nama, long total) {
        return dasar(pid, tgl, Jenis.KELUAR, nama, total, Metode.TUNAI);
    }

    private static Transaksi dasar(UUID pid, LocalDate tgl, Jenis j, String nama, long total, Metode m) {
        Transaksi t = new Transaksi();
        t.setPedagangId(pid);
        t.setTanggal(tgl);
        t.setJenis(j);
        t.setNamaItem(nama);
        t.setTotal(total);
        t.setMetode(m);
        t.setSumber(Sumber.MANUAL);
        t.setCatatanAsli(PENANDA);
        return t;
    }
}
