import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../sesi.dart';
import '../tema.dart';
import 'papan_pin.dart';

/// Minta PIN sebelum tindakan penting (keluar, putuskan rekening, hapus data). true bila PIN benar.
Future<bool> verifikasiPin(BuildContext context, String alasan) async {
  if (!Sesi.punyaPin(Sesi.noWa)) return true; // perangkat tanpa PIN tersimpan: tidak ada yang dicek
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Warna.latar,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _LembarPin(alasan: alasan),
  );
  return ok == true;
}

class _LembarPin extends StatefulWidget {
  const _LembarPin({required this.alasan});
  final String alasan;

  @override
  State<_LembarPin> createState() => _LembarPinState();
}

class _LembarPinState extends State<_LembarPin> {
  bool _salah = false;
  int _percobaan = 0;

  void _cek(String pin) {
    if (Sesi.cekPin(Sesi.noWa, pin)) {
      Navigator.of(context).pop(true);
      return;
    }
    _percobaan++;
    setState(() => _salah = true);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _salah = false);
    });
    if (_percobaan >= 3) {
      tampilPesan(context, 'PIN salah 3 kali. Coba lagi nanti.', jenis: JenisPesan.gagal);
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 44, height: 5, decoration: BoxDecoration(color: Warna.garis, borderRadius: BorderRadius.circular(5))),
            const SizedBox(height: 18),
            const Icon(Icons.lock_outline_rounded, color: Warna.oliveTua, size: 30),
            const SizedBox(height: 8),
            Text('Masukkan PIN', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(widget.alasan, textAlign: TextAlign.center, style: const TextStyle(color: Warna.redup, fontSize: 13)),
            const SizedBox(height: 22),
            PapanPin(sembunyi: true, salah: _salah, onSelesai: _cek),
          ]),
        ),
      );
}
