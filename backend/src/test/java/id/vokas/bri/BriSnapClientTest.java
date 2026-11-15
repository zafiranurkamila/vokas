package id.vokas.bri;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class BriSnapClientTest {

    @Test
    void hashBodySesuaiContohDokumentasiBri() throws Exception {
        // contoh dari halaman "APIDOCS Oauth SNAP BI" developers.bri.co.id
        assertEquals("93a23971a914e5eacbf0a8d25154cda309c3c1c72fbb9914d47c60f3cb681588",
                BriSnapClient.hashBody("{\"hello\":\"world\"}"));
    }

    @Test
    void formatTimestampHeaderPakaiMilidetikDanZona() {
        assertTrue(BriSnapClient.sekarang().matches("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}\\+07:00"));
    }

    @Test
    void signatureHmacStabil() throws Exception {
        String a = BriSnapClient.tandaTanganHmac("POST", "/snap/v1.1/bank-statement", "tok", "{}", "2026-01-01T00:00:00.000+07:00", "rahasia");
        String b = BriSnapClient.tandaTanganHmac("POST", "/snap/v1.1/bank-statement", "tok", "{}", "2026-01-01T00:00:00.000+07:00", "rahasia");
        assertEquals(a, b);
        assertEquals(88, a.length()); // base64 dari 64 byte HMAC-SHA512
    }
}
