import 'package:shared_preferences/shared_preferences.dart';

/// Status yang disimpan di perangkat: sudah lihat intro, pedagang yang masuk, dan pilihan sambung BRI.
class Sesi {
  static late SharedPreferences _p;

  static Future<void> muat() async => _p = await SharedPreferences.getInstance();

  static bool get sudahIntro => _p.getBool('sudahIntro') ?? false;
  static Future<void> selesaiIntro() => _p.setBool('sudahIntro', true);

  static String? get pedagangId => _p.getString('pedagangId');
  static String get nama => _p.getString('nama') ?? '';
  static String get namaUsaha => _p.getString('namaUsaha') ?? '';

  static Future<void> simpanPedagang(Map<String, dynamic> p) async {
    await _p.setString('pedagangId', p['id'] as String);
    await _p.setString('nama', (p['nama'] ?? '') as String);
    await _p.setString('namaUsaha', (p['namaUsaha'] ?? '') as String);
  }

  /// null = belum memilih, true = tersambung (simulasi), false = "nanti saja"
  static bool? get briTersambung => _p.getBool('briTersambung');
  static bool get sudahPilihBri => _p.containsKey('briTersambung');
  static Future<void> pilihBri(bool sambung) => _p.setBool('briTersambung', sambung);

  static Future<void> keluar() async {
    await _p.remove('pedagangId');
    await _p.remove('nama');
    await _p.remove('namaUsaha');
    await _p.remove('briTersambung');
  }
}
