import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';
import 'beranda.dart';
import '../widget/kartu_ekspor.dart';

class TabLaporan extends StatefulWidget {
  const TabLaporan({super.key, required this.onDataBerubah});
  final VoidCallback onDataBerubah;

  @override
  State<TabLaporan> createState() => _TabLaporanState();
}

class _TabLaporanState extends State<TabLaporan> {
  int _hari = 7;
  bool _mengisi = false;
  late Future<Map<String, dynamic>> _data = _muat();

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

  Future<Map<String, dynamic>> _muat() {
    final sampai = DateTime.now();
    return Api.laporan(Sesi.pedagangId!,
        dari: tglIso(sampai.subtract(Duration(days: _hari - 1))), sampai: tglIso(sampai));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _data,
        builder: (context, snap) {
          final judul = Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              Expanded(child: Text('Laporan', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700))),
              SegmentedButton<int>(
                segments: const [ButtonSegment(value: 7, label: Text('7 hari')), ButtonSegment(value: 30, label: Text('30 hari'))],
                selected: {_hari},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _hari = s.first;
                  _data = _muat();
                }),
              ),
            ]),
          );
          if (snap.hasError) {
            return ListView(padding: paddingTab, children: [judul, Text(pesanGalat(snap.error!))]);
          }
          if (!snap.hasData) {
            return ListView(padding: paddingTab, children: [judul, const SizedBox(height: 60), const Center(child: CircularProgressIndicator())]);
          }
          final l = snap.data!;
          final harian = ((l['harian'] as List?) ?? []).cast<Map<String, dynamic>>();
          final terlaris = ((l['terlaris'] as List?) ?? []).cast<Map<String, dynamic>>();
          final omzet = (l['omzet'] as num?) ?? 0;
          final qris = (l['omzetQris'] as num?) ?? 0;
          if ((l['jumlahTransaksi'] as num? ?? 0) == 0) {
            return ListView(padding: paddingTab, children: [
              judul,
              Kosong(
                ikon: Icons.bar_chart_rounded,
                judul: 'Laporan masih kosong',
                isi: 'Belum ada transaksi dalam $_hari hari terakhir. Mulai catat lewat tombol mic, '
                    'atau isi data contoh 90 hari untuk melihat laporan lengkap.',
                tombol: _mengisi ? 'Mengisi...' : 'Isi data contoh 90 hari',
                onTombol: _mengisi ? null : _isiContoh,
              ),
            ]);
          }
          return ListView(padding: paddingTab, children: [
            judul,
            Row(children: [
              _Ringkas('Omzet', rp(omzet), Warna.oliveTua),
              const SizedBox(width: 10),
              _Ringkas('Pengeluaran', rp((l['pengeluaran'] as num?) ?? 0), Warna.merah),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _Ringkas('Laba', rp((l['laba'] as num?) ?? 0), Warna.olive),
              const SizedBox(width: 10),
              _Ringkas('Porsi QRIS', omzet > 0 ? '${(100 * qris / omzet).round()}%' : '0%', Warna.qris),
            ]),
            const SizedBox(height: 20),
            Text('Masuk vs keluar per hari', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Kartu(child: harian.isEmpty ? const Text('Belum ada data.', style: TextStyle(color: Warna.redup)) : _Grafik(harian)),
            const SizedBox(height: 20),
            Text('Paling laku', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Kartu(
              child: terlaris.isEmpty
                  ? const Text('Belum ada penjualan barang.', style: TextStyle(color: Warna.redup))
                  : Column(children: [
                      for (final t in terlaris) _BarisTerlaris(t, (terlaris.first['total'] as num).toDouble()),
                    ]),
            ),
            const SizedBox(height: 20),
            Text('Unduh & kirim laporan', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            KartuEkspor(
              dari: tglIso(DateTime.now().subtract(Duration(days: _hari - 1))),
              sampai: tglIso(DateTime.now()),
              label: '$_hari hari terakhir',
            ),
          ]);
        },
      );
}

class _Ringkas extends StatelessWidget {
  const _Ringkas(this.label, this.nilai, this.warna);
  final String label, nilai;
  final Color warna;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Kartu(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Warna.redup)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(nilai, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: warna)),
            ),
          ]),
        ),
      );
}

class _Grafik extends StatelessWidget {
  const _Grafik(this.harian);
  final List<Map<String, dynamic>> harian;

  @override
  Widget build(BuildContext context) {
    final maks = harian.fold<double>(1, (m, h) => max(m, max((h['masuk'] as num).toDouble(), (h['keluar'] as num).toDouble())));
    final data = harian.length > 14 ? harian.sublist(harian.length - 14) : harian;
    return Column(children: [
      SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final h in data)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                    _Batang((h['masuk'] as num) / maks, Warna.olive),
                    const SizedBox(width: 2),
                    _Batang((h['keluar'] as num) / maks, Warna.merah.withOpacity(.6)),
                  ]),
                  const SizedBox(height: 4),
                  Text((h['tanggal'] as String).substring(8), style: const TextStyle(fontSize: 10, color: Warna.redup)),
                ]),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Legenda(Warna.olive, 'Masuk'),
        SizedBox(width: 16),
        _Legenda(Warna.merah, 'Keluar'),
      ]),
    ]);
  }
}

class _Batang extends StatelessWidget {
  const _Batang(this.rasio, this.warna);
  final num rasio;
  final Color warna;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: max(2, 110 * rasio.toDouble()),
        decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(4)),
      );
}

class _Legenda extends StatelessWidget {
  const _Legenda(this.warna, this.label);
  final Color warna;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Warna.redup)),
      ]);
}

class _BarisTerlaris extends StatelessWidget {
  const _BarisTerlaris(this.t, this.maks);
  final Map<String, dynamic> t;
  final double maks;

  @override
  Widget build(BuildContext context) {
    final total = (t['total'] as num).toDouble();
    final jumlah = (t['jumlah'] as num?) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${t['nama']}', style: const TextStyle(fontWeight: FontWeight.w600))),
          if (jumlah > 0) Text('$jumlah  ·  ', style: const TextStyle(fontSize: 12, color: Warna.redup)),
          Text(rp(total), style: const TextStyle(fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              value: maks > 0 ? total / maks : 0, minHeight: 8, backgroundColor: Warna.latar, color: Warna.olive),
        ),
      ]),
    );
  }
}
