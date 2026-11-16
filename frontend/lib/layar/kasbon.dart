import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';
import '../widget/perekam.dart';

/// Kasbon: catat pelanggan yang ngutang lewat suara atau ketik, tagih lewat WhatsApp, tandai lunas.
class LayarKasbon extends StatefulWidget {
  const LayarKasbon({super.key});

  @override
  State<LayarKasbon> createState() => _LayarKasbonState();
}

class _LayarKasbonState extends State<LayarKasbon> {
  late Future<Map<String, dynamic>> _data = _muat();
  final _teks = TextEditingController();
  bool _membaca = false;
  bool _berubah = false;

  Future<Map<String, dynamic>> _muat() => Api.kasbon(Sesi.pedagangId!);

  void _segarkan() => setState(() => _data = _muat());

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  Future<void> _bacaTeks() async {
    final t = _teks.text.trim();
    if (t.isEmpty) return _isiManual();
    FocusScope.of(context).unfocus();
    setState(() => _membaca = true);
    try {
      await _konfirmasi(await Api.bacaKasbon(Sesi.pedagangId!, t));
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
    } finally {
      if (mounted) setState(() => _membaca = false);
    }
  }

  Future<void> _bacaSuara(Uint8List audio, String mime) async {
    setState(() => _membaca = true);
    try {
      await _konfirmasi(await Api.bacaKasbonSuara(Sesi.pedagangId!, audio, mime));
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
    } finally {
      if (mounted) setState(() => _membaca = false);
    }
  }

  Future<void> _isiManual() => _konfirmasi(const {});

  /// Tampilkan draf hasil baca supaya pedagang bisa membetulkan sebelum disimpan.
  Future<void> _konfirmasi(Map<String, dynamic> d) async {
    final nama = TextEditingController(text: d['namaPelanggan'] as String? ?? '');
    final nominal = TextEditingController(text: d['nominal'] == null ? '' : '${d['nominal']}');
    final ket = TextEditingController(text: d['keterangan'] as String? ?? '');
    final wa = TextEditingController();
    final transkrip = (d['transkrip'] as String?) ?? '';
    final simpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Warna.latar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Catat kasbon', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
          if (transkrip.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('"$transkrip"', style: const TextStyle(fontStyle: FontStyle.italic, color: Warna.redup, fontSize: 13)),
          ],
          if (d['galat'] != null) ...[
            const SizedBox(height: 6),
            Text('${d['galat']}. Lengkapi di bawah ya.', style: const TextStyle(color: Warna.merah, fontSize: 12.5)),
          ],
          const SizedBox(height: 14),
          TextField(controller: nama, decoration: const InputDecoration(labelText: 'Nama pelanggan', hintText: 'Bu Ani')),
          const SizedBox(height: 10),
          TextField(
            controller: nominal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah utang', prefixText: 'Rp '),
          ),
          const SizedBox(height: 10),
          TextField(controller: ket, decoration: const InputDecoration(labelText: 'Keterangan (opsional)', hintText: 'beras 2 kg')),
          const SizedBox(height: 10),
          TextField(
            controller: wa,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'No. WhatsApp pelanggan (opsional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simpan kasbon')),
        ]),
      ),
    );
    if (simpan != true) return;
    final n = int.tryParse(nominal.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (nama.text.trim().isEmpty || n <= 0) {
      if (mounted) tampilPesan(context, 'Nama dan jumlah utang wajib diisi.', jenis: JenisPesan.info);
      return;
    }
    try {
      await Api.tambahKasbon(Sesi.pedagangId!, {
        'namaPelanggan': nama.text.trim(),
        'nominal': n,
        'keterangan': ket.text.trim(),
        'noWa': wa.text.trim(),
      });
      _teks.clear();
      _berubah = true;
      _segarkan();
      if (mounted) tampilPesan(context, 'Kasbon ${nama.text.trim()} ${rp(n)} tercatat.', jenis: JenisPesan.berhasil);
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
    }
  }

  Future<void> _lunas(Map<String, dynamic> k) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${k['namaPelanggan']} sudah bayar?'),
        content: Text('${rp(k['nominal'] as num)} akan dicatat sebagai uang masuk hari ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Belum')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
            child: const Text('Sudah lunas'),
          ),
        ],
      ),
    );
    if (ya != true) return;
    try {
      await Api.lunasKasbon(Sesi.pedagangId!, '${k['id']}');
      _berubah = true;
      _segarkan();
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
    }
  }

  Future<void> _hapus(Map<String, dynamic> k) async {
    try {
      await Api.hapusKasbon(Sesi.pedagangId!, '${k['id']}');
      _segarkan();
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
    }
  }

  Future<void> _tagih(Map<String, dynamic> k) async {
    final usaha = Sesi.namaUsaha.isNotEmpty ? Sesi.namaUsaha : 'warung kami';
    final ket = k['keterangan'] == null ? '' : ' untuk ${k['keterangan']}';
    final pesan = 'Halo ${k['namaPelanggan']}, mengingatkan kasbon di $usaha sebesar ${rp(k['nominal'] as num)}$ket '
        '(sejak ${_tanggal(k['dibuat'])}). Kalau sudah ada rezekinya boleh dibayar ya. Terima kasih';
    await Share.share(pesan, subject: 'Tagihan kasbon');
  }

  static String _tanggal(dynamic iso) {
    final w = DateTime.tryParse('$iso')?.toLocal();
    if (w == null) return '-';
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${w.day} ${bulan[w.month - 1]}';
  }

  static int _umurHari(dynamic iso) {
    final w = DateTime.tryParse('$iso')?.toLocal();
    return w == null ? 0 : DateTime.now().difference(w).inDays;
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(_berubah);
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Kasbon Pelanggan')),
          body: FutureBuilder(
            future: _data,
            builder: (context, snap) {
              final masukan = Kartu(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Ucapkan atau ketik, misalnya "Bu Ani ngutang 20 ribu buat beras"',
                      style: TextStyle(fontSize: 12.5, color: Warna.redup)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _teks,
                        enabled: !_membaca,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _bacaTeks(),
                        decoration: const InputDecoration(hintText: 'Siapa ngutang berapa?', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_membaca)
                      const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)))
                    else ...[
                      IconButton(onPressed: _bacaTeks, icon: const Icon(Icons.arrow_upward_rounded, color: Warna.oliveTua)),
                      TombolRekam(onSelesai: _bacaSuara, maksDetik: 20),
                    ],
                  ]),
                ]),
              );
              if (snap.hasError) {
                return ListView(padding: const EdgeInsets.all(20), children: [
                  masukan,
                  const SizedBox(height: 30),
                  Text(pesanGalat(snap.error!), textAlign: TextAlign.center),
                  TextButton(onPressed: _segarkan, child: const Text('Coba lagi')),
                ]);
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final d = snap.data!;
              final belum = ((d['belumLunas'] as List?) ?? []).cast<Map<String, dynamic>>();
              final lunas = ((d['lunas'] as List?) ?? []).cast<Map<String, dynamic>>();
              return RefreshIndicator(
                onRefresh: () async {
                  _segarkan();
                  await _data;
                },
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Warna.oliveTua, borderRadius: BorderRadius.circular(22)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Uang di pelanggan', style: TextStyle(color: Warna.khaki, fontSize: 13)),
                          Text(rp(d['totalBelumLunas'] as num? ?? 0),
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                          Text('${d['jumlahPelanggan'] ?? 0} pelanggan belum bayar',
                              style: const TextStyle(color: Warna.khaki, fontSize: 12)),
                        ]),
                      ),
                      const Icon(Icons.menu_book_rounded, color: Warna.matahari, size: 40),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  masukan,
                  const SizedBox(height: 20),
                  Text('Belum lunas', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (belum.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Tidak ada kasbon. Semua pelanggan sudah lunas',
                          textAlign: TextAlign.center, style: TextStyle(color: Warna.redup)),
                    ),
                  for (final k in belum) ...[
                    _KartuKasbon(
                      k,
                      umur: _umurHari(k['dibuat']),
                      tanggal: _tanggal(k['dibuat']),
                      onTagih: () => _tagih(k),
                      onLunas: () => _lunas(k),
                      onHapus: () => _hapus(k),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (lunas.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Sudah lunas', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Warna.redup)),
                    const SizedBox(height: 6),
                    for (final k in lunas)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_rounded, color: Warna.olive),
                        title: Text('${k['namaPelanggan']}'),
                        subtitle: Text('Lunas ${_tanggal(k['dilunasi'])}'),
                        trailing: Text(rp(k['nominal'] as num), style: const TextStyle(color: Warna.redup)),
                      ),
                  ],
                ]),
              );
            },
          ),
        ),
      );
}

class _KartuKasbon extends StatelessWidget {
  const _KartuKasbon(this.k,
      {required this.umur, required this.tanggal, required this.onTagih, required this.onLunas, required this.onHapus});
  final Map<String, dynamic> k;
  final int umur;
  final String tanggal;
  final VoidCallback onTagih, onLunas, onHapus;

  @override
  Widget build(BuildContext context) {
    final lama = umur >= 7;
    return Kartu(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: lama ? Warna.merah.withOpacity(.12) : Warna.khaki,
            child: Text('${k['namaPelanggan']}'.trim().split(' ').last.characters.first.toUpperCase(),
                style: TextStyle(color: lama ? Warna.merah : Warna.oliveTua, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${k['namaPelanggan']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                [if (k['keterangan'] != null) '${k['keterangan']}', 'sejak $tanggal', if (umur > 0) '$umur hari'].join(' · '),
                style: TextStyle(fontSize: 12, color: lama ? Warna.merah : Warna.redup),
              ),
            ]),
          ),
          Text(rp(k['nominal'] as num), style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Warna.redup),
            onSelected: (_) => onHapus(),
            itemBuilder: (_) => const [PopupMenuItem(value: 'hapus', child: Text('Hapus (salah catat)'))],
          ),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton.icon(onPressed: onTagih, icon: const Icon(Icons.send_rounded, size: 16), label: const Text('Tagih')),
          TextButton.icon(
            onPressed: onLunas,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Lunas'),
          ),
        ]),
      ]),
    );
  }
}
