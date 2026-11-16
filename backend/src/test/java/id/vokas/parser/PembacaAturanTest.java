package id.vokas.parser;

import id.vokas.model.Jenis;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class PembacaAturanTest {

    private final PembacaAturan p = new PembacaAturan();

    private List<ItemCatatan> baca(String s) {
        HasilBaca h = p.bacaTeks(s);
        assertTrue(h.lengkap(), "harus terbaca utuh: " + s);
        return h.items();
    }

    @Test
    void hargaPerSatuanRibuan() {
        List<ItemCatatan> it = baca("jual cilok tiga puluh bungkus dua ribuan");
        assertEquals(1, it.size());
        ItemCatatan c = it.get(0);
        assertEquals(Jenis.MASUK, c.jenis());
        assertEquals("cilok", c.nama());
        assertEquals(30, c.jumlah());
        assertEquals("bungkus", c.satuan());
        assertEquals(2_000L, c.hargaSatuan());
        assertEquals(60_000, c.total());
    }

    @Test
    void duaPengeluaranKataKerjaDiwarisi() {
        List<ItemCatatan> it = baca("beli tepung lima puluh ribu terus gas melon dua puluh dua ribu");
        assertEquals(2, it.size());
        assertEquals(new ItemCatatan(Jenis.KELUAR, "tepung", null, null, null, 50_000), it.get(0));
        assertEquals(new ItemCatatan(Jenis.KELUAR, "gas melon", null, null, null, 22_000), it.get(1));
    }

    @Test
    void belanjaLiterAngkaTotal() {
        List<ItemCatatan> it = baca("beli minyak 2 liter 38000");
        assertEquals(1, it.size());
        assertEquals("minyak", it.get(0).nama());
        assertEquals(2, it.get(0).jumlah());
        assertEquals(38_000, it.get(0).total());
        assertEquals(19_000L, it.get(0).hargaSatuan());
    }

    @Test
    void singkatanDanTitikRibuan() {
        assertEquals(50_000, baca("beli tepung 50rb").get(0).total());
        assertEquals(1_500_000, baca("bayar sewa lapak Rp1.500.000").get(0).total());
        assertEquals(2_500, baca("jual es teh dua ribu lima ratus").get(0).total());
        assertEquals(150_000, baca("dapet seratus lima puluh ribu").get(0).total());
        assertEquals(12_000, baca("jual gorengan dua belas ribu").get(0).total());
    }

    @Test
    void penjualanTanpaNamaBarang() {
        ItemCatatan c = baca("hari ini dapet dua ratus ribu dari jualan").get(0);
        assertEquals("Penjualan", c.nama());
        assertEquals(200_000, c.total());
    }

    @Test
    void penjualanMurahDenganJumlahDianggapPerSatuan() {
        ItemCatatan c = baca("laku cireng 25 biji 1500").get(0);
        assertEquals(37_500, c.total());
    }

    @Test
    void campuranJualDanBeli() {
        List<ItemCatatan> it = baca("jual cilok 40 bungkus dua ribuan, beli plastik 15 ribu");
        assertEquals(2, it.size());
        assertEquals(Jenis.MASUK, it.get(0).jenis());
        assertEquals(80_000, it.get(0).total());
        assertEquals(Jenis.KELUAR, it.get(1).jenis());
        assertEquals(15_000, it.get(1).total());
    }

    @Test
    void kalimatTanpaNominalTidakLengkap() {
        HasilBaca h = p.bacaTeks("tadi rame banget pembelinya");
        assertFalse(h.lengkap());
        assertTrue(h.items().isEmpty());
    }

    @Test
    void sebagianTerbaca() {
        HasilBaca h = p.bacaTeks("jual cilok 50 ribu, terus lupa yang satunya");
        assertFalse(h.lengkap());
        assertEquals(1, h.items().size());
    }

    @org.junit.jupiter.api.Test
    void jumlahSebelumNamaDanKataHarga() {
        var h = new PembacaAturan().bacaTeks("jual ayam 50 harga 10rb, kentang 10 harga 30rb");
        org.junit.jupiter.api.Assertions.assertTrue(h.lengkap());
        org.junit.jupiter.api.Assertions.assertEquals(500_000, h.items().get(0).total());
        org.junit.jupiter.api.Assertions.assertEquals(300_000, h.items().get(1).total());
    }

    @org.junit.jupiter.api.Test
    void kalimatAmbiguDiserahkanKeAi() {
        var h = new PembacaAturan().bacaTeks("terjual 50 ayam dengan harga 10k terus ada tambahan 10 kentang 30k");
        org.junit.jupiter.api.Assertions.assertFalse(h.lengkap(), "10 kentang 30k ambigu, harus dibaca AI");
        org.junit.jupiter.api.Assertions.assertEquals(500_000, h.items().get(0).total());
    }
}
