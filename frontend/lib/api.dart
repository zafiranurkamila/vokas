import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Alamat backend diisi saat build:
///   flutter run -d chrome --dart-define=API_URL=http://localhost:8080
///   flutter build web --dart-define=API_URL=https://xxx.onrender.com --dart-define=API_KEY=...
class Api {
  /// Bawaan: server produksi di Render. Untuk tes lokal: --dart-define=API_URL=http://localhost:8080
  /// Catatan: --dart-define=API_URL= (kosong) tetap dianggap "terisi", jadi nilai kosong ditangani di sini.
  static const _urlBuild = String.fromEnvironment('API_URL');
  static const base = _urlBuild == '' ? 'https://vokas-backend.onrender.com' : _urlBuild;
  static const _kunci = String.fromEnvironment('API_KEY');

  /// Batas menunggu server gratis (Render) yang sedang bangun dari tidur.
  static const _batasBangun = Duration(seconds: 180);

  /// Batas mencoba ulang bila koneksi gagal total (bukan karena server sedang bangun).
  static const _batasKoneksi = Duration(seconds: 15);

  /// Dipanggil saat aplikasi sedang menunggu server bangun, supaya layar bisa memberi tahu pengguna.
  static void Function(bool menunggu)? onMenungguServer;

  static Map<String, String> get _header => {
        'Content-Type': 'application/json',
        if (_kunci.isNotEmpty) 'X-Api-Key': _kunci,
      };

  static Uri _u(String path, [Map<String, String>? q]) => Uri.parse('$base$path').replace(queryParameters: q);

  /// Halaman "Application loading" dari Render (bukan jawaban backend kita).
  static bool _serverBangun(http.Response r) {
    if (r.statusCode != 502 && r.statusCode != 503 && r.statusCode != 504) return false;
    final t = r.body.trimLeft();
    return t.startsWith('<') || t.contains('Application loading') || t.isEmpty;
  }

  /// Kirim permintaan; bila server sedang bangun atau koneksi sesaat gagal, tunggu lalu coba lagi.
  static Future<http.Response> _coba(Future<http.Response> Function() kirim) async {
    final mulai = DateTime.now();
    var jeda = const Duration(seconds: 3);
    var memberiTahu = false;
    try {
      while (true) {
        try {
          final r = await kirim();
          if (!_serverBangun(r)) return r;
        } on TimeoutException {
          rethrow;
        } catch (_) {
          // Koneksi gagal total (alamat salah, CORS, internet putus). Server Render yang sedang bangun
          // tetap menjawab dengan halaman "loading", jadi kegagalan seperti ini hanya dicoba ulang sebentar.
          if (DateTime.now().difference(mulai) > _batasKoneksi) rethrow;
        }
        if (DateTime.now().difference(mulai) > _batasBangun) {
          throw ApiGagal(503, 'VoKas belum siap. Coba lagi sebentar lagi.');
        }
        if (!memberiTahu) {
          memberiTahu = true;
          onMenungguServer?.call(true);
        }
        await Future.delayed(jeda);
        if (jeda < const Duration(seconds: 8)) jeda += const Duration(seconds: 1);
      }
    } finally {
      if (memberiTahu) onMenungguServer?.call(false);
    }
  }

  static dynamic _hasil(http.Response r) {
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      body = null; // bukan JSON (misalnya halaman error dari server perantara)
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final pesan = body is Map
        ? (body['message'] ?? body['error'] ?? 'Terjadi kesalahan')
        : (r.statusCode >= 500 ? 'Ada gangguan sebentar (${r.statusCode}). Coba lagi ya.' : 'Terjadi kesalahan');
    throw ApiGagal(r.statusCode, pesan.toString());
  }

  /// Ping ringan untuk membangunkan server gratis yang sedang tidur. Dipanggil saat aplikasi dibuka.
  static Future<void> bangunkan() async {
    try {
      await http.get(_u('/actuator/health')).timeout(const Duration(seconds: 120));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> daftar({required String nama, String? namaUsaha, required String noWa}) async =>
      _hasil(await _coba(() => http.post(_u('/api/pedagang'),
          headers: _header, body: jsonEncode({'nama': nama, 'namaUsaha': namaUsaha, 'noWa': noWa}))));

  static Future<Map<String, dynamic>> masuk(String noWa) async => _hasil(
      await _coba(() => http.post(_u('/api/pedagang/masuk'), headers: _header, body: jsonEncode({'noWa': noWa}))));

  static Future<Map<String, dynamic>> pedagang(String id) async =>
      _hasil(await _coba(() => http.get(_u('/api/pedagang/$id'), headers: _header)));

  static Future<Map<String, dynamic>> ubahPedagang(String id, Map<String, dynamic> data) async =>
      _hasil(await _coba(() => http.patch(_u('/api/pedagang/$id'), headers: _header, body: jsonEncode(data))));

  static Future<void> isiDataContoh(String id) async =>
      _hasil(await _coba(() => http.post(_u('/api/pedagang/$id/data-contoh'), headers: _header)));

  static Future<void> hapusDataContoh(String id) async =>
      _hasil(await _coba(() => http.delete(_u('/api/pedagang/$id/data-contoh'), headers: _header)));

  static Future<Map<String, dynamic>> imporMutasi(String id, List<Map<String, dynamic>> mutasi) async => _hasil(
      await _coba(() => http.post(_u('/api/pedagang/$id/mutasi/impor'), headers: _header, body: jsonEncode(mutasi))));

  /// Ambil mutasi rekening dari BRIAPI (sandbox) lalu catat ke VoKas.
  static Future<Map<String, dynamic>> sinkronBri(String id, String noRek, {int hari = 7}) async =>
      _hasil(await _coba(() => http
          .post(_u('/api/bri/pedagang/$id/sinkron-mutasi'),
              headers: _header, body: jsonEncode({'accountNo': noRek, 'hari': hari}))
          .timeout(const Duration(seconds: 60))));

  /// Tanya AI tentang usaha sendiri. Hasil: {teks, galat}
  static Future<Map<String, dynamic>> tanyaAi(String id, String pertanyaan) async => _hasil(await _coba(() => http
      .post(_u('/api/ai/pedagang/$id/tanya'), headers: _header, body: jsonEncode({'pertanyaan': pertanyaan}))
      .timeout(const Duration(seconds: 90))));

  // ---------------- auth (email / WA + PIN di server) ----------------

  /// keperluan: 'DAFTAR' (identitas = email baru) atau 'LUPA_PIN' (identitas = email/WA terdaftar). Hasil: {email (disamarkan)}
  static Future<Map<String, dynamic>> kirimKode(String identitas, String keperluan) async => _hasil(await _coba(() =>
      http.post(_u('/api/auth/kode'), headers: _header, body: jsonEncode({'identitas': identitas, 'keperluan': keperluan}))));

  static Future<Map<String, dynamic>> daftarAkun({
    required String nama,
    String? namaUsaha,
    required String noWa,
    String? email,
    String? kode,
    String? googleIdToken,
    String? googleAccessToken,
    required String pin,
  }) async =>
      _hasil(await _coba(() => http.post(_u('/api/auth/daftar'),
          headers: _header,
          body: jsonEncode({
            'nama': nama,
            'namaUsaha': namaUsaha,
            'noWa': noWa,
            'email': email,
            'kode': kode,
            'googleIdToken': googleIdToken,
            'googleAccessToken': googleAccessToken,
            'pin': pin,
          }))));

  /// identitas: email atau nomor WA
  static Future<Map<String, dynamic>> masukAkun(String identitas, String pin) async => _hasil(await _coba(() =>
      http.post(_u('/api/auth/masuk'), headers: _header, body: jsonEncode({'identitas': identitas, 'pin': pin}))));

  static Future<Map<String, dynamic>> lupaPin(String identitas, String pinBaru,
          {String? kode, String? googleIdToken, String? googleAccessToken}) async =>
      _hasil(await _coba(() => http.post(_u('/api/auth/lupa-pin'),
          headers: _header,
          body: jsonEncode({
            'identitas': identitas,
            'kode': kode,
            'googleIdToken': googleIdToken,
            'googleAccessToken': googleAccessToken,
            'pinBaru': pinBaru,
          }))));

  /// Hasil: {terdaftar: true, pedagang} atau {terdaftar: false, email, nama}
  static Future<Map<String, dynamic>> masukGoogle(String? idToken, String? accessToken) async => _hasil(await _coba(() =>
      http.post(_u('/api/auth/google'), headers: _header, body: jsonEncode({'idToken': idToken, 'accessToken': accessToken}))));

  // ---------------- ekspor laporan ----------------

  /// format: 'pdf' atau 'xlsx'. Hasil: (isi berkas, nama berkas)
  static Future<(Uint8List, String)> eksporLaporan(String id, String format, {String? dari, String? sampai}) async {
    final r = await _coba(() => http
        .get(_u('/api/pedagang/$id/laporan/ekspor',
            {'format': format, if (dari != null) 'dari': dari, if (sampai != null) 'sampai': sampai}), headers: _header)
        .timeout(const Duration(seconds: 60)));
    if (r.statusCode != 200) _hasil(r);
    final cd = r.headers['content-disposition'] ?? '';
    final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
    return (r.bodyBytes, m?.group(1) ?? 'Laporan_VoKas.$format');
  }

  static Future<Map<String, dynamic>> kirimLaporanKeEmail(String id, {String? dari, String? sampai}) async =>
      _hasil(await _coba(() => http
          .post(_u('/api/pedagang/$id/laporan/kirim-email', {if (dari != null) 'dari': dari, if (sampai != null) 'sampai': sampai}),
              headers: _header)
          .timeout(const Duration(seconds: 90))));

  // ---------------- pengajuan QRIS BRI ----------------

  static Future<Map<String, dynamic>?> statusQris(String id) async {
    try {
      return _hasil(await _coba(() => http.get(_u('/api/pedagang/$id/qris'), headers: _header)));
    } on ApiGagal catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> ajukanQris(String id, Map<String, dynamic> data) async =>
      _hasil(await _coba(() => http.post(_u('/api/pedagang/$id/qris'), headers: _header, body: jsonEncode(data))));

  static Future<void> batalQris(String id) async =>
      _hasil(await _coba(() => http.delete(_u('/api/pedagang/$id/qris'), headers: _header)));

  /// Email laporan: kirim kode OTP ke email, lalu verifikasi.
  static Future<Map<String, dynamic>> daftarEmail(String id, String email) async => _hasil(
      await _coba(() => http.post(_u('/api/pedagang/$id/email'), headers: _header, body: jsonEncode({'email': email}))));

  static Future<Map<String, dynamic>> verifikasiEmail(String id, String kode) async => _hasil(await _coba(
      () => http.post(_u('/api/pedagang/$id/email/verifikasi'), headers: _header, body: jsonEncode({'kode': kode}))));

  static Future<Map<String, dynamic>> aturLaporanEmail(String id, bool aktif) async => _hasil(await _coba(
      () => http.patch(_u('/api/pedagang/$id/email'), headers: _header, body: jsonEncode({'laporanEmail': aktif}))));

  /// jenis: 'harian' (settlement hari ini) atau 'bulanan' (bulan berjalan). Hasil: {email, wa}
  static Future<Map<String, dynamic>> kirimLaporanEmail(String id, String jenis) async => _hasil(await _coba(() => http
      .post(_u('/api/pedagang/$id/email/kirim-laporan', {'jenis': jenis}), headers: _header)
      .timeout(const Duration(seconds: 60))));

  /// Riwayat tersimpan: jenis 'TANYA' (Tanya AI) atau 'CATAT' (voice note / teks). Urut dari yang paling lama.
  static Future<List<dynamic>> riwayatAi(String id, String jenis) async =>
      _hasil(await _coba(() => http.get(_u('/api/pedagang/$id/riwayat-ai', {'jenis': jenis}), headers: _header)));

  static Future<void> hapusRiwayatAi(String id, String jenis) async =>
      _hasil(await _coba(() => http.delete(_u('/api/pedagang/$id/riwayat-ai', {'jenis': jenis}), headers: _header)));

  static Future<Map<String, dynamic>> catatTeks(String id, String teks) async => _hasil(
      await _coba(() => http.post(_u('/api/pedagang/$id/catat'), headers: _header, body: jsonEncode({'teks': teks}))));

  static Future<Map<String, dynamic>> catatSuara(String id, Uint8List audio, String mime) async {
    final jenis = mime.split('/');
    return _hasil(await _coba(() async {
      // permintaan multipart tidak bisa dikirim ulang, jadi dibuat baru di setiap percobaan
      final req = http.MultipartRequest('POST', _u('/api/pedagang/$id/catat-suara'));
      if (_kunci.isNotEmpty) req.headers['X-Api-Key'] = _kunci;
      req.files.add(http.MultipartFile.fromBytes('audio', audio,
          filename: 'catatan.${jenis.last}', contentType: MediaType(jenis.first, jenis.last)));
      return http.Response.fromStream(await req.send());
    }));
  }

  static Future<List<dynamic>> transaksi(String id, {String? dari, String? sampai}) async =>
      _hasil(await _coba(() => http.get(
          _u('/api/pedagang/$id/transaksi', {if (dari != null) 'dari': dari, if (sampai != null) 'sampai': sampai}),
          headers: _header)));

  static Future<void> hapusTransaksi(String id, String trxId) async =>
      _hasil(await _coba(() => http.delete(_u('/api/pedagang/$id/transaksi/$trxId'), headers: _header)));

  static Future<Map<String, dynamic>> laporan(String id, {String? dari, String? sampai}) async =>
      _hasil(await _coba(() => http.get(
          _u('/api/pedagang/$id/laporan', {if (dari != null) 'dari': dari, if (sampai != null) 'sampai': sampai}),
          headers: _header)));

  static Future<Map<String, dynamic>> raporKur(String id) async =>
      _hasil(await _coba(() => http.get(_u('/api/pedagang/$id/rapor-kur'), headers: _header)));
}

class ApiGagal implements Exception {
  ApiGagal(this.status, this.pesan);
  final int status;
  final String pesan;

  @override
  String toString() => pesan;
}

/// Pesan ramah untuk ditampilkan di SnackBar.
String pesanGalat(Object e) {
  if (e is ApiGagal && e.pesan.startsWith('No static resource')) {
    return 'Fitur ini belum ada di server. Jalankan ulang backend versi terbaru.';
  }
  if (e is ApiGagal) return e.pesan;
  if (e is TimeoutException) return 'Server terlalu lama menjawab. Coba lagi sebentar.';
  return 'Tidak bisa terhubung ke server. Cek koneksi internet, lalu coba lagi.';
}
