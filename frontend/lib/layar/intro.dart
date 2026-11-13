import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../sesi.dart';
import '../tema.dart';

class _Langkah {
  const _Langkah(this.judul, this.isi, this.ilustrasi);
  final String judul;
  final String isi;
  final Widget Function(Animation<double>) ilustrasi;
}

final _langkah = [
  _Langkah('Cukup ngomong,\nlangsung tercatat',
      'Kirim voice note seperti biasa. VoKas mengubahnya jadi catatan jual-beli.', (a) => _IlustrasiSuara(a)),
  _Langkah('QRIS & transfer\nikut tercatat',
      'Pembayaran QRIS masuk sendiri. Transfer tinggal kamu tandai: uang usaha atau bukan.', (a) => _IlustrasiQris(a)),
  _Langkah('Catatan rapi jadi\nRapor Kesiapan KUR',
      'Bawa rapornya saat mengajukan KUR ke BRI, tanpa repot menyusun laporan.', (a) => _IlustrasiKur(a)),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(children: [
                SizedBox(
                  height: 40,
                  child: Row(children: [
                    Text('${_i + 1}/${_langkah.length}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Warna.redup)),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: akhir ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: OutlinedButton(
                        onPressed: akhir ? null : _selesai,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          side: const BorderSide(color: Warna.garis),
                          backgroundColor: Warna.kartu,
                          foregroundColor: Warna.tinta,
                          shape: const StadiumBorder(),
                          textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Lewati'),
                      ),
                    ),
                  ]),
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
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _i ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: i == _i ? Warna.oliveTua : Warna.garis, borderRadius: BorderRadius.circular(7)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: akhir
                      ? _selesai
                      : () => _hal.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic),
                  child: Text(akhir ? 'Mulai sekarang' : 'Lanjut'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _HalamanIntro extends StatefulWidget {
  const _HalamanIntro(this.l);
  final _Langkah l;

  @override
  State<_HalamanIntro> createState() => _HalamanIntroState();
}

class _HalamanIntroState extends State<_HalamanIntro> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teks = CurvedAnimation(parent: _a, curve: const Interval(.15, .6, curve: Curves.easeOutCubic));
    return Column(children: [
      const SizedBox(height: 8),
      Expanded(child: Center(child: widget.l.ilustrasi(_a))),
      const SizedBox(height: 16),
      Muncul(
        teks,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.l.judul, style: GoogleFonts.poppins(fontSize: 25, fontWeight: FontWeight.w700, height: 1.2)),
          const SizedBox(height: 10),
          Text(widget.l.isi, style: const TextStyle(fontSize: 14.5, color: Warna.redup, height: 1.55)),
        ]),
      ),
      const SizedBox(height: 24),
    ]);
  }
}

/// Fade + naik sedikit, dipakai untuk memunculkan elemen bergantian.
class Muncul extends StatelessWidget {
  const Muncul(this.a, {super.key, required this.child, this.dari = const Offset(0, .15)});
  final Animation<double> a;
  final Widget child;
  final Offset dari;

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: a,
        child: SlideTransition(position: Tween(begin: dari, end: Offset.zero).animate(a), child: child),
      );
}

Animation<double> _iv(Animation<double> a, double mulai, double akhir) =>
    CurvedAnimation(parent: a, curve: Interval(mulai, akhir, curve: Curves.easeOutCubic));

BoxDecoration _kotak([Color warna = Warna.kartu]) => BoxDecoration(
      color: warna,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 6))],
    );

// ---------------- langkah 1: voice note -> tercatat ----------------

class _IlustrasiSuara extends StatelessWidget {
  const _IlustrasiSuara(this.a);
  final Animation<double> a;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Muncul(
          _iv(a, 0, .35),
          dari: const Offset(.2, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
              decoration: _kotak(const Color(0xFFDCF3C9)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(color: Warna.oliveTua, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                _Gelombang(a),
                const SizedBox(width: 10),
                const Text('0:06', style: TextStyle(fontSize: 12, color: Warna.redup)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Muncul(
          _iv(a, .15, .45),
          child: const Align(
            alignment: Alignment.centerRight,
            child: Text('"jual cilok tiga puluh bungkus dua ribuan"',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Warna.redup)),
          ),
        ),
        const SizedBox(height: 18),
        Muncul(
          _iv(a, .35, .7),
          dari: const Offset(-.2, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: _kotak(),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Warna.khaki, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_downward_rounded, color: Warna.oliveTua, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cilok', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('30 bungkus × Rp2.000', style: TextStyle(fontSize: 12, color: Warna.redup)),
                ]),
              ),
              const Text('+Rp60.000', style: TextStyle(fontWeight: FontWeight.w700, color: Warna.oliveTua)),
            ]),
          ),
        ),
      ]);
}

class _Gelombang extends StatelessWidget {
  const _Gelombang(this.a);
  final Animation<double> a;
  static const _tinggi = <double>[8, 14, 20, 12, 18, 24, 10, 16, 22, 12, 8, 14, 18, 10];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: a,
        builder: (_, __) {
          final aktif = (a.value * 1.6 * _tinggi.length).floor();
          return Row(children: [
            for (var i = 0; i < _tinggi.length; i++)
              Container(
                width: 3,
                height: _tinggi[i],
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: i < aktif ? Warna.oliveTua : Warna.olive.withOpacity(.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ]);
        },
      );
}

// ---------------- langkah 2: notifikasi QRIS dan transfer ----------------

class _IlustrasiQris extends StatelessWidget {
  const _IlustrasiQris(this.a);
  final Animation<double> a;

  Widget _notif(IconData ikon, Color warna, String judul, String ket, String nominal, {String? label}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: _kotak(),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: warna.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(ikon, color: warna, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(judul, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(ket, style: const TextStyle(fontSize: 12, color: Warna.redup)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(nominal, style: TextStyle(fontWeight: FontWeight.w700, color: warna)),
            if (label != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Warna.matahari.withOpacity(.3), borderRadius: BorderRadius.circular(6)),
                child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
              ),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Muncul(_iv(a, 0, .3), dari: const Offset(0, -.4),
            child: _notif(Icons.qr_code_2_rounded, Warna.qris, 'QRIS masuk', '10.42 · pembeli', '+Rp15.000')),
        const SizedBox(height: 10),
        Muncul(_iv(a, .15, .45), dari: const Offset(0, -.4),
            child: _notif(Icons.qr_code_2_rounded, Warna.qris, 'QRIS masuk', '10.57 · pembeli', '+Rp8.000')),
        const SizedBox(height: 10),
        Muncul(_iv(a, .3, .6), dari: const Offset(0, -.4),
            child: _notif(Icons.swap_horiz_rounded, Warna.oliveTua, 'Transfer masuk', '11.20 · dari Andi', '+Rp250.000',
                label: 'Perlu dicek')),
      ]);
}

// ---------------- langkah 3: rapor KUR ----------------

class _IlustrasiKur extends StatelessWidget {
  const _IlustrasiKur(this.a);
  final Animation<double> a;

  static const _kriteria = [
    ('Konsistensi pencatatan', .93),
    ('Transaksi QRIS BRI', .8),
    ('Keuntungan usaha', .75),
  ];

  @override
  Widget build(BuildContext context) => Muncul(
        _iv(a, 0, .35),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _kotak(),
          child: AnimatedBuilder(
            animation: a,
            builder: (_, __) {
              final t = _iv(a, .2, .85).value;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Rapor Kesiapan KUR', style: TextStyle(fontSize: 12, color: Warna.redup)),
                      Text('Cilok & Cireng Bu Sri', style: TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  Text('${(82 * t).round()}',
                      style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w700, color: Warna.oliveTua)),
                  const Text(' /100', style: TextStyle(color: Warna.redup)),
                ]),
                const SizedBox(height: 14),
                for (final (nama, nilai) in _kriteria) ...[
                  Text(nama, style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                        value: nilai * t, minHeight: 7, backgroundColor: Warna.latar, color: Warna.olive),
                  ),
                  const SizedBox(height: 10),
                ],
                Opacity(
                  opacity: _iv(a, .8, 1).value,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Warna.oliveTua, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Siap dibawa untuk ajukan KUR',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]);
            },
          ),
        ),
      );
}
