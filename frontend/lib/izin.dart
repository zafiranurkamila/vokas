import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'sesi.dart';

/// Izin perangkat (mikrofon, notifikasi, lokasi) dan notifikasi sistem di luar aplikasi.
class Izin {
  static final _notif = FlutterLocalNotificationsPlugin();
  static bool _siap = false;
  static int _id = 0;

  /// Dipanggil saat notifikasi sistem ditekan.
  static void Function()? onNotifDitekan;

  static Future<void> siapkan() async {
    if (kIsWeb || _siap) return;
    tzdata.initializeTimeZones();
    await _notif.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/launcher_icon')),
      onDidReceiveNotificationResponse: (_) => onNotifDitekan?.call(),
    );
    _siap = true;
  }

  // ---------------- izin ----------------

  static Future<bool> mintaMikrofon() async {
    if (kIsWeb) {
      final r = AudioRecorder();
      final ok = await r.hasPermission();
      await r.dispose();
      return ok;
    }
    return (await Permission.microphone.request()).isGranted;
  }

  static Future<bool> mintaNotifikasi() async {
    if (kIsWeb) return false; // notifikasi di luar aplikasi hanya untuk aplikasi Android
    return (await Permission.notification.request()).isGranted;
  }

  /// Lokasi usaha (perkiraan) untuk dicantumkan di Rapor KUR.
  static Future<bool> mintaLokasi() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return false;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
      );
      await Sesi.simpanLokasi('${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> mikrofonAktif() async => kIsWeb ? true : (await Permission.microphone.status).isGranted;
  static Future<bool> notifikasiAktif() async => kIsWeb ? false : (await Permission.notification.status).isGranted;

  static Future<void> bukaPengaturan() => openAppSettings();

  // ---------------- notifikasi sistem ----------------

  /// Tampil di panel notifikasi HP, dengan bunyi, walau aplikasi sedang tidak dibuka.
  static Future<void> tampilkan(String judul, String isi) async {
    if (kIsWeb) return;
    await siapkan();
    await _notif.show(_id++, judul, isi, _detail);
  }

  /// Dijadwalkan ke sistem Android: tetap muncul walau aplikasi sudah ditutup.
  static Future<void> jadwalkan(int id, String judul, String isi, DateTime waktu) async {
    if (kIsWeb) return;
    await siapkan();
    await _notif.zonedSchedule(
      id,
      judul,
      isi,
      tz.TZDateTime.from(waktu.toUtc(), tz.UTC),
      _detail,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> batal(int id) async {
    if (kIsWeb) return;
    await siapkan();
    await _notif.cancel(id);
  }

  static const _detail = NotificationDetails(
        android: AndroidNotificationDetails(
          'vokas_uang_masuk',
          'Uang masuk',
          channelDescription: 'Pemberitahuan pembayaran QRIS dan transfer yang masuk',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
}
