import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'izin.dart';
import 'sesi.dart';
import 'tema.dart';

/// Kunci navigator global, supaya banner bisa tampil di layar mana pun.
final kunciNavigator = GlobalKey<NavigatorState>();

class Notif {
  Notif({required this.id, required this.judul, required this.isi, required this.waktu, this.jenis = 'qris', this.dibaca = false});

  final String id;
  final String judul;
  final String isi;
  final DateTime waktu;
  final String jenis; // qris | transfer | info
  bool dibaca;

  Map<String, dynamic> keJson() =>
      {'id': id, 'judul': judul, 'isi': isi, 'waktu': waktu.toIso8601String(), 'jenis': jenis, 'dibaca': dibaca};

  static Notif dariJson(Map<String, dynamic> j) => Notif(
        id: j['id'] as String,
        judul: j['judul'] as String,
        isi: j['isi'] as String,
        waktu: DateTime.parse(j['waktu'] as String),
        jenis: (j['jenis'] as String?) ?? 'info',
        dibaca: j['dibaca'] == true,
      );
}

/// Pusat notifikasi dalam aplikasi: simpan riwayat, bunyi "ceting", banner, dan simulasi QRIS masuk.
/// Versi resmi: notifikasi dikirim server lewat Firebase Cloud Messaging (FCM) saat mutasi BRI masuk,
/// jadi tetap muncul walau aplikasi ditutup.
class PusatNotif extends ChangeNotifier {
  PusatNotif._();
  static final i = PusatNotif._();

  static const _maks = 50;
  final _suara = AudioPlayer();
  final List<Notif> daftar = [];
  Timer? _simulasi;
  OverlayEntry? _banner;
  Timer? _tutupBanner;

  /// false saat aplikasi di latar belakang: notifikasi dikirim ke panel HP.
  bool diDepan = true;

  /// Dipanggil setelah ada transaksi baru supaya beranda memuat ulang.
  VoidCallback? onTransaksiBaru;

  String get _kunci => 'notif_${Sesi.pedagangId ?? '-'}';

  int get belumDibaca => daftar.where((n) => !n.dibaca).length;

  Future<void> muat() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kunci);
    daftar
      ..clear()
      ..addAll(s == null ? [] : (jsonDecode(s) as List).map((e) => Notif.dariJson(e as Map<String, dynamic>)));
    notifyListeners();
  }

  Future<void> _simpan() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kunci, jsonEncode(daftar.map((n) => n.keJson()).toList()));
  }

  Future<void> tambah(String judul, String isi, {String jenis = 'qris'}) async {
    final n = Notif(id: DateTime.now().microsecondsSinceEpoch.toString(), judul: judul, isi: isi, waktu: DateTime.now(), jenis: jenis);
    daftar.insert(0, n);
    if (daftar.length > _maks) daftar.removeRange(_maks, daftar.length);
    notifyListeners();
    await _simpan();
    if (diDepan) {
      _bunyi();
      _tampilkanBanner(n);
    } else {
      await Izin.tampilkan(judul, isi); // bunyi dan tampilan dari sistem Android
    }
  }

  Future<void> tandaiSemuaDibaca() async {
    for (final n in daftar) {
      n.dibaca = true;
    }
    notifyListeners();
    await _simpan();
  }

  Future<void> hapusSemua() async {
    daftar.clear();
    notifyListeners();
    await _simpan();
  }

  Future<void> _bunyi() async {
    try {
      await _suara.stop();
      await _suara.play(AssetSource('suara/masuk.wav'), volume: .9);
    } catch (_) {
      // browser bisa memblokir suara sebelum ada interaksi; notifikasi tetap tampil
    }
  }

  // ---------------- simulasi QRIS masuk ----------------

  /// Kirim satu pembayaran QRIS contoh: dicatat di backend lalu muncul notifikasi.
  Future<void> kirimQrisContoh([int? jumlah]) async {
    final id = Sesi.pedagangId;
    if (id == null) return;
    final r = Random();
    final nominal = jumlah ?? (3 + r.nextInt(10)) * 2500; // Rp7.500 - Rp30.000
    try {
      await Api.imporMutasi(id, [
        {'ref': 'DEMO-${DateTime.now().millisecondsSinceEpoch}', 'nominal': nominal, 'metode': 'QRIS', 'keterangan': 'Pembayaran QRIS'},
      ]);
      onTransaksiBaru?.call();
      await tambah('QRIS masuk ${rp(nominal)}', 'Pembayaran dari pembeli sudah tercatat otomatis sebagai penjualan.');
    } catch (e) {
      await tambah('Gagal mencatat QRIS', pesanGalat(e), jenis: 'info');
    }
  }

  /// Saat rekening BRI tersambung (simulasi), QRIS contoh masuk setiap 60-120 detik.
  void mulaiSimulasi() {
    _simulasi?.cancel();
    if (Sesi.briTersambung != true) return;
    void jadwal() {
      _simulasi = Timer(Duration(seconds: 60 + Random().nextInt(61)), () async {
        if (Sesi.briTersambung == true && Sesi.pedagangId != null) await kirimQrisContoh();
        jadwal();
      });
    }

    jadwal();
  }

  void hentikanSimulasi() => _simulasi?.cancel();

  // ---------------- banner ----------------

  void _tampilkanBanner(Notif n) {
    final overlay = kunciNavigator.currentState?.overlay;
    if (overlay == null) return;
    _tutupBanner?.cancel();
    _banner?.remove();
    _banner = OverlayEntry(builder: (_) => _Banner(n: n, onTutup: _hapusBanner));
    overlay.insert(_banner!);
    _tutupBanner = Timer(const Duration(seconds: 4), _hapusBanner);
  }

  void _hapusBanner() {
    _tutupBanner?.cancel();
    _banner?.remove();
    _banner = null;
  }

  /// Diisi oleh main.dart: membuka halaman notifikasi saat banner ditekan.
  void Function()? bukaDaftar;
}

class _Banner extends StatefulWidget {
  const _Banner({required this.n, required this.onTutup});
  final Notif n;
  final VoidCallback onTutup;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) _a.reverse();
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.of(context).padding.top + 10;
    return Positioned(
      top: atas,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1.6), end: Offset.zero)
            .animate(CurvedAnimation(parent: _a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Dismissible(
              key: ValueKey(widget.n.id),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onTutup(),
              child: Material(
                color: Colors.white,
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    widget.onTutup();
                    PusatNotif.i.bukaDaftar?.call();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      IkonNotif(widget.n.jenis),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Row(children: [
                            const Text('VoKas', style: TextStyle(fontSize: 11.5, color: Warna.redup)),
                            const Text('  ·  sekarang', style: TextStyle(fontSize: 11.5, color: Warna.redup)),
                          ]),
                          Text(widget.n.judul, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                          Text(widget.n.isi,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: Warna.redup)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IkonNotif extends StatelessWidget {
  const IkonNotif(this.jenis, {super.key});
  final String jenis;

  @override
  Widget build(BuildContext context) {
    final (ikon, warna) = switch (jenis) {
      'qris' => (Icons.qr_code_2_rounded, Warna.qris),
      'transfer' => (Icons.swap_horiz_rounded, Warna.oliveTua),
      _ => (Icons.notifications_none_rounded, Warna.olive),
    };
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: warna.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
      child: Icon(ikon, color: warna, size: 22),
    );
  }
}
