package id.vokas.service;

import id.vokas.model.Jenis;
import id.vokas.model.Metode;
import id.vokas.model.Sumber;
import id.vokas.model.Transaksi;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class LaporanService {

    private final TransaksiService transaksi;

    public LaporanService(TransaksiService transaksi) {
        this.transaksi = transaksi;
    }

    public record Harian(LocalDate tanggal, long masuk, long keluar, long qris) {}
    public record Terlaris(String nama, long jumlah, long total) {}
    public record Laporan(LocalDate dari, LocalDate sampai, long omzet, long pengeluaran, long laba,
                          long omzetQris, int jumlahTransaksi, List<Harian> harian, List<Terlaris> terlaris) {}

    public Laporan buat(UUID pedagangId, LocalDate dari, LocalDate sampai) {
        transaksi.pedagang(pedagangId);
        List<Transaksi> list = transaksi.daftar(pedagangId, dari, sampai);
        Map<LocalDate, List<Transaksi>> perHari = list.stream()
                .collect(Collectors.groupingBy(Transaksi::getTanggal, TreeMap::new, Collectors.toList()));
        List<Harian> harian = perHari.entrySet().stream().map(e -> new Harian(e.getKey(),
                jumlah(e.getValue(), Jenis.MASUK, null), jumlah(e.getValue(), Jenis.KELUAR, null),
                jumlah(e.getValue(), Jenis.MASUK, Metode.QRIS))).toList();

        Map<String, long[]> agg = new HashMap<>();
        for (Transaksi t : list) {
            // mutasi QRIS/transfer tidak punya nama barang, jadi tidak ikut daftar terlaris
            if (t.getJenis() != Jenis.MASUK || t.getSumber() == Sumber.QRIS || t.getSumber() == Sumber.MUTASI) continue;
            long[] a = agg.computeIfAbsent(t.getNamaItem(), k -> new long[2]);
            a[0] += t.getJumlah() == null ? 0 : t.getJumlah();
            a[1] += t.getTotal();
        }
        List<Terlaris> terlaris = agg.entrySet().stream()
                .map(e -> new Terlaris(e.getKey(), e.getValue()[0], e.getValue()[1]))
                .sorted(Comparator.comparingLong(Terlaris::total).reversed())
                .limit(5).toList();

        long omzet = jumlah(list, Jenis.MASUK, null), keluar = jumlah(list, Jenis.KELUAR, null);
        return new Laporan(dari, sampai, omzet, keluar, omzet - keluar, jumlah(list, Jenis.MASUK, Metode.QRIS),
                list.size(), harian, terlaris);
    }

    static long jumlah(List<Transaksi> list, Jenis jenis, Metode metode) {
        return list.stream()
                .filter(t -> t.getJenis() == jenis && (metode == null || t.getMetode() == metode))
                .mapToLong(Transaksi::getTotal).sum();
    }
}
