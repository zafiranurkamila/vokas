import 'package:share_plus/share_plus.dart';

import '../sesi.dart';
import '../tema.dart';

/// Struk digital untuk pembeli: teks rapi yang bisa dikirim lewat WhatsApp atau aplikasi lain.
String teksStruk(List<Map<String, dynamic>> transaksi) {
  final masuk = transaksi.where((t) => t['jenis'] == 'MASUK').toList();
  final daftar = masuk.isEmpty ? transaksi : masuk;
  final usaha = Sesi.namaUsaha.isNotEmpty ? Sesi.namaUsaha : (Sesi.nama.isNotEmpty ? Sesi.nama : 'VoKas');
  final w = DateTime.now();
  final tgl = '${w.day.toString().padLeft(2, '0')}/${w.month.toString().padLeft(2, '0')}/${w.year} '
      '${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';
  final b = StringBuffer()
    ..writeln('*STRUK ${usaha.toUpperCase()}*')
    ..writeln(tgl)
    ..writeln('------------------------------');
  num total = 0;
  for (final t in daftar) {
    final nama = '${t['namaItem']}';
    final judul = nama.isEmpty ? nama : nama[0].toUpperCase() + nama.substring(1);
    final jumlah = t['jumlah'];
    final harga = t['hargaSatuan'];
    final sub = (t['total'] as num?) ?? 0;
    total += sub;
    b.writeln(judul);
    b.writeln(jumlah != null && harga != null ? '  $jumlah x ${rp(harga as num)} = ${rp(sub)}' : '  ${rp(sub)}');
  }
  b
    ..writeln('------------------------------')
    ..writeln('*TOTAL ${rp(total)}*')
    ..writeln()
    ..writeln('Terima kasih sudah belanja!')
    ..write('_Dicatat dengan VoKas_');
  return b.toString();
}

Future<void> bagikanStruk(List<Map<String, dynamic>> transaksi) =>
    Share.share(teksStruk(transaksi), subject: 'Struk ${Sesi.namaUsaha}');
