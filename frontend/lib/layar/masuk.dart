import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../main.dart';
import '../sesi.dart';
import '../tema.dart';

/// 0812-3456-789 / +62812... / 62812... -> 62812...
String? normalisasiWa(String s) {
  var d = s.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0')) d = '62${d.substring(1)}';
  if (d.startsWith('8')) d = '62$d';
  return RegExp(r'^62\d{8,13}$').hasMatch(d) ? d : null;
}

class LayarMasuk extends StatefulWidget {
  const LayarMasuk({super.key});

  @override
  State<LayarMasuk> createState() => _LayarMasukState();
}

class _LayarMasukState extends State<LayarMasuk> {
  bool _daftar = true;
  bool _sibuk = false;
  final _form = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _usaha = TextEditingController();
  final _wa = TextEditingController();

  Future<void> _kirim() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sibuk = true);
    try {
      final wa = normalisasiWa(_wa.text)!;
      final p = _daftar
          ? await Api.daftar(nama: _nama.text.trim(), namaUsaha: _usaha.text.trim(), noWa: wa)
          : await Api.masuk(wa);
      await Sesi.simpanPedagang(p);
      if (mounted) lanjut(context);
    } catch (e) {
      if (!mounted) return;
      final pesan = e is ApiGagal && e.status == 404
          ? 'Nomor belum terdaftar. Pilih "Daftar" dulu.'
          : e is ApiGagal && e.status == 409
              ? 'Nomor ini sudah terdaftar. Pilih "Masuk".'
              : pesanGalat(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Center(child: SvgPicture.asset('assets/vokas_ikon.svg', width: 72)),
                    const SizedBox(height: 16),
                    Text(_daftar ? 'Buat akun VoKas' : 'Selamat datang lagi',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                        _daftar
                            ? 'Pakai nomor WhatsApp yang dipakai untuk kirim catatan.'
                            : 'Masuk dengan nomor WhatsApp yang sudah terdaftar.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Warna.redup)),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Daftar')),
                        ButtonSegment(value: false, label: Text('Masuk')),
                      ],
                      selected: {_daftar},
                      onSelectionChanged: (s) => setState(() => _daftar = s.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 20),
                    if (_daftar) ...[
                      TextFormField(
                        controller: _nama,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nama kamu', hintText: 'Sri Wahyuni'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _usaha,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nama usaha', hintText: 'Cilok & Cireng Bu Sri'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _wa,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
                      decoration: const InputDecoration(
                          labelText: 'Nomor WhatsApp', hintText: '0812xxxxxxx', prefixIcon: Icon(Icons.phone_rounded)),
                      validator: (v) => normalisasiWa(v ?? '') == null ? 'Nomor WhatsApp tidak valid' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _sibuk ? null : _kirim,
                      child: _sibuk
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(_daftar ? 'Daftar' : 'Masuk'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
