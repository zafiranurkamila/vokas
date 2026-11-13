package id.vokas.parser;

/** Mengubah catatan pedagang (teks atau suara) menjadi daftar transaksi. Penyedia bisa diganti. */
public interface PembacaCatatan {
    HasilBaca bacaTeks(String teks);

    /** Default: tidak bisa membaca audio. */
    default HasilBaca bacaSuara(byte[] audio, String mimeType) {
        return HasilBaca.gagal(nama(), "Pembaca ini tidak mendukung audio");
    }

    String nama();
}
