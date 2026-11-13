import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tema.dart';

/// Satu langkah perkenalan. kunci null = kartu di tengah layar tanpa sorotan.
class LangkahTur {
  const LangkahTur({this.kunci, required this.judul, required this.isi});
  final GlobalKey? kunci;
  final String judul;
  final String isi;
}

/// Menampilkan perkenalan fitur satu per satu: layar digelapkan, elemen yang dibahas disorot.
void tampilkanTur(BuildContext context, List<LangkahTur> langkah, {VoidCallback? onSelesai}) {
  late OverlayEntry entri;
  entri = OverlayEntry(
    builder: (_) => _Tur(
      langkah: langkah,
      onSelesai: () {
        entri.remove();
        onSelesai?.call();
      },
    ),
  );
  Overlay.of(context).insert(entri);
}

class _Tur extends StatefulWidget {
  const _Tur({required this.langkah, required this.onSelesai});
  final List<LangkahTur> langkah;
  final VoidCallback onSelesai;

  @override
  State<_Tur> createState() => _TurState();
}

class _TurState extends State<_Tur> {
  int _i = 0;

  Rect? _kotak(GlobalKey? k) {
    final ro = k?.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return null;
    final pos = ro.localToGlobal(Offset.zero);
    return (pos & ro.size).inflate(6);
  }

  void _lanjut() {
    if (_i < widget.langkah.length - 1) {
      setState(() => _i++);
    } else {
      widget.onSelesai();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.langkah[_i];
    final target = _kotak(l.kunci);
    final layar = MediaQuery.of(context).size;
    final akhir = _i == widget.langkah.length - 1;

    final kartu = Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_i + 1} dari ${widget.langkah.length}', style: const TextStyle(fontSize: 11.5, color: Warna.redup)),
          const SizedBox(height: 4),
          Text(l.judul, style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(l.isi, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Warna.tinta)),
          const SizedBox(height: 6),
          Row(children: [
            if (!akhir) TextButton(onPressed: widget.onSelesai, child: const Text('Lewati', style: TextStyle(color: Warna.redup))),
            const Spacer(),
            FilledButton(
              onPressed: _lanjut,
              style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
              child: Text(akhir ? 'Mulai' : 'Lanjut'),
            ),
          ]),
        ]),
      ),
    );

    // posisi kartu: di atas sorotan bila sorotan di bagian bawah layar, selain itu di bawahnya
    Widget posisiKartu;
    if (target == null) {
      posisiKartu = Center(child: kartu);
    } else {
      final diBawah = target.center.dy > layar.height / 2;
      final kiri = (target.center.dx - 150).clamp(12.0, layar.width - 312).toDouble();
      posisiKartu = Positioned(
        left: kiri,
        top: diBawah ? null : target.bottom + 14,
        bottom: diBawah ? layar.height - target.top + 14 : null,
        child: kartu,
      );
    }

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: _lanjut,
          child: TweenAnimationBuilder<Rect?>(
            tween: RectTween(end: target ?? Rect.fromCenter(center: layar.center(Offset.zero), width: 0, height: 0)),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (_, r, __) => CustomPaint(painter: _Gelap(r)),
          ),
        ),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_i), child: Stack(children: [posisiKartu])),
      ),
    ]);
  }
}

class _Gelap extends CustomPainter {
  _Gelap(this.lubang);
  final Rect? lubang;

  @override
  void paint(Canvas c, Size s) {
    final layar = Path()..addRect(Offset.zero & s);
    final p = Paint()..color = const Color(0xB3141A10);
    if (lubang == null || lubang!.isEmpty) {
      c.drawPath(layar, p);
      return;
    }
    final r = RRect.fromRectAndRadius(lubang!, const Radius.circular(18));
    c.drawPath(Path.combine(PathOperation.difference, layar, Path()..addRRect(r)), p);
    c.drawRRect(
        r,
        Paint()
          ..color = Warna.matahari
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(_Gelap o) => o.lubang != lubang;
}
