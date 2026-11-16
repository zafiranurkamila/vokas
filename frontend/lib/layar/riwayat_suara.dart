import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';

/// Riwayat catatan: voice note bisa diputar ulang, dengan teks transkrip dan hasil catatannya di bawah.
class LayarRiwayatSuara extends StatefulWidget {
  const LayarRiwayatSuara({super.key});

  @override
  State<LayarRiwayatSuara> createState() => _LayarRiwayatSuaraState();
}

class _LayarRiwayatSuaraState extends State<LayarRiwayatSuara> {
  late Future<List<Map<String, dynamic>>> _data = _muat();
  final _pemutar = AudioPlayer();
  final Map<String, Uint8List> _cache = {};
  String? _diputar;
  String? _memuat;
  String _saring = 'SEMUA';

  Future<List<Map<String, dynamic>>> _muat() async =>
      (await Api.riwayatAi(Sesi.pedagangId!, 'CATAT')).cast<Map<String, dynamic>>().reversed.toList();

  @override
  void initState() {
    super.initState();
    _pemutar.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _diputar = null);
    });
  }

  @override
  void dispose() {
    _pemutar.dispose();
    super.dispose();
  }

  Future<void> _putar(String id) async {
    if (_diputar == id) {
      await _pemutar.stop();
      setState(() => _diputar = null);
      return;
    }
    setState(() => _memuat = id);
    try {
      final isi = _cache[id] ?? await Api.audioRiwayat(Sesi.pedagangId!, id);
      _cache[id] = isi;
      await _pemutar.stop();
      await _pemutar.play(BytesSource(isi));
      if (mounted) setState(() => _diputar = id);
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
    } finally {
      if (mounted) setState(() => _memuat = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Riwayat Catatan Suara')),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() => _data = _muat());
            await _data;
          },
          child: FutureBuilder(
            future: _data,
            builder: (context, snap) {
              if (snap.hasError) {
                return ListView(padding: const EdgeInsets.all(24), children: [
                  Text(pesanGalat(snap.error!), textAlign: TextAlign.center),
                  TextButton(onPressed: () => setState(() => _data = _muat()), child: const Text('Coba lagi')),
                ]);
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final semua = snap.data!;
              final daftar = semua.where((e) => _saring == 'SEMUA' || e['sumber'] == _saring).toList();
              return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                Wrap(spacing: 8, children: [
                  for (final (k, l) in [('SEMUA', 'Semua'), ('SUARA', 'Suara'), ('TEKS', 'Ketik'), ('FOTO', 'Foto nota')])
                    ChoiceChip(
                      label: Text(l),
                      selected: _saring == k,
                      onSelected: (_) => setState(() => _saring = k),
                      selectedColor: Warna.khaki,
                    ),
                ]),
                const SizedBox(height: 12),
                if (daftar.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Text('Belum ada catatan. Tekan mic di beranda lalu sebutkan jualanmu.',
                        textAlign: TextAlign.center, style: TextStyle(color: Warna.redup)),
                  ),
                for (final e in daftar) ...[
                  _KartuRiwayat(
                    e,
                    diputar: _diputar == e['id'],
                    memuat: _memuat == e['id'],
                    onPutar: () => _putar('${e['id']}'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (semua.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Rekaman suara disimpan untuk 30 catatan terakhir.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Warna.redup)),
                  ),
              ]);
            },
          ),
        ),
      );
}

class _KartuRiwayat extends StatelessWidget {
  const _KartuRiwayat(this.e, {required this.diputar, required this.memuat, required this.onPutar});
  final Map<String, dynamic> e;
  final bool diputar, memuat;
  final VoidCallback onPutar;

  @override
  Widget build(BuildContext context) {
    final sumber = '${e['sumber']}';
    final waktu = DateTime.tryParse('${e['dibuat']}')?.toLocal();
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final jam = waktu == null
        ? ''
        : '${waktu.day} ${bulan[waktu.month - 1]}, ${waktu.hour.toString().padLeft(2, '0')}:${waktu.minute.toString().padLeft(2, '0')}';
    List<Map<String, dynamic>> item = [];
    try {
      final h = jsonDecode('${e['jawaban']}') as Map<String, dynamic>;
      item = ((h['tersimpan'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    final gagal = e['galat'] != null;
    final adaAudio = e['adaAudio'] == true;
    return Kartu(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (adaAudio)
            InkWell(
              onTap: onPutar,
              customBorder: const CircleBorder(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: diputar ? Warna.merah : Warna.oliveTua, shape: BoxShape.circle),
                child: memuat
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(diputar ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white),
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Warna.khaki.withOpacity(.7), shape: BoxShape.circle),
              child: Icon(
                  switch (sumber) { 'SUARA' => Icons.mic_rounded, 'FOTO' => Icons.receipt_long_rounded, _ => Icons.edit_note_rounded },
                  color: Warna.oliveTua),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(switch (sumber) { 'SUARA' => 'Voice note', 'FOTO' => 'Foto nota', _ => 'Diketik' },
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(jam, style: const TextStyle(fontSize: 12, color: Warna.redup)),
            ]),
          ),
          if (diputar)
            const Row(children: [
              Icon(Icons.graphic_eq_rounded, color: Warna.olive, size: 20),
              SizedBox(width: 4),
              Text('Diputar', style: TextStyle(fontSize: 12, color: Warna.olive)),
            ]),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Warna.latar, borderRadius: BorderRadius.circular(12)),
          child: Text('"${e['masukan'] ?? '(tidak ada teks)'}"',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13.5, height: 1.4)),
        ),
        const SizedBox(height: 8),
        if (gagal)
          Text('${e['galat']}', style: const TextStyle(fontSize: 12.5, color: Warna.merah))
        else
          for (final t in item)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(t['jenis'] == 'MASUK' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    size: 14, color: t['jenis'] == 'MASUK' ? Warna.oliveTua : Warna.merah),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      '${t['namaItem']}${t['jumlah'] != null ? ' · ${t['jumlah']} ${t['satuan'] ?? ''}' : ''}',
                      style: const TextStyle(fontSize: 13)),
                ),
                Text(rp(t['total'] as num),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t['jenis'] == 'MASUK' ? Warna.oliveTua : Warna.merah)),
              ]),
            ),
      ]),
    );
  }
}
