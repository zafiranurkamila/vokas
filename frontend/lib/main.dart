import 'package:flutter/material.dart';

import 'api.dart';
import 'layar/beranda.dart';
import 'layar/notifikasi.dart';
import 'notif.dart';
import 'izin.dart';
import 'layar/intro.dart';
import 'layar/izin_aplikasi.dart';
import 'layar/masuk.dart';
import 'layar/sambung_bri.dart';
import 'layar/splash.dart';
import 'sesi.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Sesi.muat();
  Api.bangunkan(); // tidak ditunggu: server mulai menyala selama splash dan intro tampil
  await Izin.siapkan();
  Izin.onNotifDitekan = () => PusatNotif.i.bukaDaftar?.call();
  Api.onMenungguServer = _tampilMenunggu;
  PusatNotif.i.bukaDaftar = () =>
      kunciNavigator.currentState?.push(MaterialPageRoute(builder: (_) => const LayarNotifikasi()));
  runApp(const VokasApp());
}

class VokasApp extends StatefulWidget {
  const VokasApp({super.key});

  @override
  State<VokasApp> createState() => _VokasAppState();
}

class _VokasAppState extends State<VokasApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    PusatNotif.i.diDepan = state == AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VoKas',
        navigatorKey: kunciNavigator,
        scaffoldMessengerKey: kunciPesan,
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
  if (!Sesi.sudahIzin) return const LayarIzin();
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

/// Pemberitahuan global (dipakai saat menunggu server bangun, di layar mana pun).
final kunciPesan = GlobalKey<ScaffoldMessengerState>();

void _tampilMenunggu(bool menunggu) {
  final m = kunciPesan.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  if (!menunggu) return;
  m.showSnackBar(const SnackBar(
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.fromLTRB(16, 0, 16, 20),
    backgroundColor: Warna.tinta,
    duration: Duration(seconds: 180),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    content: Row(children: [
      SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Warna.matahari)),
      SizedBox(width: 14),
      Expanded(
        child: Text('Server sedang dinyalakan, tunggu sebentar (bisa sampai 2 menit)...',
            style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4)),
      ),
    ]),
  ));
}

