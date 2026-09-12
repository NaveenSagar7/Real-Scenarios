package com.myapp.dailyjournal.util;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.regex.Pattern;

/**
 * PAN (Indian Permanent Account Number) is sensitive PII, so the
 * plaintext value is never persisted: a keyed hash (HMAC-SHA256, keyed
 * with app.security.pan-secret) is stored for returning-user lookup,
 * and only a masked form is kept for display.
 */
public final class PanUtil {

    /** Number of trailing PAN characters left visible in the masked form. */
    private static final int MASKED_SUFFIX_LENGTH = 5;

    /** Matches a well-formed PAN, e.g. ABCDE1234F. */
    private static final Pattern PAN_PATTERN =
            Pattern.compile("^[A-Z]{5}[0-9]{4}[A-Z]$");

    /** Algorithm used to key-hash a normalized PAN. */
    private static final String HMAC_ALGO = "HmacSHA256";

    private PanUtil() {
    }

    /**
     * Checks whether the given value is a well-formed PAN.
     *
     * @param pan the value to check
     * @return {@code true} if {@code pan} matches the PAN format
     */
    public static boolean isValid(final String pan) {
        return pan != null
                && PAN_PATTERN.matcher(pan.trim().toUpperCase()).matches();
    }

    /**
     * Normalizes a PAN to its canonical (trimmed, upper-case) form.
     *
     * @param pan the PAN to normalize
     * @return the normalized PAN
     */
    public static String normalize(final String pan) {
        return pan.trim().toUpperCase();
    }

    /**
     * Computes the keyed hash of a PAN used for returning-user lookup.
     *
     * @param pan the PAN to hash
     * @param secret the HMAC key
     * @return the hex-encoded HMAC of the normalized PAN
     */
    public static String hash(final String pan, final String secret) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGO);
            mac.init(new SecretKeySpec(
                    secret.getBytes(StandardCharsets.UTF_8), HMAC_ALGO));
            byte[] digest = mac.doFinal(
                    normalize(pan).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new IllegalStateException("Unable to hash PAN", e);
        }
    }

    /**
     * Masks a PAN for display, keeping only the trailing characters.
     *
     * @param pan the PAN to mask
     * @return the masked PAN, e.g. XXXXX1234F
     */
    public static String mask(final String pan) {
        String normalized = normalize(pan);
        return "XXXXX" + normalized.substring(MASKED_SUFFIX_LENGTH);
    }
}
