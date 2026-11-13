import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet sama dengan prototipe: sage/olive yang bersih.
class Warna {
  static const olive = Color(0xFF7E9E52);
  static const oliveTua = Color(0xFF3F5A2A);
  static const khaki = Color(0xFFDFE5B5);
  static const matahari = Color(0xFFF2C230);
  static const qris = Color(0xFF2F6FA8);
  static const latar = Color(0xFFF1F5E8);
  static const kartu = Color(0xFFFFFFFF);
  static const tinta = Color(0xFF23301C);
  static const redup = Color(0xFF7C8873);
  static const garis = Color(0xFFE2E8D4);
  static const merah = Color(0xFFB4533A);
}

ThemeData temaVokas() {
  final teks = GoogleFonts.poppinsTextTheme().apply(bodyColor: Warna.tinta, displayColor: Warna.tinta);
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Warna.latar,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Warna.olive,
      primary: Warna.oliveTua,
      secondary: Warna.olive,
      surface: Warna.kartu,
    ),
    textTheme: teks,
    appBarTheme: AppBarTheme(
      backgroundColor: Warna.latar,
      foregroundColor: Warna.tinta,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Warna.tinta),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Warna.oliveTua,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Warna.oliveTua,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Warna.olive),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Warna.kartu,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Warna.garis)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Warna.garis)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Warna.olive, width: 1.6)),
    ),
  );
}

enum JenisPesan { berhasil, info, gagal }

/// Pemberitahuan singkat di bawah layar, mengambang dengan ikon sesuai jenisnya.
/// Jenis ditebak dari isi kalimat bila tidak disebut.
void tampilPesan(BuildContext context, String teks, {JenisPesan? jenis}) {
  final j = jenis ?? _tebakJenis(teks);
  final (ikon, warna) = switch (j) {
    JenisPesan.berhasil => (Icons.check_rounded, Warna.olive),
    JenisPesan.gagal => (Icons.priority_high_rounded, Warna.merah),
    JenisPesan.info => (Icons.info_outline_rounded, Warna.matahari),
  };
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
    backgroundColor: Warna.tinta,
    elevation: 6,
    duration: Duration(milliseconds: j == JenisPesan.gagal ? 4500 : 3200),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    content: Row(children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
        child: Icon(ikon, color: j == JenisPesan.info ? Warna.tinta : Colors.white, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(teks, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13.5, height: 1.4)),
      ),
    ]),
  ));
}

JenisPesan _tebakJenis(String t) {
  final s = t.toLowerCase();
  if (RegExp(r'gagal|salah|tidak valid|ditolak|belum bisa|belum terdaftar|tidak sama|terlalu mudah|kesalahan|tidak ada di server')
      .hasMatch(s)) {
    return JenisPesan.gagal;
  }
  if (RegExp(r'berhasil|sudah diisi|dihapus|diberikan|terisi|tersambung|dikirim|tercatat').hasMatch(s)) {
    return JenisPesan.berhasil;
  }
  return JenisPesan.info;
}

/// 60000 -> "Rp60.000"
String rp(num n) {
  final neg = n < 0;
  final s = n.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}Rp$b';
}

class Kartu extends StatelessWidget {
  const Kartu({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.warna = Warna.kartu});
  final Widget child;
  final EdgeInsets padding;
  final Color warna;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(20)),
        child: child,
      );
}
