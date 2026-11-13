import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../sesi.dart';
import '../tema.dart';

/// Layar persetujuan sambung rekening BRI. VoKas tidak pernah meminta user ID, password, atau PIN BRImo.
/// Pada prototipe ini sambungan hanya SIMULASI; integrasi resmi lewat BRIAPI butuh kerja sama dengan BRI.
class LayarSambungBri extends StatefulWidget {
  const LayarSambungBri({super.key});

  @override
  State<LayarSambungBri> createState() => _LayarSambungBriState();
}

class _LayarSambungBriState extends State<LayarSambungBri> {
  bool _setuju = false;

  Future<void> _pilih(bool sambung) async {
    await Sesi.pilihBri(sambung);
    if (!mounted) return;
    if (sambung) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulasi: rekening BRI tersambung. Data mutasi masih data contoh.')));
    }
    lanjut(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Warna.matahari.withOpacity(.25), borderRadius: BorderRadius.circular(99)),
                      child: const Text('SIMULASI PROTOTIPE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6, color: Color(0xFF7A5E00))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: Warna.qris, borderRadius: BorderRadius.circular(22)),
                    child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 20),
                  Text('Sambungkan rekening BRI', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Supaya pembayaran QRIS dan transfer masuk tercatat sendiri tanpa diketik.',
                      style: TextStyle(color: Warna.redup, height: 1.5)),
                  const SizedBox(height: 20),
                  Kartu(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                      Text('VoKas akan:', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 10),
                      _Poin(Icons.check_circle_rounded, Warna.olive, 'Membaca mutasi QRIS dan transfer di rekening usaha'),
                      _Poin(Icons.check_circle_rounded, Warna.olive, 'Menandai transfer untuk kamu cek: uang usaha atau bukan'),
                      SizedBox(height: 6),
                      Text('VoKas tidak akan:', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 10),
                      _Poin(Icons.block_rounded, Warna.merah, 'Meminta user ID, password, atau PIN BRImo'),
                      _Poin(Icons.block_rounded, Warna.merah, 'Memindahkan uang dari rekeningmu'),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _setuju,
                    onChanged: (v) => setState(() => _setuju = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Saya setuju VoKas membaca mutasi rekening usaha saya', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _setuju ? () => _pilih(true) : null,
                    child: const Text('Sambungkan (simulasi)'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () => _pilih(false), child: const Text('Nanti saja')),
                  const SizedBox(height: 16),
                  const Text(
                    'Prototipe ini belum terhubung ke sistem BRI. Pada versi pilot, mutasi diambil dari file mutasi '
                    'rekening yang kamu unggah sendiri.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Warna.redup, height: 1.5),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _Poin extends StatelessWidget {
  const _Poin(this.ikon, this.warna, this.teks);
  final IconData ikon;
  final Color warna;
  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ikon, size: 18, color: warna),
          const SizedBox(width: 8),
          Expanded(child: Text(teks, style: const TextStyle(fontSize: 14))),
        ]),
      );
}
