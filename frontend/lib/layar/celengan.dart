import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';

/// Celengan: sisihkan sebagian untung tiap hari untuk target (DP usaha, cicilan KUR, alat baru).
class LayarCelengan extends StatefulWidget {
  const LayarCelengan({super.key});

  @override
  State<LayarCelengan> createState() => _LayarCelenganState();
}

class _LayarCelenganState extends State<LayarCelengan> {
  late Future<Map<String, dynamic>> _data = Api.celengan(Sesi.pedagangId!);
  bool _sibuk = false;

  void _pakai(Map<String, dynamic> d) => setState(() => _data = Future.value(d));

  Future<void> _atur(Map<String, dynamic>? c) async {
    final nama = TextEditingController(text: c?['nama'] as String? ?? 'Cicilan KUR');
    final target = TextEditingController(text: c == null ? '' : '${c['target']}');
    var persen = (c?['persen'] as num?)?.toInt() ?? 10;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Warna.latar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => StatefulBuilder(
        builder: (c, setL) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Target celengan', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final n in ['Cicilan KUR', 'DP KUR', 'Gerobak baru', 'Modal Lebaran'])
                ActionChip(label: Text(n), onPressed: () => nama.text = n),
            ]),
            const SizedBox(height: 10),
            TextField(controller: nama, decoration: const InputDecoration(labelText: 'Untuk apa?')),
            const SizedBox(height: 10),
            TextField(
              controller: target,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target', prefixText: 'Rp ', hintText: '1500000'),
            ),
            const SizedBox(height: 14),
            Text('Sisihkan $persen% dari untung harian', style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: persen.toDouble(),
              min: 5,
              max: 50,
              divisions: 9,
              label: '$persen%',
              onChanged: (v) => setL(() => persen = v.round()),
            ),
            const SizedBox(height: 6),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simpan target')),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    final t = int.tryParse(target.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (t <= 0) {
      if (mounted) tampilPesan(context, 'Isi target dulu ya.', jenis: JenisPesan.info);
      return;
    }
    await _jalankan(() => Api.aturCelengan(Sesi.pedagangId!, nama.text.trim(), t, persen));
  }

  Future<void> _setor(int nominal, {String? catatan}) =>
      _jalankan(() => Api.setorCelengan(Sesi.pedagangId!, nominal, catatan: catatan), pesan: nominal > 0
          ? '${rp(nominal)} masuk celengan'
          : '${rp(-nominal)} diambil dari celengan');

  Future<void> _jalankan(Future<Map<String, dynamic>> Function() f, {String? pesan}) async {
    setState(() => _sibuk = true);
    try {
      _pakai(await f());
      if (pesan != null && mounted) tampilPesan(context, pesan, jenis: JenisPesan.berhasil);
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _nominalLain({required bool ambil}) async {
    final ctrl = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ambil ? 'Ambil dari celengan' : 'Setor jumlah lain'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: 'Rp '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text.replaceAll(RegExp(r'\D'), ''))),
            style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (n == null || n <= 0) return;
    await _setor(ambil ? -n : n);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Celengan Usaha')),
        body: FutureBuilder(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(padding: const EdgeInsets.all(24), children: [
                Text(pesanGalat(snap.error!), textAlign: TextAlign.center),
                TextButton(
                    onPressed: () => setState(() => _data = Api.celengan(Sesi.pedagangId!)), child: const Text('Coba lagi')),
              ]);
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final d = snap.data!;
            final c = d['celengan'] as Map<String, dynamic>?;
            if (c == null) return _kosong();
            final terkumpul = (d['terkumpul'] as num?) ?? 0;
            final target = (c['target'] as num?) ?? 1;
            final persen = (d['persenTercapai'] as num?) ?? 0;
            final saran = (d['saranHariIni'] as num?) ?? 0;
            final sudah = d['sudahSetorHariIni'] == true;
            final perkiraan = d['perkiraanHari'] as num?;
            final riwayat = ((d['riwayat'] as List?) ?? []).cast<Map<String, dynamic>>();
            return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Warna.oliveTua, borderRadius: BorderRadius.circular(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.savings_rounded, color: Warna.matahari),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${c['nama']}',
                          style: const TextStyle(color: Warna.khaki, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      onPressed: _sibuk ? null : () => _atur(c),
                      icon: const Icon(Icons.edit_rounded, color: Warna.khaki, size: 20),
                      tooltip: 'Ubah target',
                    ),
                  ]),
                  Text(rp(terkumpul), style: GoogleFonts.poppins(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                  Text('dari ${rp(target)}', style: const TextStyle(color: Warna.khaki)),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (persen / 100).clamp(0, 1).toDouble(),
                      minHeight: 12,
                      backgroundColor: Colors.white24,
                      color: Warna.matahari,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('$persen% tercapai', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (persen >= 100)
                      const Text('Target tercapai!', style: TextStyle(color: Warna.matahari, fontWeight: FontWeight.w600))
                    else if (perkiraan != null)
                      Text('±$perkiraan hari lagi', style: const TextStyle(color: Warna.khaki, fontSize: 12.5)),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              Kartu(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(sudah ? 'Hari ini sudah menyisihkan' : 'Sisihkan hari ini',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    saran > 0
                        ? 'Untung hari ini ${rp(d['untungHariIni'] as num)}. ${c['persen']}% nya = ${rp(saran)}.'
                        : 'Belum ada untung hari ini. Catat jualan dulu, nanti VoKas hitungkan berapa yang bisa disisihkan.',
                    style: const TextStyle(color: Warna.redup, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  if (saran > 0)
                    FilledButton.icon(
                      onPressed: _sibuk ? null : () => _setor(saran.toInt(), catatan: '${c['persen']}% untung hari ini'),
                      icon: const Icon(Icons.savings_outlined),
                      label: Text('Sisihkan ${rp(saran)}'),
                    ),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                          onPressed: _sibuk ? null : () => _nominalLain(ambil: false), child: const Text('Jumlah lain')),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: _sibuk || terkumpul <= 0 ? null : () => _nominalLain(ambil: true),
                        style: TextButton.styleFrom(foregroundColor: Warna.merah),
                        child: const Text('Ambil'),
                      ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
              const Text('Uangnya tetap di rekening atau dompetmu. VoKas mencatat dan mengingatkan supaya disiplin, '
                  'disarankan dipindah ke tabungan BRI terpisah (misal Simpedes).',
                  style: TextStyle(fontSize: 12, color: Warna.redup, height: 1.4)),
              if (riwayat.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Riwayat', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                for (final s in riwayat)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon((s['nominal'] as num) > 0 ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                        color: (s['nominal'] as num) > 0 ? Warna.olive : Warna.merah),
                    title: Text('${s['catatan'] ?? ''}'),
                    subtitle: Text(_tgl(s['dibuat'])),
                    trailing: Text('${(s['nominal'] as num) > 0 ? '+' : ''}${rp(s['nominal'] as num)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: (s['nominal'] as num) > 0 ? Warna.oliveTua : Warna.merah)),
                  ),
              ],
            ]);
          },
        ),
      );

  Widget _kosong() => ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 30),
        const Icon(Icons.savings_rounded, size: 72, color: Warna.olive),
        const SizedBox(height: 14),
        Text('Siapkan cicilan KUR dari sekarang',
            textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Pasang target, misalnya cicilan KUR atau gerobak baru. Tiap hari VoKas menghitung berapa persen untung '
          'yang bisa kamu sisihkan dan menunjukkan kapan target tercapai.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Warna.redup, height: 1.5),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _sibuk ? null : () => _atur(null), child: const Text('Buat target celengan')),
      ]);

  static String _tgl(dynamic iso) {
    final w = DateTime.tryParse('$iso')?.toLocal();
    if (w == null) return '';
    return '${w.day}/${w.month} ${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';
  }
}
