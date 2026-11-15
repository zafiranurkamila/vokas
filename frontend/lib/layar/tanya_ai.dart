import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';

/// Tanya AI: asisten yang menjawab dari data transaksi pedagang sendiri.
class LayarTanyaAi extends StatefulWidget {
  const LayarTanyaAi({super.key});

  @override
  State<LayarTanyaAi> createState() => _LayarTanyaAiState();
}

class _Pesan {
  _Pesan(this.dariSaya, this.teks, {this.galat = false});
  final bool dariSaya;
  final String teks;
  final bool galat;
}

const _saran = [
  'Untung minggu ini berapa?',
  'Barang apa yang paling laku?',
  'Hari apa jualan paling ramai?',
  'Gimana biar skor KUR naik?',
  'Pengeluaran terbesar bulan ini apa?',
];

class _LayarTanyaAiState extends State<LayarTanyaAi> {
  final _teks = TextEditingController();
  final _gulir = ScrollController();
  final List<_Pesan> _pesan = [];
  bool _menunggu = false;
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muatRiwayat();
  }

  /// Percakapan sebelumnya diambil dari server, jadi tidak hilang saat layar ditutup.
  Future<void> _muatRiwayat() async {
    try {
      final r = await Api.riwayatAi(Sesi.pedagangId!, 'TANYA');
      if (!mounted) return;
      setState(() {
        for (final e in r.cast<Map<String, dynamic>>()) {
          _pesan.add(_Pesan(true, '${e['masukan'] ?? ''}'));
          final j = e['jawaban'] as String?;
          _pesan.add(j != null ? _Pesan(false, j) : _Pesan(false, (e['galat'] as String?) ?? 'AI belum menjawab.', galat: true));
        }
      });
      _keBawah();
    } catch (_) {
      // riwayat gagal dimuat: tetap bisa bertanya seperti biasa
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _hapusRiwayat() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus riwayat?'),
        content: const Text('Semua percakapan Tanya AI akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ya != true) return;
    try {
      await Api.hapusRiwayatAi(Sesi.pedagangId!, 'TANYA');
      if (mounted) setState(_pesan.clear);
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e));
    }
  }

  @override
  void dispose() {
    _teks.dispose();
    _gulir.dispose();
    super.dispose();
  }

  Future<void> _kirim([String? isi]) async {
    final t = (isi ?? _teks.text).trim();
    if (t.isEmpty || _menunggu) return;
    _teks.clear();
    setState(() {
      _pesan.add(_Pesan(true, t));
      _menunggu = true;
    });
    _keBawah();
    try {
      final r = await Api.tanyaAi(Sesi.pedagangId!, t);
      final jawab = r['teks'] as String?;
      setState(() => _pesan.add(jawab != null
          ? _Pesan(false, jawab)
          : _Pesan(false, (r['galat'] as String?) ?? 'AI belum bisa menjawab, coba lagi.', galat: true)));
    } catch (e) {
      setState(() => _pesan.add(_Pesan(false, pesanGalat(e), galat: true)));
    } finally {
      if (mounted) setState(() => _menunggu = false);
      _keBawah();
    }
  }

  void _keBawah() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_gulir.hasClients) {
          _gulir.animateTo(_gulir.position.maxScrollExtent + 120,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, color: Warna.olive, size: 20),
            SizedBox(width: 8),
            Text('Tanya AI'),
          ]),
          actions: [
            if (_pesan.isNotEmpty && !_menunggu)
              IconButton(
                tooltip: 'Hapus riwayat',
                onPressed: _hapusRiwayat,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              Expanded(
                child: ListView(
                  controller: _gulir,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (_memuat)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                      )
                    else if (_pesan.isEmpty)
                      _sambutan(),
                    for (final p in _pesan) _Gelembung(p),
                    if (_menunggu) const _Mengetik(),
                  ],
                ),
              ),
              _kolomKetik(),
            ]),
          ),
        ),
      );

  Widget _sambutan() => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Warna.khaki, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.auto_awesome_rounded, color: Warna.oliveTua),
          ),
          const SizedBox(height: 14),
          Text('Tanya apa saja soal usahamu', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('AI menjawab dari catatan transaksimu sendiri: omzet, laba, barang laku, dan Rapor KUR.',
              style: TextStyle(color: Warna.redup, height: 1.5)),
          const SizedBox(height: 18),
          const Text('Coba tanya:', style: TextStyle(fontSize: 12.5, color: Warna.redup)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _saran)
              ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 13)),
                backgroundColor: Warna.kartu,
                side: const BorderSide(color: Warna.garis),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () => _kirim(s),
              ),
          ]),
        ]),
      );

  Widget _kolomKetik() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: const BoxDecoration(color: Warna.latar, border: Border(top: BorderSide(color: Warna.garis))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _teks,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _kirim(),
                decoration: const InputDecoration(
                    hintText: 'Tulis pertanyaan...', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _menunggu ? null : _kirim,
              style: IconButton.styleFrom(backgroundColor: Warna.oliveTua, fixedSize: const Size(48, 48)),
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ]),
        ),
      );
}

class _Gelembung extends StatelessWidget {
  const _Gelembung(this.p);
  final _Pesan p;

  @override
  Widget build(BuildContext context) => Align(
        alignment: p.dariSaya ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: p.dariSaya ? Warna.oliveTua : (p.galat ? Warna.matahari.withOpacity(.22) : Warna.kartu),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(p.dariSaya ? 18 : 4),
              bottomRight: Radius.circular(p.dariSaya ? 4 : 18),
            ),
          ),
          child: Text(p.teks,
              style: TextStyle(color: p.dariSaya ? Colors.white : Warna.tinta, height: 1.5, fontSize: 14)),
        ),
      );
}

class _Mengetik extends StatefulWidget {
  const _Mengetik();

  @override
  State<_Mengetik> createState() => _MengetikState();
}

class _MengetikState extends State<_Mengetik> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: Warna.kartu, borderRadius: BorderRadius.circular(18)),
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Warna.olive.withOpacity(((_a.value * 3 - i) % 3) < 1 ? 1 : .3),
                  ),
                ),
            ]),
          ),
        ),
      );
}
