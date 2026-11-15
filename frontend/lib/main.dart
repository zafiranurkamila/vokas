import 'package:flutter/material.dart';

import 'api.dart';
import 'layar/beranda.dart';
import 'layar/notifikasi.dart';
import 'notif.dart';
import 'layar/intro.dart';
import 'layar/masuk.dart';
import 'layar/sambung_bri.dart';
import 'layar/splash.dart';
import 'sesi.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Sesi.muat();
  Api.bangunkan(); // tidak ditunggu: server mulai menyala selama splash dan intro tampil
  PusatNotif.i.bukaDaftar = () =>
      kunciNavigator.currentState?.push(MaterialPageRoute(builder: (_) => const LayarNotifikasi()));
  runApp(const VokasApp());
}

class VokasApp extends StatelessWidget {
  const VokasApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VoKas',
        navigatorKey: kunciNavigator,
        debugShowCheckedModeBanner: false,
        theme: temaVokas(),
        home: const LayarSplash(),
      );
}

/// Urutan: splash -> intro 3 langkah -> masuk/daftar -> sambung rekening BRI -> beranda.
Widget layarBerikutnya() {
  if (!Sesi.sudahIntro) return const LayarIntro();
  if (Sesi.pedagangId == null) return const LayarMasuk();
  if (!Sesi.sudahPilihBri) return const LayarSambungBri();
  return const Beranda();
}

void lanjut(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => layarBerikutnya(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ),
    (_) => false,
  );
}
