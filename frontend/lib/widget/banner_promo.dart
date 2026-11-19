import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tema.dart';

class Promo {
  const Promo({required this.judul, required this.isi, required this.tombol, required this.foto, required this.ikon, required this.warna, required this.onTap, this.warna2});
  final String judul;
  final String isi;
  final String tombol;

  /// Foto di assets/banner/. Bila belum ada, banner memakai warna dan ikon saja.
  final String foto;
  final IconData ikon;
  final Color warna;

  /// Warna kedua untuk banner gradasi (misalnya biru BRI ke hijau VoKas).
  final Color? warna2;
  final VoidCallback onTap;
}

/// Banner promosi bergeser sendiri di atas beranda.
class BannerPromo extends StatefulWidget {
  const BannerPromo(this.daftar, {super.key});
  final List<Promo> daftar;

  @override
  State<BannerPromo> createState() => _BannerPromoState();
}

class _BannerPromoState extends State<BannerPromo> {
  final _ctrl = PageController(viewportFraction: .92);
  int _aktif = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_ctrl.hasClients || widget.daftar.length < 2) return;
      final berikut = (_aktif + 1) % widget.daftar.length;
      _ctrl.animateToPage(berikut, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: 158,
          child: PageView.builder(
            controller: _ctrl,
            padEnds: false,
            itemCount: widget.daftar.length,
            onPageChanged: (i) => setState(() => _aktif = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _Kartu(widget.daftar[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < widget.daftar.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _aktif ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _aktif ? Warna.oliveTua : Warna.garis,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ]),
      ]);
}

class _Kartu extends StatelessWidget {
  const _Kartu(this.p);
  final Promo p;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: p.warna.withOpacity(.35), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: p.warna,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: p.onTap,
            child: Stack(fit: StackFit.expand, children: [
              // foto memenuhi banner; bila berkas belum ada, tampil ikon besar
              Image.asset(
                p.foto,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => p.warna2 != null
                    ? DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [p.warna, p.warna2!])))
                    : Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Icon(p.ikon, size: 84, color: Colors.white.withOpacity(.22)),
                        ),
                      ),
              ),
              // bayangan hijau dari kiri supaya tulisan terbaca di atas foto
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [p.warna.withOpacity(.95), (p.warna2 ?? p.warna).withOpacity(.75), (p.warna2 ?? p.warna).withOpacity(.05)],
                    stops: const [0, .45, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 90, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)],
                      )),
                  const SizedBox(height: 4),
                  Text(p.isi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.35,
                        shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)],
                      )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Text(p.tombol, style: TextStyle(color: p.warna, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
}
