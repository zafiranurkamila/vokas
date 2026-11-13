import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../sesi.dart';
import '../tema.dart';
import '../widget/papan_pin.dart';
import 'masuk.dart' show kodeDemo;

enum _Tahap { izin, rekening, otp, berhasil }

/// Penautan rekening BRI, pola umum penautan rekening bank di aplikasi lain:
/// izin -> nomor rekening + cek nama pemilik -> OTP dari bank -> berhasil.
/// VoKas tidak pernah meminta user ID, password, atau PIN BRImo.
/// Demo: semuanya simulasi. Versi resmi: penautan lewat BRIAPI (account linking + OTP dari BRI) setelah kerja sama.
class LayarSambungBri extends StatefulWidget {
  const LayarSambungBri({super.key, this.dariProfil = false});

  /// true: dibuka dari Profil, selesai -> kembali (pop). false: bagian alur awal, selesai -> beranda.
  final bool dariProfil;

  @override
  State<LayarSambungBri> createState() => _LayarSambungBriState();
}

class _LayarSambungBriState extends State<LayarSambungBri> {
  _Tahap _tahap = _Tahap.izin;
  final _form = GlobalKey<FormState>();
  final _rek = TextEditingController();
  final _hp = TextEditingController();
  String? _namaPemilik;
  bool _mengecek = false;
  bool _setujuSk = false;
  bool _salah = false;

  String get _norek => _rek.text.replaceAll(RegExp(r'\D'), '');

  @override
  void initState() {
    super.initState();
    final wa = Sesi.noWa;
    if (wa.startsWith('62')) _hp.text = '0${wa.substring(2)}';
  }

  void _ke(_Tahap t) => setState(() => _tahap = t);

  void _mundur() {
    switch (_tahap) {
      case _Tahap.izin:
        Navigator.of(context).pop(false);
      case _Tahap.rekening:
        _ke(_Tahap.izin);
      case _Tahap.otp:
        _ke(_Tahap.rekening);
      case _Tahap.berhasil:
        break;
    }
  }

  Future<void> _selesai(bool sambung) async {
    if (!sambung) await Sesi.pilihBri(false);
    if (!mounted) return;
    if (widget.dariProfil) {
      Navigator.of(context).pop(sambung);
    } else {
      lanjut(context);
    }
  }

  Future<void> _cekRekening() async {
    if (_norek.length != 15) {
      _form.currentState!.validate();
      return;
    }
    setState(() {
      _mengecek = true;
      _namaPemilik = null;
    });
    await Future.delayed(const Duration(milliseconds: 1000)); // simulasi inquiry nama ke bank
    if (!mounted) return;
    final nama = (Sesi.nama.isEmpty ? 'Pemilik Rekening' : Sesi.nama).toUpperCase();
    setState(() {
      _mengecek = false;
      _namaPemilik = nama;
    });
  }

  void _kirimOtp() {
    if (!_form.currentState!.validate()) return;
    if (_namaPemilik == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cek rekening dulu untuk melihat nama pemilik.')));
      return;
    }
    if (!_setujuSk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setujui syarat penautan rekening dulu.')));
      return;
    }
    _ke(_Tahap.otp);
  }

  Future<void> _otp(String kode) async {
    if (kode != kodeDemo) {
      setState(() => _salah = true);
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _salah = false);
      });
      return;
    }
    await Sesi.simpanRekening(_norek, _namaPemilik!);
    _ke(_Tahap.berhasil);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: _tahap == _Tahap.izin && !widget.dariProfil
            ? null
            : AppBar(
                leading: _tahap == _Tahap.berhasil
                    ? const SizedBox()
                    : IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: _mundur,
                      ),
              ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: KeyedSubtree(
                    key: ValueKey(_tahap),
                    child: switch (_tahap) {
                      _Tahap.izin => _izin(),
                      _Tahap.rekening => _rekening(),
                      _Tahap.otp => _layarOtp(),
                      _Tahap.berhasil => _berhasil(),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  // ---------------- 1. izin ----------------

  Widget _izin() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        const _Hubungan(),
        const SizedBox(height: 28),
        Text('Hubungkan rekening BRI', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Pembayaran QRIS dan transfer masuk akan tercatat sendiri, jadi kamu tidak perlu mengetik ulang.',
            style: TextStyle(color: Warna.redup, height: 1.5, fontSize: 14)),
        const SizedBox(height: 24),
        const _Judul('VOKAS AKAN BISA'),
        const _Izin('Melihat mutasi QRIS masuk', 'Untuk dicatat sebagai penjualan'),
        const _Izin('Melihat transfer masuk dan keluar', 'Kamu yang memutuskan: uang usaha atau bukan'),
        const SizedBox(height: 18),
        const _Judul('VOKAS TIDAK AKAN'),
        const _Izin('Meminta user ID, password, atau PIN BRImo', null),
        const _Izin('Memindahkan uang dari rekeningmu', null),
        const SizedBox(height: 28),
        FilledButton(onPressed: () => _ke(_Tahap.rekening), child: const Text('Lanjutkan')),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: TextButton(
              onPressed: () => _selesai(false),
              child: const Text('Nanti saja', style: TextStyle(fontWeight: FontWeight.w600))),
        ),
      ]);

  // ---------------- 2. rekening ----------------

  Widget _rekening() => Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Data rekening', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Pakai rekening BRI yang dipakai untuk usaha dan menerima QRIS.',
              style: TextStyle(color: Warna.redup, height: 1.5)),
          const SizedBox(height: 22),
          TextFormField(
            controller: _rek,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15), _FormatRek()],
            onChanged: (_) => setState(() => _namaPemilik = null),
            decoration: InputDecoration(
              labelText: 'Nomor rekening BRI',
              hintText: '0000-00-000000-00-0',
              helperText: '15 digit, ada di buku tabungan atau aplikasi BRImo',
              prefixIcon: const Icon(Icons.credit_card_rounded),
              suffixIcon: _mengecek
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : TextButton(onPressed: _cekRekening, child: const Text('Cek')),
            ),
            validator: (_) => _norek.length != 15 ? 'Nomor rekening BRI harus 15 digit' : null,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _namaPemilik == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Warna.kartu, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      const Icon(Icons.verified_user_rounded, color: Warna.olive),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Nama pemilik rekening', style: TextStyle(fontSize: 12, color: Warna.redup)),
                          Text(_namaPemilik!, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _hp,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Nomor HP terdaftar di BRI',
              helperText: 'Kode OTP dari BRI dikirim ke nomor ini',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
            validator: (v) => (v ?? '').length < 10 ? 'Nomor HP tidak valid' : null,
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _setujuSk,
            onChanged: (v) => setState(() => _setujuSk = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Saya pemilik rekening ini dan menyetujui syarat penautan rekening',
                style: TextStyle(fontSize: 13.5)),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _kirimOtp, child: const Text('Kirim kode OTP')),
          const SizedBox(height: 16),
          const CatatanDemo('Mode demo: nama pemilik diambil dari nama akunmu, tidak ada pengecekan ke BRI. '
              'Versi resmi memakai BRIAPI untuk cek rekening dan VoKas hanya menyimpan 4 digit terakhir.'),
        ]),
      );

  // ---------------- 3. OTP dari bank ----------------

  Widget _layarOtp() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Kode OTP dari BRI', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Masukkan kode yang dikirim BRI lewat SMS ke ${_samarHp(_hp.text)}.',
            style: const TextStyle(color: Warna.redup, height: 1.5)),
        const SizedBox(height: 32),
        PapanPin(salah: _salah, onSelesai: _otp),
        const SizedBox(height: 20),
        const CatatanDemo('Mode demo: pakai kode $kodeDemo. Kode OTP dikirim oleh BRI, bukan oleh VoKas, '
            'dan jangan pernah dibagikan ke siapa pun.'),
      ]);

  // ---------------- 4. berhasil ----------------

  Widget _berhasil() => Column(children: [
        const SizedBox(height: 40),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(color: Warna.olive, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
          ),
        ),
        const SizedBox(height: 24),
        Text('Rekening tersambung', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('BRI ****${Sesi.briRekening} a.n. ${Sesi.briNama}',
            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Mutasi QRIS dan transfer akan masuk ke catatanmu.',
            textAlign: TextAlign.center, style: TextStyle(color: Warna.redup)),
        const SizedBox(height: 32),
        FilledButton(onPressed: () => _selesai(true), child: Text(widget.dariProfil ? 'Kembali ke profil' : 'Ke beranda')),
        const SizedBox(height: 16),
        const CatatanDemo('Simulasi: belum ada mutasi sungguhan yang ditarik dari BRI.'),
      ]);

  static String _samarHp(String hp) =>
      hp.length < 8 ? hp : '${hp.substring(0, 4)}****${hp.substring(hp.length - 3)}';
}

/// 012301012345455 -> 0123-01-012345-45-5 (format nomor rekening BRI 4-2-6-2-1)
class _FormatRek extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue baru) {
    final d = baru.text.replaceAll(RegExp(r'\D'), '');
    const potong = [4, 2, 6, 2, 1];
    final b = StringBuffer();
    var i = 0;
    for (final p in potong) {
      if (i >= d.length) break;
      if (i > 0) b.write('-');
      final akhir = (i + p).clamp(0, d.length);
      b.write(d.substring(i, akhir));
      i = akhir;
    }
    final s = b.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// Logo VoKas dan ikon bank yang dihubungkan garis putus-putus.
class _Hubungan extends StatelessWidget {
  const _Hubungan();

  @override
  Widget build(BuildContext context) => Row(children: [
        SvgPicture.asset('assets/vokas_ikon.svg', width: 56, height: 56),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Expanded(child: CustomPaint(size: const Size(double.infinity, 2), painter: _GarisPutus())),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Warna.kartu, shape: BoxShape.circle),
                child: const Icon(Icons.link_rounded, size: 18, color: Warna.redup),
              ),
              Expanded(child: CustomPaint(size: const Size(double.infinity, 2), painter: _GarisPutus())),
            ]),
          ),
        ),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Warna.qris, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 28),
        ),
      ]);
}

class _GarisPutus extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Warna.garis
      ..strokeWidth = 2;
    for (double x = 0; x < s.width; x += 8) {
      c.drawLine(Offset(x, s.height / 2), Offset((x + 4).clamp(0, s.width), s.height / 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Judul extends StatelessWidget {
  const _Judul(this.teks);
  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(teks,
            style: const TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600, color: Warna.redup)),
      );
}

class _Izin extends StatelessWidget {
  const _Izin(this.judul, this.ket);
  final String judul;
  final String? ket;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Warna.garis))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(judul, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
          if (ket != null) ...[
            const SizedBox(height: 2),
            Text(ket!, style: const TextStyle(fontSize: 12.5, color: Warna.redup)),
          ],
        ]),
      );
}
