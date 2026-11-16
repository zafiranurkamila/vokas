package id.vokas.auth;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;

/** Hash PIN dengan PBKDF2-HMAC-SHA256 + salt acak. Format: iterasi$salt$hash (base64). */
public final class PinHasher {

    private static final SecureRandom ACAK = new SecureRandom();
    private static final int ITERASI = 120_000;

    private PinHasher() {}

    public static String hash(String pin) {
        byte[] salt = new byte[16];
        ACAK.nextBytes(salt);
        return ITERASI + "$" + Base64.getEncoder().encodeToString(salt) + "$"
                + Base64.getEncoder().encodeToString(turunan(pin, salt, ITERASI));
    }

    public static boolean cocok(String pin, String tersimpan) {
        if (pin == null || tersimpan == null) return false;
        String[] b = tersimpan.split("\\$");
        if (b.length != 3) return false;
        byte[] salt = Base64.getDecoder().decode(b[1]);
        byte[] harap = Base64.getDecoder().decode(b[2]);
        return MessageDigest.isEqual(harap, turunan(pin, salt, Integer.parseInt(b[0])));
    }

    private static byte[] turunan(String pin, byte[] salt, int iterasi) {
        try {
            PBEKeySpec spec = new PBEKeySpec(pin.toCharArray(), salt, iterasi, 256);
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
