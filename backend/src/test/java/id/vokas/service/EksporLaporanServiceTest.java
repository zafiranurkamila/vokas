package id.vokas.service;

import id.vokas.auth.PinHasher;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class EksporLaporanServiceTest {

    @Test
    void formatRupiah() {
        assertEquals("Rp1.250.000", EksporLaporanService.rp(1_250_000));
    }

    @Test
    void pinDiHashDanBisaDicek() {
        String h = PinHasher.hash("202611");
        assertTrue(PinHasher.cocok("202611", h));
        assertFalse(PinHasher.cocok("202612", h));
        assertNotEquals(h, PinHasher.hash("202611"), "salt acak membuat hash berbeda");
    }
}
