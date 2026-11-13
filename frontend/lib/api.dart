import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Alamat backend diisi saat build:
///   flutter run -d chrome --dart-define=API_URL=http://localhost:8080
///   flutter build web --dart-define=API_URL=https://xxx.up.railway.app --dart-define=API_KEY=...
class Api {
  static const base = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');
  static const _kunci = String.fromEnvironment('API_KEY');

  static Map<String, String> get _header => {
        'Content-Type': 'application/json',
        if (_kunci.isNotEmpty) 'X-Api-Key': _kunci,
      };

  static Uri _u(String path, [Map<String, String>? q]) => Uri.parse('$base$path').replace(queryParameters: q);

  static dynamic _hasil(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final pesan = body is Map ? (body['message'] ?? body['error'] ?? 'Terjadi kesalahan') : 'Terjadi kesalahan';
    throw ApiGagal(r.statusCode, pesan.toString());
  }

  static Future<Map<String, dynamic>> daftar({required String nama, String? namaUsaha, required String noWa}) async =>
      _hasil(await http.post(_u('/api/pedagang'),
          headers: _header, body: jsonEncode({'nama': nama, 'namaUsaha': namaUsaha, 'noWa': noWa})));

  static Future<Map<String, dynamic>> masuk(String noWa) async =>
      _hasil(await http.post(_u('/api/pedagang/masuk'), headers: _header, body: jsonEncode({'noWa': noWa})));

  static Future<Map<String, dynamic>> pedagang(String id) async =>
      _hasil(await http.get(_u('/api/pedagang/$id'), headers: _header));

  static Future<Map<String, dynamic>> ubahPedagang(String id, Map<String, dynamic> data) async =>
      _hasil(await http.patch(_u('/api/pedagang/$id'), headers: _header, body: jsonEncode(data)));

  static Future<void> isiDataContoh(String id) async =>
      _hasil(await http.post(_u('/api/pedagang/$id/data-contoh'), headers: _header));

  static Future<void> hapusDataContoh(String id) async =>
      _hasil(await http.delete(_u('/api/pedagang/$id/data-contoh'), headers: _header));

  static Future<Map<String, dynamic>> catatTeks(String id, String teks) async =>
      _hasil(await http.post(_u('/api/pedagang/$id/catat'), headers: _header, body: jsonEncode({'teks': teks})));

  static Future<Map<String, dynamic>> catatSuara(String id, Uint8List audio, String mime) async {
    final req = http.MultipartRequest('POST', _u('/api/pedagang/$id/catat-suara'));
    if (_kunci.isNotEmpty) req.headers['X-Api-Key'] = _kunci;
    final jenis = mime.split('/');
    req.files.add(http.MultipartFile.fromBytes('audio', audio,
        filename: 'catatan.${jenis.last}', contentType: MediaType(jenis.first, jenis.last)));
    return _hasil(await http.Response.fromStream(await req.send()));
  }

  static Future<List<dynamic>> transaksi(String id, {String? dari, String? sampai}) async =>
      _hasil(await http.get(
          _u('/api/pedagang/$id/transaksi', {if (dari != null) 'dari': dari, if (sampai != null) 'sampai': sampai}),
          headers: _header));

  static Future<void> hapusTransaksi(String id, String trxId) async =>
      _hasil(await http.delete(_u('/api/pedagang/$id/transaksi/$trxId'), headers: _header));

  static Future<Map<String, dynamic>> laporan(String id, {String? dari, String? sampai}) async =>
      _hasil(await http.get(
          _u('/api/pedagang/$id/laporan', {if (dari != null) 'dari': dari, if (sampai != null) 'sampai': sampai}),
          headers: _header));

  static Future<Map<String, dynamic>> raporKur(String id) async =>
      _hasil(await http.get(_u('/api/pedagang/$id/rapor-kur'), headers: _header));
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
  return 'Server belum bisa dihubungi. Cek koneksi atau alamat API.';
}
