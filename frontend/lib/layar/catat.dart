import 'dart:async';
import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';

/// Lembar bawah untuk mencatat: tekan mic lalu bicara, atau ketik / ketuk contoh kalimat.
class LembarCatat extends StatefulWidget {
  const LembarCatat({super.key});

  @override
  State<LembarCatat> createState() => _LembarCatatState();
}

enum _Status { siap, merekam, memproses, selesai }

const _contoh = [
  'jual cilok 30 bungkus dua ribuan',
  'laku es teh 15 gelas 3000',
  'beli gas melon 22 ribu',
  'beli tepung 50rb terus minyak 38 ribu',
];

class _LembarCatatState extends State<LembarCatat> with SingleTickerProviderStateMixin {
  static const _maksDetik = 60;
  static const _jumlahBatang = 28;

  final _rekam = AudioRecorder();
  final _teks = TextEditingController();
  late final _denyut = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  _Status _status = _Status.siap;
  int _detik = 0;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amp;
  final List<double> _level = List.filled(_jumlahBatang, 0.08, growable: true);
  Map<String, dynamic>? _hasil;
  bool _adaYangTersimpan = false;

  @override
  void dispose() {
    _timer?.cancel();
    _amp?.cancel();
    _denyut.dispose();
    _rekam.dispose();
    _teks.dispose();
    super.dispose();
  }

  Future<void> _mulaiRekam() async {
    if (!await _rekam.hasPermission()) {
      _pesan('Izin mikrofon ditolak. Kamu tetap bisa mengetik catatan.');
      return;
    }
    final path = kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/catatan.wav';
    // WAV 16 kHz mono: diterima Gemini dan kecil (sekitar 2 MB per menit)
    await _rekam.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: path);
    setState(() {
      _status = _Status.merekam;
      _detik = 0;
      _hasil = null;
      _level.fillRange(0, _level.length, 0.08);
    });
    _denyut.repeat();
    _amp = _rekam.onAmplitudeChanged(const Duration(milliseconds: 110)).listen((a) {
      // dBFS kira-kira -50 (hening) sampai 0 (keras) -> 0..1
      final v = ((a.current + 50) / 50).clamp(0.06, 1.0).toDouble();
      setState(() {
        _level.removeAt(0);
        _level.add(v);
      });
    }, onError: (_) {});
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _detik++);
      if (_detik >= _maksDetik) _berhentiRekam();
    });
  }

  Future<void> _berhentiRekam() async {
    _timer?.cancel();
    await _amp?.cancel();
    _denyut.stop();
    final path = await _rekam.stop();
    if (path == null) {
      setState(() => _status = _Status.siap);
      return;
    }
    setState(() => _status = _Status.memproses);
    try {
      final bytes = await XFile(path).readAsBytes();
      _tampilkan(await Api.catatSuara(Sesi.pedagangId!, bytes, 'audio/wav'));
    } catch (e) {
      _pesan(pesanGalat(e));
      setState(() => _status = _Status.siap);
    }
  }

  Future<void> _kirimTeks([String? isi]) async {
    final t = (isi ?? _teks.text).trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _status = _Status.memproses);
    try {
      _tampilkan(await Api.catatTeks(Sesi.pedagangId!, t));
      _teks.clear();
    } catch (e) {
      _pesan(pesanGalat(e));
      setState(() => _status = _Status.siap);
    }
  }

  void _tampilkan(Map<String, dynamic> h) {
    final tersimpan = (h['tersimpan'] as List?) ?? [];
    if (tersimpan.isNotEmpty) _adaYangTersimpan = true;
    setState(() {
      _hasil = h;
      _status = _Status.selesai;
    });
  }

  void _pesan(String s) {
    if (mounted) tampilPesan(context, s);
  }

  @override
  Widget build(BuildContext context) {
    final bawah = MediaQuery.of(context).viewInsets.bottom;
    final sibuk = _status == _Status.merekam || _status == _Status.memproses;
    return PopScope(
      canPop: !sibuk,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bawah),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                  width: 44, height: 5, decoration: BoxDecoration(color: Warna.garis, borderRadius: BorderRadius.circular(5))),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Text('Catat transaksi', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700))),
              IconButton(
                onPressed: sibuk ? null : () => Navigator.of(context).pop(_adaYangTersimpan),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                key: ValueKey(_status),
                switch (_status) {
                  _Status.merekam => 'Mendengarkan... tekan tombol lagi kalau sudah selesai',
                  _Status.memproses => 'Sedang membaca catatanmu...',
                  _Status.selesai => 'Mau catat lagi? Tekan mic atau ketik di bawah.',
                  _Status.siap => 'Tekan mic lalu sebutkan jualan atau belanjaanmu.',
                },
                style: const TextStyle(color: Warna.redup, fontSize: 13),
              ),
            ),
            const SizedBox(height: 18),
            _panelSuara(),
            const SizedBox(height: 18),
            if (_hasil != null) _Struk(_hasil!),
            if (!sibuk) ...[
              if (_hasil == null) ...[
                const Text('Coba contoh ini:', style: TextStyle(fontSize: 12.5, color: Warna.redup)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in _contoh)
                    ActionChip(
                      label: Text(c, style: const TextStyle(fontSize: 12.5)),
                      backgroundColor: Warna.kartu,
                      side: const BorderSide(color: Warna.garis),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () => _kirimTeks(c),
                    ),
                ]),
                const SizedBox(height: 16),
              ],
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _teks,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _kirimTeks(),
                    decoration: const InputDecoration(
                      hintText: 'Atau ketik di sini...',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _kirimTeks(),
                  style: IconButton.styleFrom(backgroundColor: Warna.oliveTua, fixedSize: const Size(50, 50)),
                  icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                ),
              ]),
            ],
            if (_adaYangTersimpan && !sibuk) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Selesai')),
            ],
          ]),
        ),
      ),
    );
  }

  /// Kartu suara: gelombang langsung dari mikrofon, timer, dan tombol mic dengan denyut.
  Widget _panelSuara() {
    final rekam = _status == _Status.merekam;
    final proses = _status == _Status.memproses;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: rekam ? Warna.oliveTua : Warna.kartu,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: [
        SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _jumlahBatang; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 110),
                  width: 4,
                  height: proses ? 8 + 18 * (0.5 + 0.5 * sin(i / 2.2)) : 6 + 42 * _level[i],
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: rekam ? Warna.matahari.withOpacity(.4 + .6 * _level[i]) : Warna.olive.withOpacity(.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          rekam ? '0:${_detik.toString().padLeft(2, '0')}' : (proses ? 'Membaca...' : '0:00'),
          style: TextStyle(fontWeight: FontWeight.w600, color: rekam ? Colors.white : Warna.redup, fontSize: 13),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: proses ? null : (rekam ? _berhentiRekam : _mulaiRekam),
          child: SizedBox(
            width: 96,
            height: 96,
            child: Stack(alignment: Alignment.center, children: [
              if (rekam)
                AnimatedBuilder(
                  animation: _denyut,
                  builder: (_, __) => Container(
                    width: 72 + 24 * _denyut.value,
                    height: 72 + 24 * _denyut.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.25 * (1 - _denyut.value)),
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rekam ? Colors.white : Warna.oliveTua,
                ),
                child: proses
                    ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Icon(rekam ? Icons.stop_rounded : Icons.mic_rounded, color: rekam ? Warna.merah : Colors.white, size: 34),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Hasil pencatatan dalam bentuk struk kecil dengan animasi centang.
class _Struk extends StatelessWidget {
  const _Struk(this.h);
  final Map<String, dynamic> h;

  @override
  Widget build(BuildContext context) {
    final baca = (h['baca'] as Map<String, dynamic>?) ?? {};
    final tersimpan = ((h['tersimpan'] as List?) ?? []).cast<Map<String, dynamic>>();
    final transkrip = (baca['transkrip'] as String?) ?? '';
    if (tersimpan.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Warna.matahari.withOpacity(.2), borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.help_outline_rounded, color: Color(0xFF7A5E00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              (baca['galat'] as String?) ?? 'Nominalnya belum terbaca. Coba sebutkan harganya, misalnya "dua puluh ribu".',
              style: const TextStyle(height: 1.4),
            ),
          ),
        ]),
      );
    }
    final total = tersimpan.fold<num>(0, (s, t) => s + (t['jenis'] == 'MASUK' ? 1 : -1) * (t['total'] as num));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Warna.kartu, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Warna.olive, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${tersimpan.length} transaksi tercatat',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ]),
          if (transkrip.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('"$transkrip"', style: const TextStyle(fontStyle: FontStyle.italic, color: Warna.redup, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          const _GarisStruk(),
          for (final t in tersimpan) _BarisStruk(t),
          const _GarisStruk(),
          Row(children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${total >= 0 ? '+' : '-'}${rp(total.abs())}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 16, color: total >= 0 ? Warna.oliveTua : Warna.merah)),
          ]),
          if (baca['lengkap'] == false)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Sebagian kalimat belum terbaca, cek lagi ya.', style: TextStyle(fontSize: 12, color: Warna.merah)),
            ),
        ]),
      ),
    );
  }
}

class _BarisStruk extends StatelessWidget {
  const _BarisStruk(this.t);
  final Map<String, dynamic> t;

  @override
  Widget build(BuildContext context) {
    final masuk = t['jenis'] == 'MASUK';
    final nama = '${t['namaItem']}';
    final detail = t['jumlah'] == null
        ? null
        : '${t['jumlah']} ${t['satuan'] ?? ''}${t['hargaSatuan'] == null ? '' : ' × ${rp(t['hargaSatuan'] as num)}'}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(masuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 16, color: masuk ? Warna.oliveTua : Warna.merah),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nama.isEmpty ? nama : nama[0].toUpperCase() + nama.substring(1),
                style: const TextStyle(fontWeight: FontWeight.w500)),
            if (detail != null) Text(detail, style: const TextStyle(fontSize: 12, color: Warna.redup)),
          ]),
        ),
        Text('${masuk ? '+' : '-'}${rp(t['total'] as num)}',
            style: TextStyle(fontWeight: FontWeight.w600, color: masuk ? Warna.oliveTua : Warna.merah)),
      ]),
    );
  }
}

class _GarisStruk extends StatelessWidget {
  const _GarisStruk();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
          builder: (_, c) => Row(
            children: List.generate(
              (c.maxWidth / 8).floor(),
              (_) => Container(width: 4, height: 1.2, margin: const EdgeInsets.only(right: 4), color: Warna.garis),
            ),
          ),
        ),
      );
}
