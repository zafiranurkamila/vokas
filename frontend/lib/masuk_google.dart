import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In asli. Client ID (Web) diisi saat build: --dart-define=GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
/// Android: daftarkan OAuth client tipe Android (nama paket + SHA-1 kunci penanda tangan APK) di project yang sama.
class MasukGoogle {
  static const clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static bool get tersedia => clientId.isNotEmpty;

  static GoogleSignIn? _g;

  static GoogleSignIn get _klien => _g ??= GoogleSignIn(
        clientId: kIsWeb ? clientId : null,
        serverClientId: kIsWeb ? null : clientId,
        scopes: const ['email', 'profile'],
      );

  /// Membuka pemilih akun Google. Hasil null bila dibatalkan.
  static Future<({String? idToken, String? accessToken})?> pilihAkun() async {
    try {
      await _klien.signOut(); // supaya pengguna bisa memilih akun lain
    } catch (_) {}
    final akun = await _klien.signIn();
    if (akun == null) return null;
    final a = await akun.authentication;
    return (idToken: a.idToken, accessToken: a.accessToken);
  }
}
