package id.vokas.parser;

import id.vokas.model.Jenis;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.regex.Pattern;

/**
 * Pembaca berbasis aturan untuk kalimat pendek bahasa Indonesia sehari-hari, misalnya
 * "jual cilok tiga puluh bungkus dua ribuan" atau "beli tepung 50rb terus gas melon 22 ribu".
 * Gratis dan cepat; kalimat yang tidak terbaca utuh diteruskan ke Gemini oleh PembacaGabungan.
 */
@Component
public class PembacaAturan implements PembacaCatatan {

    private static final Set<String> JUAL = Set.of("jual", "laku", "terjual", "dapet", "dapat", "kejual", "nerima", "terima");
    private static final Set<String> BELI = Set.of("beli", "belanja", "bayar", "ongkos", "biaya", "keluar");
    private static final Map<String, Integer> ANGKA = Map.ofEntries(
            Map.entry("nol", 0), Map.entry("satu", 1), Map.entry("dua", 2), Map.entry("tiga", 3),
            Map.entry("empat", 4), Map.entry("lima", 5), Map.entry("enam", 6), Map.entry("tujuh", 7),
            Map.entry("delapan", 8), Map.entry("sembilan", 9), Map.entry("sepuluh", 10), Map.entry("sebelas", 11));
    private static final Set<String> SATUAN = Set.of("bungkus", "porsi", "gelas", "cup", "pcs", "biji", "buah", "tusuk",
            "botol", "plastik", "kg", "kilo", "liter", "bks", "potong", "pack", "box");
    private static final Set<String> STOP = Set.of("hari", "ini", "tadi", "dari", "jualan", "yang", "buat", "untuk",
            "per", "harga", "satuan", "rupiah", "aku", "saya", "kita", "total", "semua", "sebanyak", "isi",
            "pagi", "siang", "sore", "malam", "sekitar", "kurang", "lebih", "an");
    private static final Pattern PEMISAH = Pattern.compile("\\s*[,;]\\s*|\\s+(?:dan|terus|trus|lalu|sama)\\s+");
    private static final Pattern ANGKA_SINGKAT = Pattern.compile("(\\d+)(rb|k|jt|ribu|juta)\\b");

    @Override
    public String nama() { return "aturan"; }

    @Override
    public HasilBaca bacaTeks(String teks) {
        if (teks == null || teks.isBlank()) return HasilBaca.kosong(nama(), "");
        String norm = normalisasi(teks);
        List<ItemCatatan> items = new ArrayList<>();
        boolean lengkap = true;
        Jenis jenisSebelum = null;
        for (String potong : PEMISAH.split(norm)) {
            if (potong.isBlank()) continue;
            Potongan p = urai(potong.trim().split("\\s+"));
            Jenis jenis = p.jenis != null ? p.jenis : jenisSebelum;   // "terus gas melon 22 ribu" mewarisi "beli"
            if (jenis == null || p.nominal == null) { lengkap = false; continue; }
            jenisSebelum = jenis;
            boolean perSatuan = p.ribuan || p.adaKataPer
                    || (jenis == Jenis.MASUK && p.qty != null && p.qty > 1 && p.nominal <= 10_000);
            long total = perSatuan && p.qty != null ? p.nominal * p.qty : p.nominal;
            Long harga = p.qty != null && p.qty > 0 ? (perSatuan ? p.nominal : Math.round((double) p.nominal / p.qty)) : null;
            String namaItem = p.nama.isEmpty() ? (jenis == Jenis.MASUK ? "Penjualan" : "Pengeluaran") : p.nama;
            items.add(new ItemCatatan(jenis, namaItem, p.qty, p.satuan, harga, total));
        }
        return new HasilBaca(items, lengkap && !items.isEmpty(), nama(), teks.trim(), null);
    }

    static String normalisasi(String teks) {
        String s = teks.toLowerCase(Locale.ROOT)
                .replaceAll("(?<=\\d)[.](?=\\d{3}\\b)", "")   // 38.000 -> 38000
                .replaceAll("(?<=\\d)[.](?=\\d{3}\\b)", "")   // 1.500.000 butuh dua kali
                .replaceAll("\\brp\\.?\\s*", "")
                .replaceAll("[^a-z0-9,;\\s]", " ");
        s = ANGKA_SINGKAT.matcher(s).replaceAll("$1 $2");      // 50rb -> 50 rb
        return s.replaceAll("\\s+", " ").trim();
    }

    private static final class Potongan {
        Jenis jenis;
        Long nominal;
        Integer qty;
        String satuan;
        boolean ribuan;
        boolean adaKataPer;
        String nama = "";
    }

    /** Mengurai satu potongan kalimat: kata kerja, angka (kuantitas bila diikuti satuan), dan nama barang. */
    private static Potongan urai(String[] kata) {
        Potongan p = new Potongan();
        List<String> namaKata = new ArrayList<>();
        int i = 0;
        while (i < kata.length) {
            String k = kata[i];
            if (JUAL.contains(k)) { if (p.jenis == null) p.jenis = Jenis.MASUK; i++; continue; }
            if (BELI.contains(k)) { if (p.jenis == null) p.jenis = Jenis.KELUAR; i++; continue; }
            if (k.equals("per") || k.equals("harga") || k.equals("satuan")) p.adaKataPer = true;
            if (awalAngka(k)) {
                Angka a = bacaAngka(kata, i);
                i = a.akhir;
                if (i < kata.length && SATUAN.contains(kata[i]) && p.qty == null && a.nilai < 10_000) {
                    p.qty = (int) a.nilai;
                    p.satuan = kata[i];
                    i++;
                } else {
                    p.nominal = a.nilai;
                    p.ribuan |= a.ribuan;
                }
                continue;
            }
            if (!SATUAN.contains(k) && !STOP.contains(k)) namaKata.add(k);
            i++;
        }
        p.nama = String.join(" ", namaKata);
        return p;
    }

    private static boolean angkaDigit(String k) {
        return !k.isEmpty() && k.chars().allMatch(Character::isDigit);
    }

    private static boolean awalAngka(String k) {
        return angkaDigit(k) || ANGKA.containsKey(k) || k.equals("seratus") || k.equals("seribu") || k.equals("sejuta");
    }

    private record Angka(long nilai, int akhir, boolean ribuan) {}

    /** Membaca satu bilangan mulai dari indeks i, contoh "dua puluh dua ribu", "38000", atau "50 rb". */
    private static Angka bacaAngka(String[] kata, int i) {
        long total = 0, grup = 0, satuan = 0;
        boolean ribuan = false;
        while (i < kata.length) {
            String k = kata[i];
            if (angkaDigit(k)) {
                if (total + grup + satuan > 0) break;              // angka baru, bukan lanjutan
                satuan = Long.parseLong(k.length() > 12 ? k.substring(0, 12) : k);
            } else if (ANGKA.containsKey(k)) {
                satuan += ANGKA.get(k);
            } else if (k.equals("belas")) {
                satuan += 10;
            } else if (k.equals("puluh")) {
                satuan = Math.max(satuan, 1) * 10;
            } else if (k.equals("ratus")) {
                grup += Math.max(satuan, 1) * 100;
                satuan = 0;
            } else if (k.equals("seratus")) {
                grup += 100;
            } else if (k.equals("ribu") || k.equals("ribuan") || k.equals("rb") || k.equals("k")) {
                total += Math.max(grup + satuan, 1) * 1_000;
                grup = 0;
                satuan = 0;
                if (k.equals("ribuan")) ribuan = true;
            } else if (k.equals("seribu")) {
                total += 1_000;
            } else if (k.equals("juta") || k.equals("jt")) {
                total += Math.max(grup + satuan, 1) * 1_000_000;
                grup = 0;
                satuan = 0;
            } else if (k.equals("sejuta")) {
                total += 1_000_000;
            } else {
                break;
            }
            i++;
        }
        return new Angka(total + grup + satuan, i, ribuan);
    }
}
