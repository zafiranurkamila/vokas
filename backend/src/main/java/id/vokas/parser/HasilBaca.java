package id.vokas.parser;

import java.util.List;

/**
 * @param lengkap   false bila ada potongan kalimat yang tidak terbaca (tanpa nominal atau tanpa kata kerja)
 * @param sumber    "aturan" atau "gemini"
 * @param transkrip teks hasil dengar voice note (dari Gemini); untuk teks sama dengan masukan
 * @param galat     pesan bila pembaca gagal (misal kuota Gemini habis), selain itu null
 */
public record HasilBaca(List<ItemCatatan> items, boolean lengkap, String sumber, String transkrip, String galat) {
    public static HasilBaca kosong(String sumber, String transkrip) {
        return new HasilBaca(List.of(), false, sumber, transkrip, null);
    }

    public static HasilBaca gagal(String sumber, String galat) {
        return new HasilBaca(List.of(), false, sumber, "", galat);
    }
}
