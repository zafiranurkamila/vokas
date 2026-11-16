import 'package:flutter/material.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';

/// Laporan lewat email: daftar + verifikasi kode OTP, lalu settlement QRIS harian (21.00) dan laporan bulanan.
class KartuEmail extends StatefulWidget {
  const KartuEmail({super.key});

  @override
  State<KartuEmail> createState() => _KartuEmailState();
}

class _KartuEmailState extends State<KartuEmail> {
  String? _email;
  bool _terverifikasi = false;
  bool _aktif = true;
  bool _memuat = true;
  bool _sibuk = false;
  final _isian = TextEditingController();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _isian.dispose();
    super.dispose();
  }

  void _terapkan(Map<String, dynamic> p) {
    _email = p['email'] as String?;
    _terverifikasi = p['emailTerverifikasi'] == true;
    _aktif = p['laporanEmail'] != false;
    if (_isian.text.isEmpty && _email != null) _isian.text = _email!;
  }

  Future<void> _muat() async {
    try {
      final p = await Api.pedagang(Sesi.pedagangId!);
      if (mounted) setState(() => _terapkan(p));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  void _pesan(String s) => tampilPesan(context, s);

  Future<void> _kirimKode() async {
    final email = _isian.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _pesan('Format email belum benar.');
      return;
    }
    setState(() => _sibuk = true);
    try {
      await Api.daftarEmail(Sesi.pedagangId!, email);
      if (!mounted) return;
      setState(() => _sibuk = false);
      await _mintaKode(email);
    } catch (e) {
      _pesan(pesanGalat(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _mintaKode(String email) async {
    final ctrl = TextEditingController();
    final kode = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Masukkan kode'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Kode 6 angka sudah dikirim ke $email. Cek juga folder Spam.',
              style: const TextStyle(fontSize: 13, color: Warna.redup, height: 1.45)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(hintText: '123456', counterText: ''),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Verifikasi')),
        ],
      ),
    );
    if (kode == null || kode.isEmpty) return;
    setState(() => _sibuk = true);
    try {
      final p = await Api.verifikasiEmail(Sesi.pedagangId!, kode);
      if (!mounted) return;
      setState(() => _terapkan(p));
      _pesan('Email terverifikasi. Laporan akan dikirim otomatis.');
    } catch (e) {
      _pesan(pesanGalat(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _ubahAktif(bool v) async {
    setState(() => _aktif = v);
    try {
      await Api.aturLaporanEmail(Sesi.pedagangId!, v);
    } catch (e) {
      setState(() => _aktif = !v);
      _pesan(pesanGalat(e));
    }
  }

  Future<void> _kirimSekarang(String jenis) async {
    setState(() => _sibuk = true);
    try {
      final h = await Api.kirimLaporanEmail(Sesi.pedagangId!, jenis);
      final wa = h['wa'] == true ? ' Ringkasan juga dikirim ke WhatsApp.' : '';
      _pesan(h['email'] == true ? 'Laporan $jenis terkirim ke $_email.$wa' : 'Email belum terkirim, coba lagi sebentar.');
    } catch (e) {
      _pesan(pesanGalat(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Kartu(child: SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))));
    }
    if (!_terverifikasi) {
      return Kartu(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Terima rincian settlement QRIS setiap malam dan laporan lengkap setiap awal bulan lewat email.',
              style: TextStyle(fontSize: 13, color: Warna.redup, height: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _isian,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'email@contoh.com', prefixIcon: Icon(Icons.mail_outline_rounded)),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _sibuk ? null : _kirimKode,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: _sibuk
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Kirim kode verifikasi'),
          ),
        ]),
      );
    }
    return Kartu(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mark_email_read_outlined, color: Warna.oliveTua),
          title: Text(_email ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Terverifikasi', style: TextStyle(fontSize: 12.5)),
          trailing: TextButton(
            onPressed: _sibuk ? null : () => setState(() => _terverifikasi = false),
            child: const Text('Ganti'),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _aktif,
          onChanged: _sibuk ? null : _ubahAktif,
          activeColor: Warna.oliveTua,
          title: const Text('Laporan otomatis', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5)),
          subtitle: const Text('Settlement QRIS tiap pukul 21.00, laporan bulanan tiap tanggal 1', style: TextStyle(fontSize: 12.5)),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _sibuk ? null : () => _kirimSekarang('harian'),
              child: const Text('Kirim hari ini'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _sibuk ? null : () => _kirimSekarang('bulanan'),
              child: const Text('Kirim bulan ini'),
            ),
          ),
        ]),
      ]),
    );
  }
}
