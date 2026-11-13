import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';
import 'beranda.dart';

class TabRaporKur extends StatefulWidget {
  const TabRaporKur({super.key, required this.onDataBerubah});
  final VoidCallback onDataBerubah;

  @override
  State<TabRaporKur> createState() => _TabRaporKurState();
}

class _TabRaporKurState extends State<TabRaporKur> {
  late final Future<Map<String, dynamic>> _data = Api.raporKur(Sesi.pedagangId!);
  bool _mengisi = false;

  Future<void> _isiContoh() async {
    setState(() => _mengisi = true);
    try {
      await Api.isiDataContoh(Sesi.pedagangId!);
      widget.onDataBerubah();
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
    } finally {
      if (mounted) setState(() => _mengisi = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _data,
        builder: (context, snap) {
          final judul = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('90 hari pencatatan', style: TextStyle(color: Warna.redup, fontSize: 13)),
            Text('Rapor Kesiapan KUR', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
          ]);
          if (snap.hasError) {
            return ListView(padding: paddingTab, children: [judul, Text(pesanGalat(snap.error!))]);
          }
          if (!snap.hasData) {
            return ListView(padding: paddingTab, children: [judul, const SizedBox(height: 60), const Center(child: CircularProgressIndicator())]);
          }
          final r = snap.data!;
          final skor = (r['skor'] as num).toInt();
          final siap = r['siap'] == true;
          final kriteria = ((r['kriteria'] as List?) ?? []).cast<Map<String, dynamic>>();
          if ((r['hariTercatat'] as num? ?? 0) == 0) {
            return ListView(padding: paddingTab, children: [
              judul,
              Kosong(
                ikon: Icons.verified_outlined,
                judul: 'Rapor belum bisa dihitung',
                isi: 'Rapor dihitung dari catatan 90 hari: konsistensi, porsi QRIS, rekening terpisah, '
                    'margin laba, dan tren omzet. Mulai catat setiap hari, atau isi data contoh untuk melihat contohnya.',
                tombol: _mengisi ? 'Mengisi...' : 'Isi data contoh 90 hari',
                onTombol: _mengisi ? null : _isiContoh,
              ),
            ]);
          }
          return ListView(padding: paddingTab, children: [
            judul,
            Kartu(
              warna: Warna.khaki,
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                SizedBox(width: 116, height: 116, child: CustomPaint(painter: _Gauge(skor / 100, siap), child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$skor', style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w700)),
                    const Text('dari 100', style: TextStyle(fontSize: 11, color: Warna.redup)),
                  ]),
                ))),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Skor kesiapan', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: siap ? Warna.oliveTua : Warna.matahari, borderRadius: BorderRadius.circular(99)),
                      child: Text('${r['status']}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: siap ? Colors.white : Warna.tinta)),
                    ),
                    const SizedBox(height: 8),
                    Text('${r['hariTercatat']} dari ${r['hariTotal']} hari tercatat',
                        style: const TextStyle(fontSize: 12, color: Warna.oliveTua)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Kartu(
              child: Column(children: [
                for (final k in kriteria) _BarisKriteria(k),
              ]),
            ),
            const SizedBox(height: 12),
            const Text(
              'Rapor ini alat bantu merapikan catatan usaha, bukan keputusan kredit. Persetujuan KUR tetap ditentukan BRI.',
              style: TextStyle(fontSize: 12, color: Warna.redup, height: 1.5),
            ),
          ]);
        },
      );
}

class _BarisKriteria extends StatelessWidget {
  const _BarisKriteria(this.k);
  final Map<String, dynamic> k;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${k['nama']}', style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${k['poin']}/${k['bobot']}', style: const TextStyle(fontWeight: FontWeight.w600, color: Warna.oliveTua)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ((k['nilai'] as num).toDouble()).clamp(0, 1),
              minHeight: 8,
              backgroundColor: Warna.latar,
              color: Warna.olive,
            ),
          ),
          const SizedBox(height: 4),
          Text('${k['keterangan']}', style: const TextStyle(fontSize: 12, color: Warna.redup)),
        ]),
      );
}

class _Gauge extends CustomPainter {
  _Gauge(this.nilai, this.siap);
  final double nilai;
  final bool siap;

  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(7, 7, s.width - 14, s.height - 14);
    final dasar = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    final isi = Paint()
      ..color = siap ? Warna.oliveTua : Warna.matahari
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    c.drawArc(r, 0, 2 * pi, false, dasar);
    c.drawArc(r, -pi / 2, 2 * pi * nilai.clamp(0, 1), false, isi);
  }

  @override
  bool shouldRepaint(_Gauge o) => o.nilai != nilai || o.siap != siap;
}
