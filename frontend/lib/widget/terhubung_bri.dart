import 'package:flutter/material.dart';

import '../tema.dart';

/// Penanda di halaman awal: VoKas terhubung dengan layanan BRI (QRIS, rekening, BRIAPI).
/// [terang] dipakai di atas latar hijau (splash): logo diberi alas putih supaya tetap terbaca.
class TerhubungBri extends StatelessWidget {
  const TerhubungBri({super.key, this.terang = false});
  final bool terang;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Terhubung dengan',
            style: TextStyle(fontSize: 12.5, color: terang ? Warna.khaki : Warna.redup, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Container(
          padding: terang ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : EdgeInsets.zero,
          decoration: terang ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)) : null,
          child: Image.asset('assets/logo/bri.png', height: 18, semanticLabel: 'BRI'),
        ),
      ]);
}
