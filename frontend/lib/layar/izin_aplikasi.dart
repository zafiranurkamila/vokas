import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../izin.dart';
import '../main.dart';
import '../sesi.dart';
import '../tema.dart';

/// Layar izin sebelum masuk beranda: menjelaskan untuk apa tiap izin, lalu memintanya satu per satu.
class LayarIzin extends StatefulWidget {
  const LayarIzin({super.key});

  @override
  State<LayarIzin> createState() => _LayarIzinState();
}

class _LayarIzinState extends State<LayarIzin> {
  final Map<String, bool?> _status = {'mic': null, 'notif': null, 'lokasi': null};
  bool _sibuk = false;

  Future<void> _minta(String jenis) async {
    setState(() => _sibuk = true);
    final ok = switch (jenis) {
      'mic' => await Izin.mintaMikrofon(),
      'notif' => await Izin.mintaNotifikasi(),
      _ => await Izin.mintaLokasi(),
    };
    if (mounted) setState(() {
      _status[jenis] = ok;
      _sibuk = false;
    });
  }

  Future<void> _semua() async {
    for (final j in ['mic', 'notif', 'lokasi']) {
      if (_status[j] != true) await _minta(j);
    }
    await _selesai();
  }

  Future<void> _selesai() async {
    await Sesi.selesaiIzin();
    if (mounted) lanjut(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Satu langkah lagi', style: GoogleFonts.poppins(fontSize: 23, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('VoKas butuh beberapa izin supaya bisa bekerja penuh. Kamu bisa mengubahnya kapan saja '
                      'di pengaturan HP.', style: TextStyle(color: Warna.redup, height: 1.5)),
                  const SizedBox(height: 22),
                  _Baris(
                    ikon: Icons.mic_rounded,
                    judul: 'Mikrofon',
                    isi: 'Untuk mencatat jualan lewat suara. Suara hanya direkam saat kamu menekan tombol mic.',
                    status: _status['mic'],
                    onIzinkan: _sibuk ? null : () => _minta('mic'),
                  ),
                  _Baris(
                    ikon: Icons.notifications_active_outlined,
                    judul: 'Notifikasi',
                    isi: kIsWeb
                        ? 'Notifikasi di luar aplikasi tersedia di aplikasi Android VoKas.'
                        : 'Supaya tahu saat uang QRIS atau transfer masuk, walau aplikasi sedang ditutup.',
                    status: kIsWeb ? false : _status['notif'],
                    tersedia: !kIsWeb,
                    onIzinkan: _sibuk || kIsWeb ? null : () => _minta('notif'),
                  ),
                  _Baris(
                    ikon: Icons.location_on_outlined,
                    judul: 'Lokasi usaha',
                    isi: 'Perkiraan lokasi warung dicantumkan di Rapor KUR. Hanya diambil sekali, tidak dilacak.',
                    status: _status['lokasi'],
                    onIzinkan: _sibuk ? null : () => _minta('lokasi'),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _sibuk ? null : _semua,
                    child: Text(_status.values.every((v) => v != null) ? 'Lanjut ke beranda' : 'Izinkan semua'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(onPressed: _sibuk ? null : _selesai, child: const Text('Nanti saja')),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _Baris extends StatelessWidget {
  const _Baris({
    required this.ikon,
    required this.judul,
    required this.isi,
    required this.status,
    required this.onIzinkan,
    this.tersedia = true,
  });

  final IconData ikon;
  final String judul, isi;
  final bool? status;
  final VoidCallback? onIzinkan;
  final bool tersedia;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Warna.kartu, borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Warna.khaki, borderRadius: BorderRadius.circular(12)),
            child: Icon(ikon, color: Warna.oliveTua),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(judul, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 2),
              Text(isi, style: const TextStyle(fontSize: 12.5, color: Warna.redup, height: 1.45)),
            ]),
          ),
          const SizedBox(width: 8),
          if (!tersedia)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Android', style: TextStyle(fontSize: 11.5, color: Warna.redup)))
          else if (status == true)
            const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.check_circle_rounded, color: Warna.olive))
          else if (status == false)
            TextButton(onPressed: Izin.bukaPengaturan, child: const Text('Pengaturan'))
          else
            TextButton(onPressed: onIzinkan, child: const Text('Izinkan')),
        ]),
      );
}
