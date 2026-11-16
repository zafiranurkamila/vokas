package id.vokas.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class KasbonServiceTest {

    @Test
    void bacaKalimatKasbonSederhana() {
        KasbonService.Draf d = KasbonService.bacaAturan("bu ani ngutang 20 ribu buat beras");
        assertNull(d.galat());
        assertEquals("Bu Ani", d.namaPelanggan());
        assertEquals(20_000L, d.nominal());
        assertEquals("beras", d.keterangan());
    }

    @Test
    void keteranganSebelumNominalDanAngkaKecilBukanUang() {
        KasbonService.Draf d = KasbonService.bacaAturan("Pak Budi ngebon rokok 2 bungkus 50rb");
        assertNull(d.galat());
        assertEquals("Pak Budi", d.namaPelanggan());
        assertEquals(50_000L, d.nominal());
        assertEquals("rokok 2 bungkus", d.keterangan());
    }

    @Test
    void nominalDenganTitikRibuan() {
        assertEquals(1_500_000L, KasbonService.bacaAturan("mas joko kasbon 1.500.000").nominal());
        assertEquals(25_000L, KasbonService.bacaAturan("Mbak Sri utang 25.000 gula").nominal());
    }

    @Test
    void kalimatTanpaKataUtangDiserahkanKeAi() {
        assertNotNull(KasbonService.bacaAturan("jual cilok 30 bungkus").galat());
        assertNotNull(KasbonService.bacaAturan("ngutang 20 ribu").galat());   // tanpa nama
    }

    @Test
    void celenganDibulatkanKeRatusan() {
        assertEquals(12_300L, CelenganService.bulatkan(12_345));
        assertEquals(0L, CelenganService.bulatkan(-5));
    }
}
