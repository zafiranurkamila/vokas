import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';
import 'beranda.dart';

/// Kalkulator cicilan KUR: membandingkan cicilan dengan laba rata-rata bulanan dari catatan pedagang.
/// Bunga mengikuti suku bunga KUR Mikro yang umum (6% per tahun), dihitung anuitas. Hanya perkiraan.
class LayarHitungKur extends StatefulWidget {
  const LayarHitungKur({super.key});

  @override
  State<LayarHitungKur> createState() => _LayarHitungKurState();
}

class _LayarHitungKurState extends State<LayarHitungKur> {
  static const _bungaTahunan = 0.06;
  double _pinjaman = 10000000;
  int _tenor = 24;
  num? _labaBulanan; // laba 30 hari terakhir dari catatan

  @override
  void initState() {
    super.initState();
    final s = DateTime.now();
    Api.laporan(Sesi.pedagangId!, dari: tglIso(s.subtract(const Duration(days: 29))), sampai: tglIso(s)).then((l) {
      if (mounted) setState(() => _labaBulanan = (l['laba'] as num?) ?? 0);
    }).catchError((_) {
      if (mounted) setState(() => _labaBulanan = 0);
    });
  }

  double get _cicilan {
    final r = _bungaTahunan / 12;
    return _pinjaman * r / (1 - pow(1 + r, -_tenor));
  }

  @override
  Widget build(BuildContext context) {
    final cicilan = _cicilan;
    final total = cicilan * _tenor;
    final laba = _labaBulanan;
    final rasio = laba == null || laba <= 0 ? null : cicilan / laba;
    final (status, warna, saran) = switch (rasio) {
      null => ('Belum bisa dinilai', Warna.redup, 'Catat transaksi dulu supaya laba bulanan terlihat.'),
      < .3 => ('Aman', Warna.olive, 'Cicilan di bawah 30% laba bulanan. Masih ada ruang untuk kebutuhan lain.'),
      < .5 => ('Perlu hati-hati', const Color(0xFFB8860B), 'Cicilan 30-50% laba. Pertimbangkan tenor lebih panjang atau pinjaman lebih kecil.'),
      _ => ('Terlalu berat', Warna.merah, 'Cicilan lebih dari separuh laba. Kecilkan pinjaman atau panjangkan tenor.'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Hitung KUR')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
            Kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('Jumlah pinjaman', style: TextStyle(fontWeight: FontWeight.w600))),
                  Text(rp(_pinjaman), style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
                Slider(
                  value: _pinjaman,
                  min: 5000000,
                  max: 100000000,
                  divisions: 19,
                  activeColor: Warna.oliveTua,
                  onChanged: (v) => setState(() => _pinjaman = v),
                ),
                const Text('KUR Mikro: sampai Rp100 juta', style: TextStyle(fontSize: 12, color: Warna.redup)),
                const SizedBox(height: 16),
                const Text('Lama cicilan', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 12, label: Text('12 bln')),
                    ButtonSegment(value: 24, label: Text('24 bln')),
                    ButtonSegment(value: 36, label: Text('36 bln')),
                  ],
                  selected: {_tenor},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _tenor = s.first),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Kartu(
              warna: Warna.oliveTua,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Perkiraan cicilan per bulan', style: TextStyle(color: Warna.khaki, fontSize: 13)),
                Text(rp(cicilan), style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Total dibayar ${rp(total)} · bunga 6%/tahun',
                    style: const TextStyle(color: Warna.khaki, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(height: 14),
            Kartu(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dibandingkan dengan usahamu', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(children: [
                  const Expanded(child: Text('Laba 30 hari terakhir', style: TextStyle(color: Warna.redup))),
                  Text(laba == null ? '...' : rp(laba), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Expanded(child: Text('Cicilan / laba', style: TextStyle(color: Warna.redup))),
                  Text(rasio == null ? '-' : '${(rasio * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                if (rasio != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: rasio.clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: Warna.latar, color: warna),
                  ),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(rasio == null ? Icons.info_outline_rounded : Icons.circle, size: 12, color: warna),
                  const SizedBox(width: 8),
                  Text(status, style: TextStyle(fontWeight: FontWeight.w700, color: warna)),
                ]),
                const SizedBox(height: 4),
                Text(saran, style: const TextStyle(fontSize: 13, color: Warna.redup, height: 1.45)),
              ]),
            ),
            const SizedBox(height: 16),
            const Text(
              'Perkiraan saja, bukan penawaran dari BRI. Bunga, plafon, dan persetujuan KUR mengikuti ketentuan BRI '
              'dan pemerintah yang berlaku saat pengajuan.',
              style: TextStyle(fontSize: 11.5, color: Warna.redup, height: 1.5),
            ),
          ]),
        ),
      ),
    );
  }
}
