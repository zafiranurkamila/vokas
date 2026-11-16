import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';
import '../widget/papan_pin.dart' show CatatanDemo;

/// Pengajuan merchant QRIS BRI lewat VoKas.
/// Skema kerja sama: VoKas mengumpulkan data usaha dan meneruskannya ke BRI; BRI memverifikasi identitas dan
/// rekening lalu menerbitkan QRIS. Pada demo, tahap verifikasi BRI disimulasikan (sekitar 3 menit).
class LayarDaftarQris extends StatefulWidget {
  const LayarDaftarQris({super.key});

  @override
  State<LayarDaftarQris> createState() => _LayarDaftarQrisState();
}

const _kategori = ['Makanan & minuman', 'Sayur & bahan pokok', 'Kelontong / warung', 'Jasa', 'Lainnya'];
const _omzet = ['< Rp1 jt/bln', 'Rp1-5 jt/bln', 'Rp5-15 jt/bln', '> Rp15 jt/bln'];
/// Produk tabungan BRI yang umum dipakai pelaku usaha mikro sebagai rekening penampung dana QRIS.
const _rekening = ['Simpedes', 'Simpedes UMi', 'BritAma', 'BritAma Bisnis', 'Tabungan BRI lain'];

class _LayarDaftarQrisState extends State<LayarDaftarQris> {
  Map<String, dynamic>? _status;
  bool _memuat = true;
  bool _mengirim = false;
  Timer? _pantau;

  final _form = GlobalKey<FormState>();
  final _pemilik = TextEditingController(text: Sesi.nama);
  final _usaha = TextEditingController(text: Sesi.namaUsaha);
  final _alamat = TextEditingController();
  final _kota = TextEditingController();
  final _rek = TextEditingController();
  String _kat = _kategori.first;
  String _omz = _omzet[1];
  String _jenisRek = _rekening.first;
  bool _setuju = false;

  @override
  void initState() {
    super.initState();
    _muat();
    // selama menunggu verifikasi, status diperbarui tiap 10 detik
    _pantau = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_status != null && _status!['status'] != 'AKTIF') _muat(diam: true);
    });
  }

  @override
  void dispose() {
    _pantau?.cancel();
    for (final c in [_pemilik, _usaha, _alamat, _kota, _rek]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _muat({bool diam = false}) async {
    try {
      final s = await Api.statusQris(Sesi.pedagangId!);
      if (mounted) setState(() => _status = s);
    } catch (e) {
      if (!diam && mounted) tampilPesan(context, pesanGalat(e));
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _ajukan() async {
    if (!_form.currentState!.validate()) return;
    if (!_setuju) {
      tampilPesan(context, 'Centang persetujuan dulu.');
      return;
    }
    setState(() => _mengirim = true);
    try {
      final s = await Api.ajukanQris(Sesi.pedagangId!, {
        'namaPemilik': _pemilik.text.trim(),
        'namaUsaha': _usaha.text.trim(),
        'kategori': _kat,
        'alamat': _alamat.text.trim(),
        'kota': _kota.text.trim(),
        'kisaranOmzet': _omz,
        'jenisRekening': _jenisRek,
        'nomorRekening': _rek.text.replaceAll(RegExp(r'\D'), ''),
        'setuju': true,
      });
      if (mounted) setState(() => _status = s);
      if (mounted) tampilPesan(context, 'Pengajuan terkirim ke BRI. Status akan diperbarui otomatis.');
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e));
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  Future<void> _ulang() async {
    try {
      await Api.batalQris(Sesi.pedagangId!);
      if (mounted) setState(() => _status = null);
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Daftar QRIS BRI')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _memuat
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
                    if (_status == null) ..._formulir() else ..._lacak(_status!),
                  ]),
          ),
        ),
      );

  // ---------------- formulir pengajuan ----------------

  List<Widget> _formulir() => [
        Kartu(
          warna: Warna.qris.withOpacity(.08),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.qr_code_2_rounded, color: Warna.qris, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                  'Belum punya QRIS? Ajukan QRIS BRI langsung dari VoKas. Data usaha dikirim ke BRI, BRI memverifikasi, '
                  'lalu QRIS terbit dan pembayarannya otomatis tercatat di VoKas.',
                  style: TextStyle(fontSize: 13, height: 1.45)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _pemilik,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama pemilik (sesuai KTP)', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usaha,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama usaha di QRIS', prefixIcon: Icon(Icons.storefront_outlined)),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            _Pilihan(judul: 'Kategori usaha', opsi: _kategori, nilai: _kat, onPilih: (v) => setState(() => _kat = v)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _alamat,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Alamat lapak / usaha', prefixIcon: Icon(Icons.place_outlined)),
              validator: (v) => (v ?? '').trim().length < 8 ? 'Isi alamat lengkap' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kota,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Kota / kabupaten', prefixIcon: Icon(Icons.location_city_outlined)),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            _Pilihan(judul: 'Perkiraan omzet', opsi: _omzet, nilai: _omz, onPilih: (v) => setState(() => _omz = v)),
            const SizedBox(height: 4),
            _Pilihan(
                judul: 'Jenis rekening BRI penampung dana',
                opsi: _rekening,
                nilai: _jenisRek,
                onPilih: (v) => setState(() => _jenisRek = v)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rek,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Nomor rekening BRI penampung dana',
                  helperText: 'Hanya 4 angka terakhir yang disimpan VoKas',
                  prefixIcon: Icon(Icons.account_balance_outlined)),
              validator: (v) => RegExp(r'^\d{10,16}$').hasMatch(v ?? '') ? null : 'Nomor rekening 10-16 angka',
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _setuju,
              onChanged: (v) => setState(() => _setuju = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                  'Saya setuju data ini diteruskan ke BRI untuk pendaftaran merchant QRIS dan verifikasi identitas.',
                  style: TextStyle(fontSize: 12.5, height: 1.4)),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _mengirim ? null : _ajukan,
              style: FilledButton.styleFrom(backgroundColor: Warna.qris, minimumSize: const Size.fromHeight(48)),
              icon: _mengirim
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Ajukan ke BRI'),
            ),
            const SizedBox(height: 14),
            const CatatanDemo('Alur kerja sama: VoKas meneruskan pengajuan, BRI yang memverifikasi KTP dan rekening. '
                'Pada demo, verifikasi BRI disimulasikan dan selesai dalam sekitar 3 menit.'),
          ]),
        ),
      ];

  // ---------------- pelacakan status ----------------

  List<Widget> _lacak(Map<String, dynamic> s) {
    final aktif = s['status'] == 'AKTIF';
    final tahap = ((s['tahap'] as List?) ?? []).cast<Map<String, dynamic>>();
    return [
      Kartu(
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: aktif ? Warna.olive : Warna.qris, borderRadius: BorderRadius.circular(12)),
            child: Icon(aktif ? Icons.verified_rounded : Icons.hourglass_top_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(aktif ? 'QRIS BRI aktif' : (s['status'] == 'VERIFIKASI' ? 'Sedang diverifikasi BRI' : 'Pengajuan terkirim'),
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              Text('No. pengajuan ${s['referensi']}', style: const TextStyle(fontSize: 12.5, color: Warna.redup)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Kartu(
        child: Column(children: [
          for (var i = 0; i < tahap.length; i++) _BarisTahap(tahap[i], terakhir: i == tahap.length - 1),
        ]),
      ),
      if (aktif) ...[
        const SizedBox(height: 14),
        Kartu(
          warna: Colors.white,
          child: Column(children: [
            Text('${s['namaUsaha']}', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('NMID ${s['nmid']}', style: const TextStyle(color: Warna.redup, fontSize: 12.5)),
            const SizedBox(height: 12),
            QrImageView(
              data: 'VOKAS-DEMO-QRIS:${s['nmid']}',
              size: 200,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Warna.tinta),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Warna.tinta),
            ),
            const SizedBox(height: 8),
            Text('Dana masuk ke ${s['jenisRekening'] ?? 'rekening BRI'} ****${s['rekeningAkhir']}',
                style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 6),
            const Text('Contoh tampilan. QRIS asli diterbitkan BRI setelah verifikasi.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Warna.redup)),
          ]),
        ),
      ],
      const SizedBox(height: 14),
      if (!aktif)
        const CatatanDemo('Status diperbarui otomatis. Pada demo, verifikasi BRI disimulasikan dan selesai sekitar 3 menit.')
      else
        TextButton(onPressed: _ulang, child: const Text('Ulangi pengajuan (demo)')),
    ];
  }
}

class _BarisTahap extends StatelessWidget {
  const _BarisTahap(this.t, {required this.terakhir});
  final Map<String, dynamic> t;
  final bool terakhir;

  @override
  Widget build(BuildContext context) {
    final selesai = t['selesai'] == true;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(shape: BoxShape.circle, color: selesai ? Warna.olive : Warna.garis),
          child: Icon(selesai ? Icons.check_rounded : Icons.more_horiz_rounded, size: 16, color: Colors.white),
        ),
        if (!terakhir) Container(width: 2, height: 42, color: selesai ? Warna.olive : Warna.garis),
      ]),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 3, bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t['judul']}', style: TextStyle(fontWeight: FontWeight.w600, color: selesai ? Warna.tinta : Warna.redup)),
            const SizedBox(height: 2),
            Text('${t['keterangan']}', style: const TextStyle(fontSize: 12.5, color: Warna.redup, height: 1.4)),
          ]),
        ),
      ),
    ]);
  }
}

/// Pilihan ringkas berbentuk chip (pengganti dropdown yang menu-nya melebar penuh layar).
class _Pilihan extends StatelessWidget {
  const _Pilihan({required this.judul, required this.opsi, required this.nilai, required this.onPilih});
  final String judul;
  final List<String> opsi;
  final String nilai;
  final ValueChanged<String> onPilih;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(judul, style: const TextStyle(fontSize: 12.5, color: Warna.redup, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final o in opsi)
              ChoiceChip(
                label: Text(o, style: const TextStyle(fontSize: 12.5)),
                selected: o == nilai,
                onSelected: (_) => onPilih(o),
                selectedColor: Warna.khaki,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: Warna.garis),
              ),
          ]),
        ]),
      );
}
