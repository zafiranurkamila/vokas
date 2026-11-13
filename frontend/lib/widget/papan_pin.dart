import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tema.dart';

/// Kotak kode (OTP terlihat, PIN disamarkan) plus papan angka sendiri, seperti aplikasi bank.
class PapanPin extends StatefulWidget {
  const PapanPin({
    super.key,
    required this.onSelesai,
    this.panjang = 6,
    this.sembunyi = false,
    this.salah = false,
  });

  final ValueChanged<String> onSelesai;
  final int panjang;
  final bool sembunyi;

  /// true: kotak bergetar merah lalu dikosongkan.
  final bool salah;

  @override
  State<PapanPin> createState() => PapanPinState();
}

class PapanPinState extends State<PapanPin> with SingleTickerProviderStateMixin {
  String _isi = '';
  late final _getar = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  void kosongkan() => setState(() => _isi = '');

  @override
  void didUpdateWidget(PapanPin old) {
    super.didUpdateWidget(old);
    if (widget.salah && !old.salah) {
      _getar.forward(from: 0);
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted) setState(() => _isi = '');
      });
    }
  }

  @override
  void dispose() {
    _getar.dispose();
    super.dispose();
  }

  void _tekan(String k) {
    if (k == '<') {
      if (_isi.isNotEmpty) setState(() => _isi = _isi.substring(0, _isi.length - 1));
      return;
    }
    if (_isi.length >= widget.panjang) return;
    setState(() => _isi += k);
    if (_isi.length == widget.panjang) {
      final kode = _isi;
      Future.delayed(const Duration(milliseconds: 150), () => widget.onSelesai(kode));
    }
  }

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _getar,
          builder: (_, child) {
            final t = _getar.value;
            final dx = t == 0 ? 0.0 : 10 * (1 - t) * ((t * 10).floor().isEven ? 1 : -1);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.panjang, (i) {
              final terisi = i < _isi.length;
              final aktif = i == _isi.length;
              final merah = widget.salah;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: widget.sembunyi ? 18 : 44,
                height: widget.sembunyi ? 18 : 52,
                decoration: widget.sembunyi
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: terisi ? (merah ? Warna.merah : Warna.oliveTua) : Colors.transparent,
                        border: Border.all(color: merah ? Warna.merah : (aktif ? Warna.oliveTua : Warna.garis), width: 2),
                      )
                    : BoxDecoration(
                        color: Warna.kartu,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: merah ? Warna.merah : (aktif ? Warna.olive : Warna.garis), width: aktif ? 2 : 1.2),
                      ),
                alignment: Alignment.center,
                child: widget.sembunyi || !terisi
                    ? null
                    : Text(_isi[i], style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600)),
              );
            }),
          ),
        ),
        const SizedBox(height: 28),
        for (final baris in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final k in baris)
                SizedBox(
                  width: 84,
                  height: 60,
                  child: k.isEmpty
                      ? null
                      : InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => _tekan(k),
                          child: Center(
                            child: k == '<'
                                ? const Icon(Icons.backspace_outlined, color: Warna.tinta)
                                : Text(k, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w500)),
                          ),
                        ),
                ),
            ],
          ),
      ]);
}

/// Baris kecil "Mode demo / versi resmi" yang dipakai di layar auth dan sambung BRI.
class CatatanDemo extends StatelessWidget {
  const CatatanDemo(this.teks, {super.key});
  final String teks;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Warna.khaki.withOpacity(.45), borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Warna.oliveTua),
          const SizedBox(width: 8),
          Expanded(child: Text(teks, style: const TextStyle(fontSize: 12, height: 1.45, color: Warna.oliveTua))),
        ]),
      );
}
