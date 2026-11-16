package id.vokas.service;

import id.vokas.model.*;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class EksporBerkasTest {

    @Test
    void pdfDanExcelTerbentuk() throws Exception {
        UUID id = UUID.randomUUID();
        LocalDate hari = LocalDate.of(2026, 11, 16);
        Pedagang p = new Pedagang();
        p.setNama("Juri");
        p.setNamaUsaha("Cilok & Cireng Demo");
        Transaksi t = new Transaksi();
        t.setTanggal(hari);
        t.setJenis(Jenis.MASUK);
        t.setNamaItem("cilok");
        t.setJumlah(30);
        t.setSatuan("bungkus");
        t.setHargaSatuan(2000L);
        t.setTotal(60_000);
        t.setMetode(Metode.QRIS);
        t.setSumber(Sumber.SUARA);

        TransaksiService ts = mock(TransaksiService.class);
        LaporanService ls = mock(LaporanService.class);
        SkorKurService ks = mock(SkorKurService.class);
        when(ts.pedagang(id)).thenReturn(p);
        when(ts.daftar(any(), any(), any())).thenReturn(List.of(t));
        when(ls.buat(any(), any(), any())).thenReturn(new LaporanService.Laporan(hari, hari, 60_000, 0, 60_000, 60_000, 1,
                List.of(new LaporanService.Harian(hari, 60_000, 0, 60_000)), List.of(new LaporanService.Terlaris("cilok", 30, 60_000))));
        when(ks.hitung(id)).thenReturn(new SkorKurService.Rapor(72, true, "Siap", 60, 90, List.of()));

        EksporLaporanService e = new EksporLaporanService(ts, ls, ks);
        byte[] pdf = e.pdf(id, hari, hari);
        byte[] xlsx = e.xlsx(id, hari, hari);
        assertEquals("%PDF", new String(pdf, 0, 4));
        assertEquals('P', (char) xlsx[0]);   // zip "PK"
        assertEquals('K', (char) xlsx[1]);
        assertEquals("Laporan_VoKas_Cilok_Cireng_Demo_2026-11-16_sd_2026-11-16.pdf", EksporLaporanService.namaBerkas(p, hari, hari, "pdf"));
        java.nio.file.Files.write(java.nio.file.Path.of("target", "contoh_laporan.pdf"), pdf);
        java.nio.file.Files.write(java.nio.file.Path.of("target", "contoh_laporan.xlsx"), xlsx);
    }
}
