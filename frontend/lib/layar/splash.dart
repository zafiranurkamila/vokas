import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../tema.dart';
import 'profil.dart' show PoweredBy;

/// Splash: logo jatuh lalu memantul, bunyi "pop + denting" saat mendarat, lalu nama dan tagline muncul.
class LayarSplash extends StatefulWidget {
  const LayarSplash({super.key});

  @override
  State<LayarSplash> createState() => _LayarSplashState();
}

class _LayarSplashState extends State<LayarSplash> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
  final _suara = AudioPlayer();

  // 0 - .45 : logo jatuh dan memantul
  late final _jatuh = CurvedAnimation(parent: _a, curve: const Interval(0, .45, curve: Curves.bounceOut));
  // .45 - .7 : nama muncul
  late final _nama = CurvedAnimation(parent: _a, curve: const Interval(.45, .7, curve: Curves.easeOutCubic));
  // .6 - .85 : tagline dan powered by
  late final _tagline = CurvedAnimation(parent: _a, curve: const Interval(.6, .85, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _a.forward();
    // pantulan pertama menyentuh dasar sekitar 36% dari interval jatuh (~330 ms)
    Future.delayed(const Duration(milliseconds: 320), _bunyi);
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) lanjut(context);
    });
  }

  Future<void> _bunyi() async {
    try {
      await _suara.play(AssetSource('suara/splash.wav'), volume: .8);
    } catch (_) {
      // browser bisa memblokir suara sebelum ada interaksi pengguna; splash tetap jalan tanpa suara
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _suara.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Warna.oliveTua,
        body: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedBuilder(
                animation: _a,
                builder: (_, child) {
                  final v = _jatuh.value;
                  // sedikit gepeng saat menyentuh dasar, lalu kembali bulat
                  final dekatDasar = (1 - (1 - v).abs() * 6).clamp(0.0, 1.0);
                  final gepeng = _a.value < .45 ? .12 * dekatDasar : 0.0;
                  return Transform.translate(
                    offset: Offset(0, -260 * (1 - v)),
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(1 + gepeng, 1 - gepeng, 1),
                      child: child,
                    ),
                  );
                },
                child: SvgPicture.asset('assets/vokas_ikon.svg', width: 112),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: _nama,
                child: ScaleTransition(
                  scale: Tween(begin: .7, end: 1.0).animate(_nama),
                  child: Text('VoKas',
                      style: GoogleFonts.poppins(
                          fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -.5)),
                ),
              ),
              FadeTransition(
                opacity: _tagline,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, .5), end: Offset.zero).animate(_tagline),
                  child: Text('Catat usaha cukup lewat suara', style: GoogleFonts.poppins(fontSize: 14, color: Warna.khaki)),
                ),
              ),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: FadeTransition(opacity: _tagline, child: const PoweredBy(terang: true)),
          ),
        ]),
      );
}
