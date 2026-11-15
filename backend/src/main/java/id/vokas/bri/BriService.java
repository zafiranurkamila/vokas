package id.vokas.bri;

import com.fasterxml.jackson.databind.JsonNode;
import id.vokas.model.Jenis;
import id.vokas.model.Metode;
import id.vokas.service.TransaksiService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * Sinkronisasi mutasi rekening dari BRIAPI (sandbox) ke catatan VoKas.
 * Uang masuk berketerangan QRIS dicatat sebagai penjualan QRIS; transfer ditandai "perlu cek".
 * Uang keluar dicatat sebagai transfer keluar yang juga perlu dicek.
 */
@Service
public class BriService {

    private final BriSnapClient bri;
    private final TransaksiService transaksi;

    public BriService(BriSnapClient bri, TransaksiService transaksi) {
        this.bri = bri;
        this.transaksi = transaksi;
    }

    public record HasilSinkron(int ditemukan, TransaksiService.HasilImpor impor, String sumber) {}

    public HasilSinkron sinkron(UUID pedagangId, String accountNo, int hari) {
        if (!bri.aktif()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "BRIAPI belum dikonfigurasi di server (isi BRI_CLIENT_ID, BRI_CLIENT_SECRET, BRI_PRIVATE_KEY, BRI_PARTNER_ID, BRI_CHANNEL_ID)");
        }
        if (accountNo == null || !accountNo.matches("\\d{10,16}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Nomor rekening harus 10-16 digit angka");
        }
        OffsetDateTime sampai = OffsetDateTime.now(ZoneOffset.ofHours(7));
        OffsetDateTime dari = sampai.minusDays(Math.max(1, Math.min(hari, 31)));
        JsonNode r;
        try {
            r = bri.mutasi(accountNo, dari, sampai);
        } catch (RestClientResponseException e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "BRI menolak permintaan (" + e.getStatusCode().value() + "): " + ringkas(e.getResponseBodyAsString()));
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "Gagal menghubungi BRI: " + e.getMessage());
        }
        String kode = r == null ? "" : r.path("responseCode").asText("");
        if (!kode.startsWith("200")) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "BRI: " + (r == null ? "tanpa jawaban" : r.path("responseMessage").asText("gagal")) + " (" + kode + ")");
        }

        List<TransaksiService.Mutasi> mutasi = new ArrayList<>();
        for (JsonNode d : r.path("detailData")) {
            String id = d.path("transactionId").asText("").replace(" ", "");
            String remark = d.path("remark").asText("");
            long nominal = new BigDecimal(d.at("/amount/value").asText("0")).longValue();
            if (nominal <= 0) continue;
            boolean masuk = d.path("type").asText("").toUpperCase(Locale.ROOT).startsWith("CREDIT");
            boolean qris = remark.toUpperCase(Locale.ROOT).contains("QRIS");
            LocalDate tgl;
            try {
                tgl = OffsetDateTime.parse(d.path("transactionDate").asText()).atZoneSameInstant(ZoneOffset.ofHours(7)).toLocalDate();
            } catch (Exception e) {
                tgl = null;
            }
            String ref = "BRI-" + (id.isEmpty() ? d.path("transactionDate").asText() + "-" + nominal + "-" + remark.hashCode() : id);
            mutasi.add(new TransaksiService.Mutasi(ref.length() > 80 ? ref.substring(0, 80) : ref, tgl, nominal,
                    remark.isBlank() ? null : remark,
                    masuk ? Jenis.MASUK : Jenis.KELUAR,
                    masuk && qris ? Metode.QRIS : Metode.TRANSFER));
        }
        return new HasilSinkron(mutasi.size(), transaksi.imporMutasi(pedagangId, mutasi), "BRIAPI sandbox");
    }

    private static String ringkas(String s) {
        return s == null ? "" : (s.length() > 200 ? s.substring(0, 200) : s);
    }
}
