package id.vokas.service;

import id.vokas.repo.PedagangRepo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Setiap server menyala, data contoh akun juri diperbarui supaya tanggalnya selalu 90 hari terakhir.
 * Hanya baris bertanda "[contoh]" yang diganti; catatan yang dibuat juri sendiri tetap ada.
 */
@Component
public class AkunJuriRunner implements ApplicationRunner {

    public static final String NO_WA_JURI = "6281200002026";
    /** PIN bawaan akun demo, dicantumkan di proposal untuk juri. */
    public static final String PIN_DEMO = "202611";
    private static final Logger log = LoggerFactory.getLogger(AkunJuriRunner.class);

    private final PedagangRepo pedagang;
    private final DataContohService dataContoh;

    public AkunJuriRunner(PedagangRepo pedagang, DataContohService dataContoh) {
        this.pedagang = pedagang;
        this.dataContoh = dataContoh;
    }

    @Override
    public void run(ApplicationArguments args) {
        try {
            // akun demo (tim dan juri) memakai PIN bawaan bila belum punya PIN
            for (String wa : List.of(NO_WA_JURI, "6281200000001", "6281200000002", "6281200000003", "6281200000004")) {
                pedagang.findByNoWa(wa).filter(p -> p.getPinHash() == null).ifPresent(p -> {
                    p.setPinHash(id.vokas.auth.PinHasher.hash(PIN_DEMO));
                    pedagang.save(p);
                });
            }
            pedagang.findByNoWa(NO_WA_JURI).ifPresent(p -> {
                int n = dataContoh.isi(p.getId());
                log.info("Data contoh akun juri diperbarui: {} baris", n);
            });
        } catch (Exception e) {
            log.warn("Gagal mengisi data contoh akun juri: {}", e.getMessage());
        }
    }
}
