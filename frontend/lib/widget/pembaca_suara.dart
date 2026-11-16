import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Laporan Dibacakan: VoKas membacakan ringkasan usaha dengan suara (bahasa Indonesia),
/// untuk pedagang yang sedang sibuk atau kurang nyaman membaca angka.
class PembacaSuara {
  PembacaSuara._();

  static final FlutterTts _tts = FlutterTts();
  static bool _siap = false;
  static final ValueNotifier<bool> berbicara = ValueNotifier(false);

  static Future<void> _siapkan() async {
    if (_siap) return;
    try {
      await _tts.setLanguage('id-ID');
    } catch (_) {}
    await _tts.setSpeechRate(kIsWeb ? 0.95 : 0.48);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() => berbicara.value = true);
    _tts.setCompletionHandler(() => berbicara.value = false);
    _tts.setCancelHandler(() => berbicara.value = false);
    _tts.setErrorHandler((_) => berbicara.value = false);
    _siap = true;
  }

  static Future<void> bacakan(String teks) async {
    await _siapkan();
    await _tts.stop();
    berbicara.value = true;
    await _tts.speak(teks);
  }

  static Future<void> berhenti() async {
    await _tts.stop();
    berbicara.value = false;
  }

  /// "Rp125.000" dibaca "125 ribu rupiah" supaya terdengar wajar.
  static String uang(num n) {
    final v = n.abs().round();
    final minus = n < 0 ? 'minus ' : '';
    if (v >= 1000000) {
      final jt = v ~/ 1000000;
      final sisa = (v % 1000000) ~/ 1000;
      return '$minus$jt juta${sisa > 0 ? ' $sisa ribu' : ''} rupiah';
    }
    if (v >= 1000) {
      final rb = v ~/ 1000;
      final sisa = v % 1000;
      return '$minus$rb ribu${sisa > 0 ? ' $sisa' : ''} rupiah';
    }
    return '$minus$v rupiah';
  }

  /// Ringkasan harian yang dibacakan dari beranda.
  static String ringkasanHarian({
    required String nama,
    required Map<String, dynamic> laporan,
    required Map<String, dynamic> kur,
    List<Map<String, dynamic>> peringatan = const [],
  }) {
    final omzet = (laporan['omzet'] as num?) ?? 0;
    final keluar = (laporan['pengeluaran'] as num?) ?? 0;
    final laba = (laporan['laba'] as num?) ?? 0;
    final qris = (laporan['omzetQris'] as num?) ?? 0;
    final terlaris = ((laporan['terlaris'] as List?) ?? []).cast<Map<String, dynamic>>();
    final b = StringBuffer('Halo $nama. Ini laporan usahamu hari ini. ');
    if (omzet == 0 && keluar == 0) {
      b.write('Belum ada catatan hari ini. Tekan tombol mic lalu sebutkan jualanmu. ');
    } else {
      b.write('Uang masuk ${uang(omzet)}');
      if (qris > 0) b.write(', ${uang(qris)} di antaranya lewat QRIS');
      b.write('. Uang keluar ${uang(keluar)}. ');
      b.write(laba >= 0 ? 'Jadi untungmu ${uang(laba)}. ' : 'Hari ini masih rugi ${uang(-laba)}. ');
      if (terlaris.isNotEmpty) b.write('Paling laku: ${terlaris.first['nama']}. ');
    }
    if (kur['skor'] != null) b.write('Skor Rapor KUR ${kur['skor']} dari 100. ');
    if (peringatan.isNotEmpty) b.write('Perhatian: ${peringatan.first['judul']}. ');
    b.write('Semangat jualannya!');
    return b.toString();
  }
}
