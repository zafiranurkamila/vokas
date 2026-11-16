import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';
import 'kartu_email.dart';

/// Ekspor laporan periode yang sedang dilihat: PDF, Excel, atau kirim ke email (PDF + Excel terlampir).
class KartuEkspor extends StatefulWidget {
  const KartuEkspor({super.key, required this.dari, required this.sampai, required this.label});
  final String dari, sampai, label;

  @override
  State<KartuEkspor> createState() => _KartuEksporState();
}

class _KartuEksporState extends State<KartuEkspor> {
  String? _sibuk; // 'pdf' | 'xlsx' | 'email'

  void _pesan(String s, {JenisPesan? jenis}) {
    if (mounted) tampilPesan(context, s, jenis: jenis);
  }

  Future<void> _unduh(String format) async {
    setState(() => _sibuk = format);
    try {
      final (isi, nama) = await Api.eksporLaporan(Sesi.pedagangId!, format, dari: widget.dari, sampai: widget.sampai);
      final mime = format == 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      await Share.shareXFiles([XFile.fromData(isi, mimeType: mime, name: nama)], subject: nama);
    } catch (e) {
      _pesan(pesanGalat(e), jenis: JenisPesan.gagal);
    } finally {
      if (mounted) setState(() => _sibuk = null);
    }
  }

  Future<void> _kirimEmail() async {
    setState(() => _sibuk = 'email');
    try {
      final r = await Api.kirimLaporanKeEmail(Sesi.pedagangId!, dari: widget.dari, sampai: widget.sampai);
      _pesan('Laporan ${widget.label} (PDF + Excel) terkirim ke ${r['email']}.');
    } on ApiGagal catch (e) {
      _pesan(e.pesan.contains('verifikasi email') ? 'Tambahkan dan verifikasi email dulu di bawah.' : e.pesan,
          jenis: JenisPesan.gagal);
    } catch (e) {
      _pesan(pesanGalat(e), jenis: JenisPesan.gagal);
    } finally {
      if (mounted) setState(() => _sibuk = null);
    }
  }

  Widget _tombol(String kunci, IconData ikon, String label, VoidCallback aksi, Color warna) => Expanded(
        child: OutlinedButton(
          onPressed: _sibuk != null ? null : aksi,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Warna.garis),
            backgroundColor: Warna.kartu,
            foregroundColor: Warna.tinta,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sibuk == kunci
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))
                : Icon(ikon, color: warna, size: 24),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Laporan ${widget.label} berisi ringkasan, per hari, barang terlaris, dan rincian transaksi.',
            style: const TextStyle(fontSize: 12.5, color: Warna.redup, height: 1.45)),
        const SizedBox(height: 10),
        Row(children: [
          _tombol('pdf', Icons.picture_as_pdf_outlined, 'PDF', () => _unduh('pdf'), Warna.merah),
          const SizedBox(width: 8),
          _tombol('xlsx', Icons.table_chart_outlined, 'Excel', () => _unduh('xlsx'), Warna.oliveTua),
          const SizedBox(width: 8),
          _tombol('email', Icons.forward_to_inbox_outlined, 'Email', _kirimEmail, Warna.qris),
        ]),
        const SizedBox(height: 14),
        const KartuEmail(),
      ]);
}
