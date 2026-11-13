import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';
import 'beranda.dart';

/// Lembar bawah untuk mencatat: tekan mic untuk rekam suara, atau ketik kalimat.
/// Hasil disimpan oleh backend lalu ditampilkan supaya pedagang bisa langsung cek.
class LembarCatat extends StatefulWidget {
  const LembarCatat({super.key});

  @override
  State<LembarCatat> createState() => _LembarCatatState();
}

enum _Status { siap, merekam, memproses, selesai }

class _LembarCatatState extends State<LembarCatat> {
  static const _maksDetik = 60;

  final _rekam = AudioRecorder();
  final _teks = TextEditingController();
  _Status _status = _Status.siap;
  int _detik = 0;
  Timer? _timer;
  Map<String, dynamic>? _hasil;
  bool _adaYangTersimpan = false;

  @override
  void dispose() {
    _timer?.cancel();
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
    // WAV 16 kHz mono: format yang diterima Gemini dan kecil (sekitar 2 MB per menit)
    await _rekam.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: path);
    setState(() {
      _status = _Status.merekam;
      _detik = 0;
      _hasil = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _detik++);
      if (_detik >= _maksDetik) _berhentiRekam();
    });
  }

  Future<void> _berhentiRekam() async {
    _timer?.cancel();
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

  Future<void> _kirimTeks() async {
    final t = _teks.text.trim();
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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final bawah = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: _status != _Status.merekam && _status != _Status.memproses,
      onPopInvoked: (_) {},
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bawah),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
                width: 44, height: 5, decoration: BoxDecoration(color: Warna.garis, borderRadius: BorderRadius.circular(5))),
          ),
          const SizedBox(height: 16),
          Text('Catat transaksi', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            switch (_status) {
              _Status.merekam => 'Sedang merekam... sebutkan jualan atau belanjaanmu',
              _Status.memproses => 'Sedang membaca catatan...',
              _ => 'Tekan mic lalu bicara, contoh: "jual cilok tiga puluh bungkus dua ribuan"',
            },
            style: const TextStyle(color: Warna.redup, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Center(child: _tombolMic()),
          if (_status == _Status.merekam) ...[
            const SizedBox(height: 10),
            Center(
              child: Text('0:${_detik.toString().padLeft(2, '0')} / 1:00',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Warna.oliveTua)),
            ),
          ],
          const SizedBox(height: 20),
          if (_hasil != null) _HasilCatat(_hasil!),
          if (_status != _Status.merekam)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _teks,
                  enabled: _status != _Status.memproses,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _kirimTeks(),
                  decoration: const InputDecoration(hintText: 'Atau ketik: beli gas melon 22 ribu'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _status == _Status.memproses ? null : _kirimTeks,
                style: IconButton.styleFrom(backgroundColor: Warna.oliveTua, fixedSize: const Size(52, 52)),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ]),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _status == _Status.merekam || _status == _Status.memproses
                ? null
                : () => Navigator.of(context).pop(_adaYangTersimpan),
            child: Text(_adaYangTersimpan ? 'Selesai' : 'Tutup'),
          ),
        ]),
      ),
    );
  }

  Widget _tombolMic() {
    if (_status == _Status.memproses) {
      return const SizedBox(width: 96, height: 96, child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()));
    }
    final rekam = _status == _Status.merekam;
    return GestureDetector(
      onTap: rekam ? _berhentiRekam : _mulaiRekam,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: rekam ? Warna.merah : Warna.oliveTua,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: (rekam ? Warna.merah : Warna.olive).withOpacity(.35), blurRadius: rekam ? 28 : 12, spreadRadius: rekam ? 6 : 0),
          ],
        ),
        child: Icon(rekam ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 46),
      ),
    );
  }
}

class _HasilCatat extends StatelessWidget {
  const _HasilCatat(this.h);
  final Map<String, dynamic> h;

  @override
  Widget build(BuildContext context) {
    final baca = (h['baca'] as Map<String, dynamic>?) ?? {};
    final tersimpan = ((h['tersimpan'] as List?) ?? []).cast<Map<String, dynamic>>();
    final transkrip = (baca['transkrip'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (transkrip.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('"$transkrip"', style: const TextStyle(fontStyle: FontStyle.italic, color: Warna.redup)),
          ),
        if (tersimpan.isEmpty)
          Kartu(
            warna: Warna.matahari.withOpacity(.2),
            child: Text(
              (baca['galat'] as String?) ?? 'Nominalnya belum terbaca. Coba sebutkan harganya, misalnya "dua puluh ribu".',
              style: const TextStyle(height: 1.4),
            ),
          )
        else ...[
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: Warna.olive, size: 18),
            const SizedBox(width: 6),
            Text('Tercatat ${tersimpan.length} transaksi', style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          ...tersimpan.map((t) => BarisTransaksi(t)),
          if (baca['lengkap'] == false)
            const Text('Sebagian kalimat belum terbaca, cek lagi ya.', style: TextStyle(fontSize: 12, color: Warna.merah)),
        ],
      ]),
    );
  }
}
