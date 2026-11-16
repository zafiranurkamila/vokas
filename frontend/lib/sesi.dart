import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Status yang disimpan di perangkat. Versi demo: PIN disimpan sebagai hash di perangkat.
/// Versi resmi: PIN di-hash (bcrypt/argon2) di server, sesi memakai token Supabase Auth.
class Sesi {
  static late SharedPreferences _p;

  static Future<void> muat() async => _p = await SharedPreferences.getInstance();

  static bool get sudahIntro => _p.getBool('sudahIntro') ?? false;
  static Future<void> selesaiIntro() => _p.setBool('sudahIntro', true);

  static bool get sudahIzin => _p.getBool('sudahIzin') ?? false;
  static Future<void> selesaiIzin() => _p.setBool('sudahIzin', true);

  static String get lokasiUsaha => _p.getString('lokasi_${pedagangId ?? '-'}') ?? '';
  static Future<void> simpanLokasi(String s) => _p.setString('lokasi_${pedagangId ?? '-'}', s);

  static bool get sudahTur => _p.getBool('sudahTur') ?? false;
  static Future<void> selesaiTur() => _p.setBool('sudahTur', true);

  /// Perkenalan fitur baru (kasbon, celengan, dst.) untuk pengguna lama yang sudah pernah ikut tur awal.
  static bool get sudahTurFiturBaru => _p.getBool('sudahTurFitur2') ?? false;
  static Future<void> selesaiTurFiturBaru() => _p.setBool('sudahTurFitur2', true);

  static String? get pedagangId => _p.getString('pedagangId');
  static String get nama => _p.getString('nama') ?? '';
  static String get namaUsaha => _p.getString('namaUsaha') ?? '';
  static String get noWa => _p.getString('noWa') ?? '';

  static Future<void> simpanPedagang(Map<String, dynamic> p) async {
    await _p.setString('pedagangId', p['id'] as String);
    await _p.setString('nama', (p['nama'] ?? '') as String);
    await _p.setString('namaUsaha', (p['namaUsaha'] ?? '') as String);
    await _p.setString('noWa', (p['noWa'] ?? '') as String);
  }

  // ---------- target omzet harian ----------
  static int get targetHarian => _p.getInt('target_${pedagangId ?? '-'}') ?? 0;
  static Future<void> simpanTarget(int nilai) => _p.setInt('target_${pedagangId ?? '-'}', nilai);

  // ---------- PIN ----------
  static String _hash(String wa, String pin) => sha256.convert(utf8.encode('vokas:$wa:$pin')).toString();
  static bool punyaPin(String wa) => _p.containsKey('pin_$wa');
  static Future<void> simpanPin(String wa, String pin) => _p.setString('pin_$wa', _hash(wa, pin));
  static bool cekPin(String wa, String pin) => _p.getString('pin_$wa') == _hash(wa, pin);

  // ---------- rekening BRI (simulasi) ----------
  /// null = belum memilih, true = tersambung, false = "nanti saja"
  static bool? get briTersambung => _p.getBool('briTersambung');
  static bool get sudahPilihBri => _p.containsKey('briTersambung');
  static String get briRekening => _p.getString('briRekening') ?? '';
  static String get briNama => _p.getString('briNama') ?? '';

  static Future<void> pilihBri(bool sambung) => _p.setBool('briTersambung', sambung);

  /// Hanya 4 digit terakhir yang disimpan.
  static Future<void> simpanRekening(String norek, String namaPemilik) async {
    await _p.setString('briRekening', norek.substring(norek.length - 4));
    await _p.setString('briNama', namaPemilik);
    await _p.setBool('briTersambung', true);
  }

  static Future<void> putuskanBri() async {
    await _p.remove('briRekening');
    await _p.remove('briNama');
    await _p.setBool('briTersambung', false);
  }

  static Future<void> keluar() async {
    for (final k in ['pedagangId', 'nama', 'namaUsaha', 'noWa', 'briTersambung', 'briRekening', 'briNama']) {
      await _p.remove(k);
    }
  }
}

/// 6281234567890 -> 0812****890
String samarkanWa(String wa) {
  final lokal = wa.startsWith('62') ? '0${wa.substring(2)}' : wa;
  if (lokal.length < 8) return lokal;
  return '${lokal.substring(0, 4)}****${lokal.substring(lokal.length - 3)}';
}
