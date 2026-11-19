import 'package:flutter/material.dart';

import '../tema.dart';

/// Penanda di halaman awal: VoKas terhubung dengan layanan BRI (QRIS, rekening, BRIAPI).
/// [terang] dipakai di atas latar hijau (splash): logo versi putih.
class TerhubungBri extends StatelessWidget {
  const TerhubungBri({super.key, this.terang = false});
  final bool terang;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Terhubung dengan',
            style: TextStyle(fontSize: 12.5, color: terang ? Warna.khaki : Warna.redup, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        // di atas latar hijau logo dibuat putih polos, tanpa alas
        Image.asset(terang ? 'assets/logo/bri_putih.png' : 'assets/logo/bri.png', height: 18, semanticLabel: 'BRI'),
      ]);
}
