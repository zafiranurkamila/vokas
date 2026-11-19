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

  /// Daftar hasil baca nota; tiap baris bisa diketuk untuk dikoreksi.
  Widget _hasilBisaDiedit(List<Map<String, dynamic>> daftar) {
    final total = daftar.fold<num>(0, (s, t) => s + ((t['total'] as num?) ?? 0));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(color: Warna.kartu, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${daftar.length} barang tercatat sebagai pengeluaran', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 2),
        const Text('Periksa hasil baca. Ketuk barang untuk mengubah bila ada yang salah.',
            style: TextStyle(fontSize: 12, color: Warna.redup, height: 1.4)),
        const SizedBox(height: 8),
        for (final t in daftar)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _ubah(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${t['namaItem']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (t['jumlah'] != null)
                      Text('${t['jumlah']} ${t['satuan'] ?? ''}${t['hargaSatuan'] != null ? ' x ${rp(t['hargaSatuan'] as num)}' : ''}',
                          style: const TextStyle(fontSize: 12, color: Warna.redup)),
                  ]),
                ),
                Text(rp((t['total'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined, size: 18, color: Warna.olive),
              ]),
            ),
          ),
        const Divider(height: 12),
        Row(children: [
          const Expanded(child: Text('Total nota', style: TextStyle(fontWeight: FontWeight.w600))),
          Text(rp(total), style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
      ]),
    );
  }

  Future<void> _ubah(Map<String, dynamic> t) async {
    final nama = TextEditingController(text: '${t['namaItem'] ?? ''}');
    final jumlah = TextEditingController(text: t['jumlah'] == null ? '' : '${t['jumlah']}');
    final satuan = TextEditingController(text: '${t['satuan'] ?? ''}');
    final harga = TextEditingController(text: t['hargaSatuan'] == null ? '' : '${t['hargaSatuan']}');
    final total = TextEditingController(text: '${t['total'] ?? ''}');
    int? angka(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), ''));
    // total ikut berubah saat jumlah atau harga satuan diganti
    void hitung() {
      final j = angka(jumlah), h = angka(harga);
      if (j != null && h != null) total.text = '${j * h}';
    }

    jumlah.addListener(hitung);
    harga.addListener(hitung);
    final simpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Ubah barang', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: nama, decoration: const InputDecoration(labelText: 'Nama barang')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: jumlah, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: satuan, decoration: const InputDecoration(labelText: 'Satuan'))),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: harga, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga satuan (Rp)')),
          const SizedBox(height: 10),
          TextField(controller: total, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total (Rp)')),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simpan perubahan')),
        ]),
      ),
    );
    if (simpan != true || !mounted) return;
    final tot = angka(total), jml = angka(jumlah), hrg = angka(harga);
    if (nama.text.trim().isEmpty || tot == null || tot <= 0) {
      tampilPesan(context, 'Nama barang dan total harus diisi.', jenis: JenisPesan.gagal);
      return;
    }
    try {
      final baru = await Api.ubahTransaksi(Sesi.pedagangId!, '${t['id']}', {
        'namaItem': nama.text.trim(),
        if (jml != null && jml > 0) 'jumlah': jml,
        'satuan': satuan.text.trim(),
        if (hrg != null && hrg > 0) 'hargaSatuan': hrg,
        'total': tot,
      });
      if (!mounted) return;
      setState(() {
        final l = (_hasil!['tersimpan'] as List?) ?? [];
        final i = l.indexWhere((x) => '${x['id']}' == '${t['id']}');
        if (i >= 0) l[i] = baru;
      });
      tampilPesan(context, 'Barang diperbarui.');
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
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
          if (_hasil != null && tersimpan.isEmpty) StrukCatat(_hasil!),
          if (tersimpan.isNotEmpty) _hasilBisaDiedit(tersimpan.cast<Map<String, dynamic>>()),
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
