import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../sesi.dart';
import '../tema.dart';

class _Langkah {
  const _Langkah(this.ikon, this.warna, this.judul, this.isi);
  final IconData ikon;
  final Color warna;
  final String judul;
  final String isi;
}

const _langkah = [
  _Langkah(Icons.mic_rounded, Warna.olive, 'Cukup ngomong,\nlangsung tercatat',
      'Kirim voice note atau chat WhatsApp seperti biasa. VoKas mengubahnya jadi catatan jual-beli.'),
  _Langkah(Icons.qr_code_2_rounded, Warna.qris, 'QRIS & transfer\nikut masuk',
      'Pembayaran QRIS tercatat sendiri. Transfer masuk tinggal dikonfirmasi: uang usaha atau bukan.'),
  _Langkah(Icons.verified_rounded, Warna.matahari, 'Rapor Kesiapan KUR',
      'Catatan rapi tiap hari jadi rapor yang bisa dibawa saat mengajukan KUR BRI.'),
];

class LayarIntro extends StatefulWidget {
  const LayarIntro({super.key});

  @override
  State<LayarIntro> createState() => _LayarIntroState();
}

class _LayarIntroState extends State<LayarIntro> {
  final _hal = PageController();
  int _i = 0;

  Future<void> _selesai() async {
    await Sesi.selesaiIntro();
    if (mounted) lanjut(context);
  }

  @override
  Widget build(BuildContext context) {
    final akhir = _i == _langkah.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _selesai, child: const Text('Lewati')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _hal,
                itemCount: _langkah.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) => _HalamanIntro(_langkah[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _langkah.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _i ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: i == _i ? Warna.oliveTua : Warna.khaki, borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: akhir
                  ? _selesai
                  : () => _hal.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
              child: Text(akhir ? 'Mulai' : 'Lanjut'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tiap halaman: ikon muncul memantul, gelombang berdenyut di belakangnya, lalu judul dan teks naik pelan.
class _HalamanIntro extends StatefulWidget {
  const _HalamanIntro(this.l);
  final _Langkah l;

  @override
  State<_HalamanIntro> createState() => _HalamanIntroState();
}

class _HalamanIntroState extends State<_HalamanIntro> with TickerProviderStateMixin {
  late final _masuk = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final _denyut = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _masuk.dispose();
    _denyut.dispose();
    super.dispose();
  }

  Animation<double> _bagian(double a, double b, [Curve c = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _masuk, curve: Interval(a, b, curve: c));

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final ikon = _bagian(0, .55, Curves.elasticOut);
    final judul = _bagian(.3, .75);
    final isi = _bagian(.45, 1);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 240,
        height: 240,
        child: Stack(alignment: Alignment.center, children: [
          // dua gelombang berdenyut, seperti suara yang sedang direkam
          for (final geser in [0.0, .5])
            AnimatedBuilder(
              animation: _denyut,
              builder: (_, __) {
                final t = (_denyut.value + geser) % 1;
                return Container(
                  width: 130 + 110 * t,
                  height: 130 + 110 * t,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: l.warna.withOpacity(.22 * (1 - t))),
                );
              },
            ),
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(color: Warna.khaki.withOpacity(.7), shape: BoxShape.circle),
          ),
          ScaleTransition(
            scale: ikon,
            child: RotationTransition(
              turns: Tween(begin: -.04, end: 0.0).animate(ikon),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: l.warna,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: l.warna.withOpacity(.35), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: Icon(l.ikon, size: 64, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 28),
      _Naik(judul,
          Text(l.judul,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2))),
      const SizedBox(height: 12),
      _Naik(isi,
          Text(l.isi,
              textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 15, color: Warna.redup, height: 1.5))),
    ]);
  }
}

class _Naik extends StatelessWidget {
  const _Naik(this.a, this.child);
  final Animation<double> a;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: a,
        child: SlideTransition(position: Tween(begin: const Offset(0, .25), end: Offset.zero).animate(a), child: child),
      );
}
