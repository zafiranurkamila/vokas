import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../sesi.dart';
import '../tema.dart';

/// Layar persetujuan sambung rekening BRI, bergaya layar izin aplikasi bank.
/// VoKas tidak pernah meminta user ID, password, atau PIN BRImo.
/// Di prototipe ini sambungan hanya simulasi; integrasi resmi lewat BRIAPI butuh kerja sama dengan BRI.
class LayarSambungBri extends StatefulWidget {
  const LayarSambungBri({super.key});

  @override
  State<LayarSambungBri> createState() => _LayarSambungBriState();
}

class _LayarSambungBriState extends State<LayarSambungBri> {
  bool _menyambung = false;

  Future<void> _pilih(bool sambung) async {
    if (sambung) {
      setState(() => _menyambung = true);
      await Future.delayed(const Duration(milliseconds: 1200)); // jeda singkat seperti menunggu persetujuan
    }
    await Sesi.pilihBri(sambung);
    if (mounted) lanjut(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _Hubungan(),
                  const SizedBox(height: 28),
                  Text('Hubungkan rekening BRI',
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25)),
                  const SizedBox(height: 8),
                  const Text(
                    'Pembayaran QRIS dan transfer masuk akan tercatat sendiri, jadi kamu tidak perlu mengetik ulang.',
                    style: TextStyle(color: Warna.redup, height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  const Text('VOKAS AKAN BISA',
                      style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600, color: Warna.redup)),
                  const SizedBox(height: 4),
                  const _Izin('Melihat mutasi QRIS masuk', 'Untuk dicatat sebagai penjualan'),
                  const _Izin('Melihat transfer masuk dan keluar', 'Kamu yang memutuskan: uang usaha atau bukan'),
                  const SizedBox(height: 20),
                  const Text('VOKAS TIDAK AKAN',
                      style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600, color: Warna.redup)),
                  const SizedBox(height: 4),
                  const _Izin('Meminta user ID, password, atau PIN', null),
                  const _Izin('Memindahkan uang dari rekeningmu', null),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _menyambung ? null : () => _pilih(true),
                    child: _menyambung
                        ? const Row(mainAxisSize: MainAxisSize.min, children: [
                            SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
                            SizedBox(width: 12),
                            Text('Menghubungkan...'),
                          ])
                        : const Text('Hubungkan'),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _menyambung ? null : () => _pilih(false),
                      child: const Text('Nanti saja', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Mode demo: belum terhubung ke sistem BRI.',
                    style: TextStyle(fontSize: 12, color: Warna.redup, height: 1.5),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Logo VoKas dan ikon bank yang dihubungkan garis putus-putus.
class _Hubungan extends StatelessWidget {
  const _Hubungan();

  @override
  Widget build(BuildContext context) => Row(children: [
        SvgPicture.asset('assets/vokas_ikon.svg', width: 56, height: 56),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Expanded(child: CustomPaint(size: const Size(double.infinity, 2), painter: _GarisPutus())),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Warna.kartu, shape: BoxShape.circle),
                child: const Icon(Icons.link_rounded, size: 18, color: Warna.redup),
              ),
              Expanded(child: CustomPaint(size: const Size(double.infinity, 2), painter: _GarisPutus())),
            ]),
          ),
        ),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Warna.qris, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 28),
        ),
      ]);
}

class _GarisPutus extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Warna.garis
      ..strokeWidth = 2;
    for (double x = 0; x < s.width; x += 8) {
      c.drawLine(Offset(x, s.height / 2), Offset((x + 4).clamp(0, s.width), s.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Izin extends StatelessWidget {
  const _Izin(this.judul, this.ket);
  final String judul;
  final String? ket;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Warna.garis))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(judul, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
          if (ket != null) ...[
            const SizedBox(height: 2),
            Text(ket!, style: const TextStyle(fontSize: 12.5, color: Warna.redup)),
          ],
        ]),
      );
}
