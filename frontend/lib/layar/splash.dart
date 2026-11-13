import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../tema.dart';
import 'profil.dart' show PoweredBy;

class LayarSplash extends StatefulWidget {
  const LayarSplash({super.key});

  @override
  State<LayarSplash> createState() => _LayarSplashState();
}

class _LayarSplashState extends State<LayarSplash> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) lanjut(context);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Warna.oliveTua,
        body: Stack(children: [
          Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween(begin: .85, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SvgPicture.asset('assets/vokas_ikon.svg', width: 112),
                const SizedBox(height: 18),
                Text('VoKas',
                    style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -.5)),
                Text('Catat usaha cukup lewat suara', style: GoogleFonts.poppins(fontSize: 14, color: Warna.khaki)),
              ]),
            ),
          ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _anim, curve: const Interval(.4, 1)),
              child: const PoweredBy(terang: true),
            ),
          ),
        ]),
      );
}
