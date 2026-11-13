package id.vokas.service;

import id.vokas.model.Jenis;
import id.vokas.model.Metode;
import id.vokas.model.Transaksi;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class SkorKurServiceTest {

    private static Transaksi trx(LocalDate tgl, Jenis j, long total, Metode m) {
        Transaksi t = new Transaksi();
        t.setTanggal(tgl);
        t.setJenis(j);
        t.setNamaItem("x");
        t.setTotal(total);
        t.setMetode(m);
        return t;
    }

    @Test
    void tanpaCatatanSkorHanyaDariRekening() {
        SkorKurService.Rapor r = SkorKurService.hitung(List.of(), true, LocalDate.of(2026, 11, 13));
        assertEquals(15, r.skor());
        assertFalse(r.siap());
    }

    @Test
    void pencatatanRapiSetiapHariSiap() {
        LocalDate akhir = LocalDate.of(2026, 11, 13);
        List<Transaksi> list = new ArrayList<>();
        for (int d = 89; d >= 0; d--) {
            LocalDate tgl = akhir.minusDays(d);
            long omzet = 300_000 + (89 - d) * 1_000L;      // naik pelan
            list.add(trx(tgl, Jenis.MASUK, omzet / 2, Metode.QRIS));
            list.add(trx(tgl, Jenis.MASUK, omzet / 2, Metode.TUNAI));
            list.add(trx(tgl, Jenis.KELUAR, omzet * 6 / 10, Metode.TUNAI));
        }
        SkorKurService.Rapor r = SkorKurService.hitung(list, true, akhir);
        assertEquals(90, r.hariTercatat());
        assertEquals(90, r.hariTotal());
        // konsistensi 30 + QRIS 20 + rekening 15 + margin 40%->20 + tren naik -> 15
        assertEquals(100, r.skor());
        assertTrue(r.siap());
    }

    @Test
    void hariBolongMenurunkanKonsistensi() {
        LocalDate akhir = LocalDate.of(2026, 11, 13);
        List<Transaksi> list = new ArrayList<>();
        for (int d = 59; d >= 0; d -= 2) list.add(trx(akhir.minusDays(d), Jenis.MASUK, 100_000, Metode.TUNAI));
        SkorKurService.Rapor r = SkorKurService.hitung(list, false, akhir);
        SkorKurService.Kriteria k = r.kriteria().get(0);
        assertEquals(30, r.hariTercatat());
        assertEquals(60, r.hariTotal());
        assertEquals(15, k.poin());
    }
}
