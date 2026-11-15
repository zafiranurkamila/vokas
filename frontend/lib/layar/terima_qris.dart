import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../notif.dart';
import '../sesi.dart';
import '../tema.dart';

/// Layar "Terima QRIS" untuk ditunjukkan ke pembeli.
/// Demo: kode QR berisi teks contoh (bukan kode QRIS asli) dan pembayaran disimulasikan.
/// Versi resmi: menampilkan QRIS merchant BRI milik pedagang; mutasi masuk lewat BRIAPI.
class LayarTerimaQris extends StatefulWidget {
  const LayarTerimaQris({super.key});

  @override
  State<LayarTerimaQris> createState() => _LayarTerimaQrisState();
}

class _LayarTerimaQrisState extends State<LayarTerimaQris> {
  static const _pilihan = [5000, 10000, 15000, 25000, 50000];
  int _nominal = 15000;
  bool _mengirim = false;

  Future<void> _simulasi() async {
    setState(() => _mengirim = true);
    await Future.delayed(const Duration(milliseconds: 900)); // seolah pembeli sedang memindai dan membayar
    await PusatNotif.i.kirimQrisContoh(_nominal);
    if (mounted) setState(() => _mengirim = false);
  }

  @override
  Widget build(BuildContext context) {
    final usaha = Sesi.namaUsaha.isEmpty ? Sesi.nama : Sesi.namaUsaha;
    return Scaffold(
      appBar: AppBar(title: const Text('Terima QRIS')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(children: [
                  Text(usaha, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    Sesi.briTersambung == true ? 'Rekening BRI ****${Sesi.briRekening}' : 'Rekening BRI belum tersambung',
                    style: const TextStyle(color: Warna.redup, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: 'VOKAS-DEMO:${Sesi.pedagangId}',
                    size: 220,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Warna.tinta),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Warna.tinta),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Warna.matahari.withOpacity(.25), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Contoh tampilan, bukan kode QRIS asli',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6B5200))),
                  ),
                  const SizedBox(height: 8),
                  const Text('Pembeli memindai dengan aplikasi bank atau e-wallet apa pun.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Warna.redup)),
                ]),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Simulasi pembeli bayar', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final n in _pilihan)
                  ChoiceChip(
                    label: Text(rp(n)),
                    selected: _nominal == n,
                    onSelected: (_) => setState(() => _nominal = n),
                    selectedColor: Warna.khaki,
                    showCheckmark: false,
                  ),
              ]),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _mengirim ? null : _simulasi,
                icon: _mengirim
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.qr_code_scanner_rounded),
                label: Text(_mengirim ? 'Menunggu pembayaran...' : 'Pembeli bayar ${rp(_nominal)}'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Uang masuk langsung tercatat sebagai penjualan, lalu muncul notifikasi dengan bunyi ceting.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Warna.redup, height: 1.5),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
