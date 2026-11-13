import 'package:flutter/material.dart';

import '../notif.dart';
import '../sesi.dart';
import '../tema.dart';

class LayarNotifikasi extends StatefulWidget {
  const LayarNotifikasi({super.key});

  @override
  State<LayarNotifikasi> createState() => _LayarNotifikasiState();
}

class _LayarNotifikasiState extends State<LayarNotifikasi> {
  final _p = PusatNotif.i;
  bool _mengirim = false;

  @override
  void initState() {
    super.initState();
    _p.addListener(_ubah);
  }

  @override
  void dispose() {
    _p.removeListener(_ubah);
    _p.tandaiSemuaDibaca();
    super.dispose();
  }

  void _ubah() => setState(() {});

  Future<void> _kirimContoh() async {
    setState(() => _mengirim = true);
    await _p.kirimQrisContoh();
    if (mounted) setState(() => _mengirim = false);
  }

  static String _waktu(DateTime w) {
    final beda = DateTime.now().difference(w);
    if (beda.inMinutes < 1) return 'Baru saja';
    if (beda.inHours < 1) return '${beda.inMinutes} menit lalu';
    if (beda.inDays < 1) return '${beda.inHours} jam lalu';
    return '${w.day}/${w.month} ${w.hour.toString().padLeft(2, '0')}.${w.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final daftar = _p.daftar;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (daftar.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'baca' ? _p.tandaiSemuaDibaca() : _p.hapusSemua(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'baca', child: Text('Tandai semua dibaca')),
                PopupMenuItem(value: 'hapus', child: Text('Hapus semua')),
              ],
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Warna.khaki.withOpacity(.5), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Mode demo', style: TextStyle(fontWeight: FontWeight.w600, color: Warna.oliveTua)),
                const SizedBox(height: 4),
                Text(
                  Sesi.briTersambung == true
                      ? 'Rekening BRI tersambung (simulasi): QRIS contoh masuk sendiri tiap 1-2 menit. '
                          'Tekan tombol untuk mengirim sekarang.'
                      : 'Sambungkan rekening BRI di Profil supaya QRIS contoh masuk otomatis, atau kirim satu sekarang.',
                  style: const TextStyle(fontSize: 12.5, color: Warna.oliveTua, height: 1.45),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _mengirim ? null : _kirimContoh,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: Text(_mengirim ? 'Mengirim...' : 'Kirim contoh QRIS masuk'),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            if (daftar.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Column(children: [
                  Icon(Icons.notifications_none_rounded, size: 48, color: Warna.redup),
                  SizedBox(height: 10),
                  Text('Belum ada notifikasi', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Pembayaran QRIS dan transfer masuk akan muncul di sini.',
                      textAlign: TextAlign.center, style: TextStyle(color: Warna.redup, fontSize: 13)),
                ]),
              )
            else
              Kartu(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (var k = 0; k < daftar.length; k++) ...[
                    if (k > 0) const Divider(height: 1, indent: 68, endIndent: 16, color: Warna.garis),
                    Container(
                      color: daftar[k].dibaca ? null : Warna.khaki.withOpacity(.18),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        IkonNotif(daftar[k].jenis),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text(daftar[k].judul, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              if (!daftar[k].dibaca)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Warna.merah, shape: BoxShape.circle),
                                ),
                            ]),
                            const SizedBox(height: 2),
                            Text(daftar[k].isi, style: const TextStyle(fontSize: 13, color: Warna.redup, height: 1.4)),
                            const SizedBox(height: 4),
                            Text(_waktu(daftar[k].waktu), style: const TextStyle(fontSize: 11.5, color: Warna.redup)),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            const SizedBox(height: 16),
            const Text(
              'Versi resmi: notifikasi dikirim server lewat Firebase Cloud Messaging saat mutasi BRI masuk, '
              'jadi tetap muncul walau aplikasi ditutup.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Warna.redup, height: 1.45),
            ),
          ]),
        ),
      ),
    );
  }
}
