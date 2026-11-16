import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../tema.dart';

/// Tombol mic kecil: ketuk untuk mulai merekam, ketuk lagi untuk selesai. Hasil WAV 16 kHz mono.
/// Saat merekam muncul tombol buang bila salah ngomong.
class TombolRekam extends StatefulWidget {
  const TombolRekam({super.key, required this.onSelesai, this.maksDetik = 30, this.aktif = true});
  final Future<void> Function(Uint8List audio, String mime) onSelesai;
  final int maksDetik;
  final bool aktif;

  @override
  State<TombolRekam> createState() => _TombolRekamState();
}

class _TombolRekamState extends State<TombolRekam> {
  final _rekam = AudioRecorder();
  bool _merekam = false;
  int _detik = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _rekam.dispose();
    super.dispose();
  }

  Future<void> _mulai() async {
    if (!await _rekam.hasPermission()) {
      if (mounted) tampilPesan(context, 'Izin mikrofon ditolak. Kamu tetap bisa mengetik.');
      return;
    }
    final path = kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/rekam_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rekam.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: path);
    setState(() {
      _merekam = true;
      _detik = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _detik++);
      if (_detik >= widget.maksDetik) _berhenti();
    });
  }

  Future<void> _berhenti() async {
    _timer?.cancel();
    final path = await _rekam.stop();
    setState(() => _merekam = false);
    if (path == null) return;
    final bytes = await XFile(path).readAsBytes();
    await widget.onSelesai(bytes, 'audio/wav');
  }

  Future<void> _buang() async {
    _timer?.cancel();
    try {
      await _rekam.cancel();
    } catch (_) {}
    if (mounted) setState(() => _merekam = false);
  }

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (_merekam) ...[
          Text('0:${_detik.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Warna.merah, fontWeight: FontWeight.w600, fontSize: 12)),
          IconButton(
            tooltip: 'Buang rekaman',
            onPressed: _buang,
            icon: const Icon(Icons.delete_outline_rounded, color: Warna.redup),
          ),
        ],
        IconButton.filled(
          tooltip: _merekam ? 'Selesai merekam' : 'Rekam suara',
          onPressed: !widget.aktif ? null : (_merekam ? _berhenti : _mulai),
          style: IconButton.styleFrom(
            backgroundColor: _merekam ? Warna.merah : Warna.oliveTua,
            fixedSize: const Size(50, 50),
          ),
          icon: Icon(_merekam ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white),
        ),
      ]);
}
