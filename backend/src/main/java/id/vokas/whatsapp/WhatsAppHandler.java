package id.vokas.whatsapp;

import com.fasterxml.jackson.databind.JsonNode;
import id.vokas.model.Jenis;
import id.vokas.model.Pedagang;
import id.vokas.model.Transaksi;
import id.vokas.repo.PedagangRepo;
import id.vokas.service.LaporanService;
import id.vokas.service.SkorKurService;
import id.vokas.service.TransaksiService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import java.text.NumberFormat;
import java.time.LocalDate;
import java.util.Locale;

/** Memproses pesan masuk di luar thread webhook, karena Meta meminta balasan HTTP 200 secepatnya. */
@Component
public class WhatsAppHandler {

    private static final Logger log = LoggerFactory.getLogger(WhatsAppHandler.class);

    private final PedagangRepo pedagangRepo;
    private final TransaksiService transaksi;
    private final LaporanService laporan;
    private final SkorKurService kur;
    private final WhatsAppClient wa;

    public WhatsAppHandler(PedagangRepo pedagangRepo, TransaksiService transaksi, LaporanService laporan,
                           SkorKurService kur, WhatsAppClient wa) {
        this.pedagangRepo = pedagangRepo;
        this.transaksi = transaksi;
        this.laporan = laporan;
        this.kur = kur;
        this.wa = wa;
    }

    @Async
    public void proses(JsonNode payload) {
        for (JsonNode entry : payload.path("entry")) {
            for (JsonNode change : entry.path("changes")) {
                JsonNode value = change.path("value");
                String namaProfil = value.at("/contacts/0/profile/name").asText("Pedagang");
                for (JsonNode msg : value.path("messages")) {
                    try {
                        prosesPesan(msg, namaProfil);
                    } catch (Exception e) {
                        log.error("Gagal memproses pesan WA {}", msg.path("id").asText(), e);
                        wa.kirimTeks(msg.path("from").asText(), "Maaf, catatan belum bisa diproses. Coba kirim lagi ya.");
                    }
                }
            }
        }
    }

    private void prosesPesan(JsonNode msg, String namaProfil) {
        String dari = msg.path("from").asText();
        Pedagang p = pedagangRepo.findByNoWa(dari).orElseGet(() -> daftarBaru(dari, namaProfil));
        String tipe = msg.path("type").asText();

        if ("audio".equals(tipe)) {
            WhatsAppClient.Media m = wa.unduh(msg.at("/audio/id").asText());
            wa.kirimTeks(dari, balasanCatat(transaksi.catatSuara(p.getId(), m.isi(), m.mimeType())));
            return;
        }
        if (!"text".equals(tipe)) {
            wa.kirimTeks(dari, "Kirim voice note atau ketik catatan, contoh: jual cilok 30 bungkus dua ribuan.");
            return;
        }
        String teks = msg.at("/text/body").asText("").trim();
        String kecil = teks.toLowerCase(Locale.ROOT);
        if (kecil.equals("laporan") || kecil.equals("rekap")) {
            LocalDate hari = transaksi.hariIni();
            LaporanService.Laporan l = laporan.buat(p.getId(), hari, hari);
            wa.kirimTeks(dari, "Rekap hari ini\nMasuk: " + rp(l.omzet()) + "\nKeluar: " + rp(l.pengeluaran())
                    + "\nUntung: " + rp(l.laba()));
        } else if (kecil.equals("rapor") || kecil.equals("kur")) {
            SkorKurService.Rapor r = kur.hitung(p.getId());
            wa.kirimTeks(dari, "Rapor Kesiapan KUR: " + r.skor() + "/100\n" + r.status()
                    + "\n" + r.hariTercatat() + " dari " + r.hariTotal() + " hari tercatat");
        } else if (kecil.equals("bantuan") || kecil.equals("halo") || kecil.equals("hai")) {
            wa.kirimTeks(dari, bantuan());
        } else {
            wa.kirimTeks(dari, balasanCatat(transaksi.catatTeks(p.getId(), teks, true)));
        }
    }

    private Pedagang daftarBaru(String noWa, String nama) {
        Pedagang p = new Pedagang();
        p.setNoWa(noWa);
        p.setNama(nama);
        Pedagang baru = pedagangRepo.save(p);
        wa.kirimTeks(noWa, "Selamat datang di VoKas, " + nama + "!\n" + bantuan());
        return baru;
    }

    static String balasanCatat(TransaksiService.HasilCatat h) {
        if (h.tersimpan().isEmpty()) {
            String sebab = h.baca().galat() != null ? h.baca().galat() : "Nominalnya belum terbaca.";
            return sebab + "\nContoh: jual cilok 30 bungkus dua ribuan, beli gas 22 ribu.";
        }
        StringBuilder sb = new StringBuilder("Tercatat:\n");
        for (Transaksi t : h.tersimpan()) {
            sb.append(t.getJenis() == Jenis.MASUK ? "+ " : "- ").append(t.getNamaItem());
            if (t.getJumlah() != null) sb.append(" ").append(t.getJumlah()).append(t.getSatuan() == null ? "" : " " + t.getSatuan());
            sb.append("  ").append(rp(t.getTotal())).append("\n");
        }
        if (!h.baca().lengkap()) sb.append("Sebagian kalimat belum terbaca, cek lagi ya.\n");
        return sb.append("Ketik *laporan* untuk rekap hari ini.").toString();
    }

    private static String bantuan() {
        return "Kirim voice note atau ketik catatan, contoh:\n- jual cilok 30 bungkus dua ribuan\n- beli tepung 50 ribu terus gas 22 ribu\n"
                + "Perintah: *laporan* (rekap hari ini), *rapor* (Rapor Kesiapan KUR).";
    }

    static String rp(long n) {
        return "Rp" + NumberFormat.getIntegerInstance(new Locale("id", "ID")).format(n);
    }
}
