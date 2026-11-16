import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';
import 'catat.dart';

/// Foto nota belanja dari pemasok; AI membaca barang dan harganya lalu mencatat sebagai pengeluaran.
class LayarFotoNota extends StatefulWidget {
  const LayarFotoNota({super.key});

  @override
  State<LayarFotoNota> createState() => _LayarFotoNotaState();
}

class _LayarFotoNotaState extends State<LayarFotoNota> {
  final _pemilih = ImagePicker();
  Uint8List? _foto;
  String _mime = 'image/jpeg';
  bool _membaca = false;
  bool _membatalkan = false;
  Map<String, dynamic>? _hasil;
  bool _adaYangTersimpan = false;

  Future<void> _ambil(ImageSource sumber) async {
    try {
      final f = await _pemilih.pickImage(source: sumber, maxWidth: 1600, imageQuality: 80);
      if (f == null) return;
      final isi = await f.readAsBytes();
      setState(() {
        _foto = isi;
        _mime = f.mimeType ?? (f.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
        _hasil = null;
      });
      await _baca();
    } catch (e) {
      if (mounted) tampilPesan(context, 'Foto tidak bisa dibuka: $e', jenis: JenisPesan.gagal);
    }
  }

  Future<void> _baca() async {
    if (_foto == null) return;
    setState(() => _membaca = true);
    try {
      final h = await Api.catatFoto(Sesi.pedagangId!, _foto!, _mime);
      if (((h['tersimpan'] as List?) ?? []).isNotEmpty) _adaYangTersimpan = true;
      if (mounted) setState(() => _hasil = h);
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
    } finally {
      if (mounted) setState(() => _membaca = false);
    }
  }

  Future<void> _batalkan() async {
    final tersimpan = ((_hasil?['tersimpan'] as List?) ?? []).cast<Map<String, dynamic>>();
    setState(() => _membatalkan = true);
    try {
      for (final t in tersimpan) {
        await Api.hapusTransaksi(Sesi.pedagangId!, '${t['id']}');
      }
      if (!mounted) return;
      setState(() {
        _hasil = null;
        _foto = null;
      });
      tampilPesan(context, 'Catatan dari nota dibatalkan.');
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
    } finally {
      if (mounted) setState(() => _membatalkan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tersimpan = ((_hasil?['tersimpan'] as List?) ?? []);
    return PopScope(
      canPop: !_membaca,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Foto Nota'),
          leading: BackButton(onPressed: _membaca ? null : () => Navigator.of(context).pop(_adaYangTersimpan)),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
          Text('Belanja ke pemasok? Foto notanya saja.', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('AI membaca nama barang dan harganya, lalu mencatatnya sebagai pengeluaran. Nota tulisan tangan juga bisa.',
              style: TextStyle(color: Warna.redup, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          Container(
            height: 260,
            decoration: BoxDecoration(color: Warna.kartu, borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: _foto == null
                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.receipt_long_rounded, size: 56, color: Warna.olive),
                    SizedBox(height: 8),
                    Text('Belum ada foto', style: TextStyle(color: Warna.redup)),
                  ])
                : Stack(fit: StackFit.expand, children: [
                    Image.memory(_foto!, fit: BoxFit.cover),
                    if (_membaca)
                      Container(
                        color: Colors.black45,
                        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text('AI sedang membaca nota...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _membaca ? null : () => _ambil(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Foto nota'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _membaca ? null : () => _ambil(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Dari galeri'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          if (_hasil != null) StrukCatat(_hasil!),
          if (_hasil != null && tersimpan.isEmpty && !_membaca)
            TextButton.icon(onPressed: _baca, icon: const Icon(Icons.refresh_rounded), label: const Text('Baca ulang')),
          if (tersimpan.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: _membatalkan ? null : _batalkan,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Salah baca? Batalkan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Warna.merah,
                side: BorderSide(color: Warna.merah.withOpacity(.5)),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Selesai')),
          ],
        ]),
      ),
    );
  }
}
