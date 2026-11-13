import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../main.dart';
import '../sesi.dart';
import '../tema.dart';
import '../widget/papan_pin.dart';

/// 0812-3456-789 / +62812... / 62812... -> 62812...
String? normalisasiWa(String s) {
  var d = s.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0')) d = '62${d.substring(1)}';
  if (d.startsWith('8')) d = '62$d';
  return RegExp(r'^62\d{8,13}$').hasMatch(d) ? d : null;
}

const kodeDemo = '123456';

enum _Tahap { form, otp, buatPin, ulangPin, pin }

/// Alur auth versi demo: data -> OTP WhatsApp -> buat PIN (daftar) atau nomor -> PIN (masuk).
/// Versi resmi: OTP dikirim lewat WhatsApp Cloud API, PIN di-hash di server, sesi memakai Supabase Auth (JWT).
class LayarMasuk extends StatefulWidget {
  const LayarMasuk({super.key});

  @override
  State<LayarMasuk> createState() => _LayarMasukState();
}

class _LayarMasukState extends State<LayarMasuk> {
  _Tahap _tahap = _Tahap.form;
  bool _daftar = true;
  bool _sibuk = false;
  bool _salah = false;
  int _salahPin = 0;
  final _form = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _usaha = TextEditingController();
  final _wa = TextEditingController();

  String _noWa = '';
  Map<String, dynamic>? _pedagang;
  String _pinBaru = '';
  String? _briNama; // terisi bila daftar lewat "Lanjut dengan BRImo"

  void _pesan(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  void _ke(_Tahap t) => setState(() {
        _tahap = t;
        _salah = false;
      });

  void _gagal() {
    setState(() => _salah = true);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _salah = false);
    });
  }

  // ---------------- tahap 1: formulir ----------------

  Future<void> _kirimForm() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sibuk = true);
    _noWa = normalisasiWa(_wa.text)!;
    try {
      final ada = await _cari(_noWa);
      if (_daftar && ada != null) {
        // nomor sudah terdaftar: langsung arahkan ke masuk
        _daftar = false;
        _pesan('Nomor ini sudah terdaftar. Masuk dengan PIN-mu.');
      }
      if (!_daftar && ada == null) {
        _pesan('Nomor belum terdaftar. Pilih "Daftar" dulu.');
        return;
      }
      _pedagang = ada;
      _ke(!_daftar && Sesi.punyaPin(_noWa) ? _Tahap.pin : _Tahap.otp);
    } catch (e) {
      _pesan(pesanGalat(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<Map<String, dynamic>?> _cari(String wa) async {
    try {
      return await Api.masuk(wa);
    } on ApiGagal catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  // ---------------- tahap 2: OTP ----------------

  Future<void> _otpMasuk(String kode) async {
    if (kode != kodeDemo) {
      _gagal();
      return;
    }
    if (_pedagang == null) {
      setState(() => _sibuk = true);
      try {
        _pedagang = await Api.daftar(nama: _nama.text.trim(), namaUsaha: _usaha.text.trim(), noWa: _noWa);
      } catch (e) {
        _pesan(pesanGalat(e));
        _ke(_Tahap.form);
        return;
      } finally {
        if (mounted) setState(() => _sibuk = false);
      }
    }
    _ke(_Tahap.buatPin);
  }

  // ---------------- tahap 3: PIN ----------------

  void _pinDibuat(String pin) {
    if (RegExp(r'^(\d)\1{5}$').hasMatch(pin) || '0123456789'.contains(pin) || '9876543210'.contains(pin)) {
      _gagal();
      _pesan('PIN terlalu mudah ditebak. Hindari angka sama atau berurutan.');
      return;
    }
    _pinBaru = pin;
    _ke(_Tahap.ulangPin);
  }

  Future<void> _pinDiulang(String pin) async {
    if (pin != _pinBaru) {
      _gagal();
      _pesan('PIN tidak sama. Buat ulang PIN-mu.');
      Future.delayed(const Duration(milliseconds: 500), () => _ke(_Tahap.buatPin));
      return;
    }
    await Sesi.simpanPin(_noWa, pin);
    await _selesai();
  }

  Future<void> _pinMasuk(String pin) async {
    if (!Sesi.cekPin(_noWa, pin)) {
      _salahPin++;
      _gagal();
      if (_salahPin >= 3) _pesan('PIN salah 3 kali. Pakai "Lupa PIN?" untuk atur ulang lewat OTP.');
      return;
    }
    await _selesai();
  }

  Future<void> _selesai() async {
    await Sesi.simpanPedagang(_pedagang!);
    if (_briNama != null) await Sesi.simpanRekening('4521', _briNama!);
    if (mounted) lanjut(context);
  }

  // ---------------- masuk dengan BRImo / Google (simulasi) ----------------

  Future<void> _lewatBrimo() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Warna.latar,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _LembarBrimo(),
    );
    if (ok != true) return;
    setState(() {
      _daftar = true;
      _briNama = 'Sri Wahyuni';
      _nama.text = 'Sri Wahyuni';
    });
    _pesan('Data dari BRI terisi (simulasi). Lengkapi nomor WhatsApp.');
  }

  Future<void> _lewatGoogle() async {
    final nama = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _LembarGoogle(),
    );
    if (nama == null) return;
    setState(() {
      _daftar = true;
      _nama.text = nama;
    });
    _pesan('Nama terisi dari akun Google (simulasi). Lengkapi nomor WhatsApp.');
  }

  // ---------------- tampilan ----------------

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _tahap == _Tahap.form,
        onPopInvoked: (sudah) {
          if (!sudah) _ke(_Tahap.form);
        },
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                          position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(a), child: c),
                    ),
                    child: KeyedSubtree(key: ValueKey(_tahap), child: _isi()),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _isi() => switch (_tahap) {
        _Tahap.form => _formulir(),
        _Tahap.otp => _layarKode(
            judul: 'Masukkan kode verifikasi',
            sub: 'Kode 6 digit dikirim lewat WhatsApp ke ${samarkanWa(_noWa)}.',
            demo: 'Mode demo: pakai kode $kodeDemo. Versi resmi mengirim kode lewat WhatsApp Cloud API '
                'dan kode berlaku 5 menit.',
            sembunyi: false,
            onSelesai: _otpMasuk,
            bawah: _KirimUlang(onKirim: () => _pesan('Kode baru dikirim (simulasi). Kode demo: $kodeDemo')),
          ),
        _Tahap.buatPin => _layarKode(
            judul: 'Buat PIN VoKas',
            sub: '6 angka untuk membuka aplikasi. Jangan pakai tanggal lahir atau angka berurutan.',
            demo: 'PIN ini khusus VoKas, bukan PIN BRImo atau ATM. Versi resmi menyimpan PIN ter-hash di server.',
            sembunyi: true,
            onSelesai: _pinDibuat,
          ),
        _Tahap.ulangPin => _layarKode(
            judul: 'Ulangi PIN',
            sub: 'Masukkan sekali lagi untuk konfirmasi.',
            sembunyi: true,
            onSelesai: _pinDiulang,
          ),
        _Tahap.pin => _layarKode(
            judul: 'Masukkan PIN',
            sub: 'Masuk sebagai ${samarkanWa(_noWa)}',
            sembunyi: true,
            onSelesai: _pinMasuk,
            bawah: TextButton(onPressed: () => _ke(_Tahap.otp), child: const Text('Lupa PIN?')),
          ),
      };

  Widget _layarKode({
    required String judul,
    required String sub,
    String? demo,
    required bool sembunyi,
    required ValueChanged<String> onSelesai,
    Widget? bawah,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _sibuk ? null : () => _ke(_Tahap.form),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Kembali',
          ),
        ),
        const SizedBox(height: 8),
        Text(judul, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(sub, style: const TextStyle(color: Warna.redup, height: 1.5)),
        const SizedBox(height: 32),
        if (_sibuk)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else
          PapanPin(sembunyi: sembunyi, salah: _salah, onSelesai: onSelesai),
        if (bawah != null) ...[const SizedBox(height: 8), Center(child: bawah)],
        if (demo != null) ...[const SizedBox(height: 20), CatatanDemo(demo)],
      ]);

  Widget _formulir() => Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
          Center(child: SvgPicture.asset('assets/vokas_ikon.svg', width: 64)),
          const SizedBox(height: 14),
          Text(_daftar ? 'Buat akun VoKas' : 'Selamat datang lagi',
              textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 23, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              _daftar
                  ? 'Pakai nomor WhatsApp yang dipakai untuk kirim catatan.'
                  : 'Masuk dengan nomor WhatsApp dan PIN-mu.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Warna.redup, fontSize: 13.5)),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Daftar')),
              ButtonSegment(value: false, label: Text('Masuk')),
            ],
            selected: {_daftar},
            onSelectionChanged: (s) => setState(() => _daftar = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 18),
          if (_daftar) ...[
            TextFormField(
              controller: _nama,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama kamu', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usaha,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nama usaha', hintText: 'Cilok & Cireng Bu Sri', prefixIcon: Icon(Icons.storefront_outlined)),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _wa,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
            decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp', hintText: '0812xxxxxxx', prefixIcon: Icon(Icons.phone_outlined)),
            validator: (v) => normalisasiWa(v ?? '') == null ? 'Nomor WhatsApp tidak valid' : null,
          ),
          if (_briNama != null) ...[
            const SizedBox(height: 10),
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.check_circle_rounded, size: 16, color: Warna.olive),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text('Rekening BRI ****4521 akan langsung tersambung', style: TextStyle(fontSize: 12.5)),
              ),
            ]),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sibuk ? null : _kirimForm,
            child: _sibuk
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(_daftar ? 'Daftar' : 'Lanjut'),
          ),
          const SizedBox(height: 20),
          const Row(children: [
            Expanded(child: Divider(color: Warna.garis)),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('atau', style: TextStyle(color: Warna.redup, fontSize: 12.5))),
            Expanded(child: Divider(color: Warna.garis)),
          ]),
          const SizedBox(height: 16),
          _TombolSosial(
            onTap: _lewatBrimo,
            ikon: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: Warna.qris, borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 15),
            ),
            label: 'Lanjut dengan BRImo',
          ),
          const SizedBox(height: 10),
          _TombolSosial(
            onTap: _lewatGoogle,
            ikon: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Warna.garis)),
              alignment: Alignment.center,
              child: Text('G', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Warna.qris)),
            ),
            label: 'Lanjut dengan Google',
          ),
          const SizedBox(height: 18),
          const Text(
            'Dengan mendaftar, kamu menyetujui Syarat & Ketentuan dan Kebijakan Privasi VoKas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Warna.redup, height: 1.5),
          ),
          const SizedBox(height: 12),
          const CatatanDemo('Mode demo: login BRImo dan Google masih simulasi. Versi resmi memakai Google Sign-In '
              '(OAuth) dan penautan akun resmi lewat BRIAPI setelah ada kerja sama dengan BRI.'),
        ]),
      );
}

class _TombolSosial extends StatelessWidget {
  const _TombolSosial({required this.onTap, required this.ikon, required this.label});
  final VoidCallback onTap;
  final Widget ikon;
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Warna.kartu,
          side: const BorderSide(color: Warna.garis),
          foregroundColor: Warna.tinta,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ikon,
          const SizedBox(width: 12),
          Text(label),
        ]),
      );
}

class _KirimUlang extends StatefulWidget {
  const _KirimUlang({required this.onKirim});
  final VoidCallback onKirim;

  @override
  State<_KirimUlang> createState() => _KirimUlangState();
}

class _KirimUlangState extends State<_KirimUlang> {
  int _sisa = 30;

  @override
  void initState() {
    super.initState();
    _hitung();
  }

  void _hitung() async {
    while (_sisa > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _sisa--);
    }
  }

  @override
  Widget build(BuildContext context) => _sisa > 0
      ? Text('Kirim ulang kode dalam 0:${_sisa.toString().padLeft(2, '0')}',
          style: const TextStyle(color: Warna.redup, fontSize: 13))
      : TextButton(
          onPressed: () {
            widget.onKirim();
            setState(() => _sisa = 30);
            _hitung();
          },
          child: const Text('Kirim ulang kode'));
}

/// Simulasi layar izin dari BRImo.
class _LembarBrimo extends StatefulWidget {
  const _LembarBrimo();

  @override
  State<_LembarBrimo> createState() => _LembarBrimoState();
}

class _LembarBrimoState extends State<_LembarBrimo> {
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _memuat = false);
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: _memuat
            ? const SizedBox(
                height: 220,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Membuka BRImo... (simulasi)', style: TextStyle(color: Warna.redup)),
                ]),
              )
            : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Warna.qris, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.account_balance_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('VoKas meminta akses ke data BRI-mu',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                  ),
                ]),
                const SizedBox(height: 18),
                const _BarisData('Nama', 'SRI WAHYUNI'),
                const _BarisData('Rekening', '****4521 (Tabungan)'),
                const _BarisData('Akses', 'Mutasi QRIS dan transfer'),
                const SizedBox(height: 16),
                const CatatanDemo('Simulasi. Data di atas adalah data contoh, bukan data BRI sungguhan.'),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: Warna.qris),
                  child: const Text('Izinkan'),
                ),
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
              ]),
      );
}

class _BarisData extends StatelessWidget {
  const _BarisData(this.label, this.nilai);
  final String label, nilai;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Warna.garis))),
        child: Row(children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Warna.redup, fontSize: 13))),
          Expanded(child: Text(nilai, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Simulasi pemilih akun Google.
class _LembarGoogle extends StatelessWidget {
  const _LembarGoogle();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Pilih akun', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const Text('untuk melanjutkan ke VoKas',
              textAlign: TextAlign.center, style: TextStyle(color: Warna.redup, fontSize: 13)),
          const SizedBox(height: 16),
          ListTile(
            onTap: () => Navigator.of(context).pop('Sri Wahyuni'),
            leading: const CircleAvatar(backgroundColor: Warna.khaki, child: Text('S', style: TextStyle(color: Warna.oliveTua))),
            title: const Text('Sri Wahyuni'),
            subtitle: const Text('akun.demo@gmail.com'),
          ),
          const Divider(color: Warna.garis),
          ListTile(
            onTap: () => Navigator.of(context).pop(''),
            leading: const CircleAvatar(backgroundColor: Warna.latar, child: Icon(Icons.person_add_alt_1_outlined, color: Warna.redup)),
            title: const Text('Gunakan akun lain'),
          ),
          const SizedBox(height: 8),
          const CatatanDemo('Simulasi. Versi resmi memakai Google Sign-In, VoKas hanya menerima nama dan email.'),
        ]),
      );
}
