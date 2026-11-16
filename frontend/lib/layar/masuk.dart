import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../main.dart';
import '../masuk_google.dart';
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

bool emailValid(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

/// Kode demo untuk akun lama yang belum punya email (OTP WhatsApp belum aktif).
const kodeDemo = '123456';

enum _Tahap { form, kode, buatPin, ulangPin, pin, lupaKode, lupaBuat, lupaUlang }

/// Auth VoKas:
/// - Daftar: data usaha + nomor WA + email -> kode dari email -> buat PIN. Atau daftar dengan Google (tanpa kode).
/// - Masuk: email ATAU nomor WA -> PIN (dicek di server, berlaku di HP mana pun).
/// - Lupa PIN: kode dikirim ke email terdaftar (atau Google) -> PIN baru.
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
  final _email = TextEditingController();
  final _identitas = TextEditingController();

  String _noWa = '';
  String _kode = '';
  String _pinBaru = '';
  String _emailSamar = '';
  bool _lupaDemo = false;
  ({String? idToken, String? accessToken})? _google;
  bool _lewatBri = false; // true bila daftar/masuk lewat "Lanjut dengan BRImo"

  void _pesan(String s) => tampilPesan(context, s);

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

  Future<T?> _jalankan<T>(Future<T> Function() f) async {
    setState(() => _sibuk = true);
    try {
      return await f();
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  String get _identitasTampil {
    final s = _identitas.text.trim();
    if (s.contains('@')) {
      final at = s.indexOf('@');
      return at <= 1 ? s : '${s[0]}${'*' * (at - 1).clamp(1, 5).toInt()}${s.substring(at)}';
    }
    return samarkanWa(normalisasiWa(s) ?? s);
  }

  // ---------------- formulir ----------------

  Future<void> _kirimForm() async {
    if (!_form.currentState!.validate()) return;
    if (_daftar) {
      _noWa = normalisasiWa(_wa.text)!;
      if (_google != null) {
        _ke(_Tahap.buatPin); // email sudah dibuktikan lewat Google
        return;
      }
      try {
        final r = await _jalankan(() => Api.kirimKode(_email.text.trim(), 'DAFTAR'));
        _emailSamar = '${r?['email'] ?? _email.text.trim()}';
        _ke(_Tahap.kode);
      } catch (e) {
        _pesan(pesanGalat(e));
      }
    } else {
      _salahPin = 0;
      _ke(_Tahap.pin);
    }
  }

  // ---------------- kode dari email ----------------

  void _kodeDiisi(String kode) {
    _kode = kode;
    _ke(_tahap == _Tahap.kode ? _Tahap.buatPin : _Tahap.lupaBuat);
  }

  Future<void> _kirimUlangKode() async {
    try {
      if (_tahap == _Tahap.kode) {
        await Api.kirimKode(_email.text.trim(), 'DAFTAR');
      } else {
        await Api.kirimKode(_identitas.text.trim(), 'LUPA_PIN');
      }
      _pesan('Kode baru sudah dikirim ke email.');
    } catch (e) {
      _pesan(pesanGalat(e));
    }
  }

  // ---------------- PIN ----------------

  void _pinDibuat(String pin) {
    if (RegExp(r'^(\d)\1{5}$').hasMatch(pin) || '0123456789'.contains(pin) || '9876543210'.contains(pin)) {
      _gagal();
      _pesan('PIN terlalu mudah ditebak. Hindari angka sama atau berurutan.');
      return;
    }
    _pinBaru = pin;
    _ke(_tahap == _Tahap.buatPin ? _Tahap.ulangPin : _Tahap.lupaUlang);
  }

  Future<void> _pinDiulang(String pin) async {
    final lupa = _tahap == _Tahap.lupaUlang;
    if (pin != _pinBaru) {
      _gagal();
      _pesan('PIN tidak sama. Buat ulang PIN-mu.');
      Future.delayed(const Duration(milliseconds: 500), () => _ke(lupa ? _Tahap.lupaBuat : _Tahap.buatPin));
      return;
    }
    if (lupa) {
      await _aturPinBaru(pin);
    } else {
      await _daftarAkun(pin);
    }
  }

  Future<void> _daftarAkun(String pin) async {
    try {
      final p = await _jalankan(() => Api.daftarAkun(
            nama: _nama.text.trim(),
            namaUsaha: _usaha.text.trim(),
            noWa: _noWa,
            email: _google == null ? _email.text.trim() : null,
            kode: _google == null ? _kode : null,
            googleIdToken: _google?.idToken,
            googleAccessToken: _google?.accessToken,
            pin: pin,
          ));
      await _selesai(p!, pin);
    } on ApiGagal catch (e) {
      _pesan(e.pesan);
      _ke(e.pesan.startsWith('Kode') ? _Tahap.kode : _Tahap.form);
    } catch (e) {
      _pesan(pesanGalat(e));
      _ke(_Tahap.form);
    }
  }

  Future<void> _pinMasuk(String pin) async {
    try {
      final p = await _jalankan(() => Api.masukAkun(_identitas.text.trim(), pin));
      await _selesai(p!, pin);
    } on ApiGagal catch (e) {
      if (e.status == 401) {
        _salahPin++;
        _gagal();
        _pesan(_salahPin >= 3 ? 'PIN salah. Lupa PIN? Atur ulang lewat email.' : 'PIN salah.');
      } else if (e.pesan == 'PIN_BELUM_ADA') {
        _pesan('Akun ini belum punya PIN. Buat PIN dulu.');
        await _mulaiLupa();
      } else {
        _pesan(e.pesan);
        if (e.status == 404) _ke(_Tahap.form);
      }
    } catch (e) {
      _pesan(pesanGalat(e));
    }
  }

  // ---------------- lupa PIN ----------------

  Future<void> _mulaiLupa() async {
    if (_google != null) {
      _ke(_Tahap.lupaBuat); // kepemilikan akun sudah dibuktikan lewat Google
      return;
    }
    try {
      final r = await _jalankan(() => Api.kirimKode(_identitas.text.trim(), 'LUPA_PIN'));
      _emailSamar = '${r?['email'] ?? ''}';
      _lupaDemo = false;
      _ke(_Tahap.lupaKode);
    } on ApiGagal catch (e) {
      if (e.pesan == 'AKUN_TANPA_EMAIL') {
        _lupaDemo = true;
        _ke(_Tahap.lupaKode);
      } else {
        _pesan(e.pesan);
      }
    } catch (e) {
      _pesan(pesanGalat(e));
    }
  }

  Future<void> _aturPinBaru(String pin) async {
    try {
      final p = await _jalankan(() => Api.lupaPin(_identitas.text.trim(), pin,
          kode: _google == null ? _kode : null, googleIdToken: _google?.idToken, googleAccessToken: _google?.accessToken));
      _pesan('PIN baru tersimpan.');
      await _selesai(p!, pin);
    } on ApiGagal catch (e) {
      _pesan(e.pesan);
      _ke(e.pesan.startsWith('Kode') ? _Tahap.lupaKode : _Tahap.form);
    } catch (e) {
      _pesan(pesanGalat(e));
      _ke(_Tahap.form);
    }
  }

  Future<void> _selesai(Map<String, dynamic> p, String pin) async {
    await Sesi.simpanPedagang(p);
    // salinan PIN di perangkat untuk konfirmasi cepat di dalam aplikasi (keluar, hapus data, dsb.)
    await Sesi.simpanPin('${p['noWa']}', pin);
    if (_lewatBri) await Sesi.simpanRekening('4521', '${p['nama'] ?? ''}'.toUpperCase());
    if (mounted) lanjut(context);
  }

  // ---------------- Google / BRImo ----------------

  Future<void> _lewatGoogle() async {
    if (!MasukGoogle.tersedia) {
      _pesan('Login Google belum diaktifkan di versi ini. Pakai email atau nomor WhatsApp dulu.');
      return;
    }
    try {
      final t = await _jalankan(MasukGoogle.pilihAkun);
      if (t == null) return;
      final r = await _jalankan(() => Api.masukGoogle(t.idToken, t.accessToken));
      _google = t;
      if (r?['terdaftar'] == true) {
        final p = (r!['pedagang'] as Map).cast<String, dynamic>();
        _identitas.text = '${p['email'] ?? p['noWa']}';
        setState(() => _daftar = false);
        if (p['punyaPin'] == true) {
          _salahPin = 0;
          _ke(_Tahap.pin);
        } else {
          _pesan('Buat PIN untuk akunmu.');
          _ke(_Tahap.lupaBuat);
        }
      } else {
        setState(() {
          _daftar = true;
          _email.text = '${r?['email'] ?? ''}';
          if (_nama.text.trim().isEmpty) _nama.text = '${r?['nama'] ?? ''}';
        });
        _pesan('Akun Google tersambung. Lengkapi nama usaha dan nomor WhatsApp.');
      }
    } catch (e) {
      _google = null;
      _pesan(pesanGalat(e));
    }
  }

  Future<void> _lewatBrimo() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Warna.latar,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _LembarBrimo(nama: _nama.text.trim()),
    );
    if (ok != true) return;
    setState(() => _lewatBri = true);
    _pesan('Izin BRI diberikan (simulasi). Lengkapi data lalu lanjutkan.');
  }

  // ---------------- tampilan ----------------

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _tahap == _Tahap.form,
        onPopInvoked: (sudah) {
          if (!sudah) _ke(_Tahap.form);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
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
        _Tahap.kode => _layarKode(
            judul: 'Cek email kamu',
            sub: 'Kode 6 angka dikirim ke $_emailSamar. Cek juga folder Spam atau Promosi.',
            sembunyi: false,
            onSelesai: _kodeDiisi,
            bawah: _KirimUlang(onKirim: _kirimUlangKode),
          ),
        _Tahap.buatPin => _layarKode(
            judul: 'Buat PIN VoKas',
            sub: '6 angka untuk masuk ke VoKas. Jangan pakai tanggal lahir atau angka berurutan.',
            demo: 'PIN ini khusus VoKas, bukan PIN BRImo atau ATM. PIN disimpan dalam bentuk hash di server.',
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
            sub: 'Masuk sebagai $_identitasTampil',
            sembunyi: true,
            onSelesai: _pinMasuk,
            bawah: TextButton(onPressed: _sibuk ? null : _mulaiLupa, child: const Text('Lupa PIN?')),
          ),
        _Tahap.lupaKode => _layarKode(
            judul: 'Atur ulang PIN',
            sub: _lupaDemo
                ? 'Akun ini belum punya email. Mode demo: masukkan kode $kodeDemo.'
                : 'Kode 6 angka dikirim ke $_emailSamar. Cek juga folder Spam.',
            demo: _lupaDemo ? 'Setelah masuk, tambahkan email di menu Laporan supaya lupa PIN bisa lewat email.' : null,
            sembunyi: false,
            onSelesai: _kodeDiisi,
            bawah: _lupaDemo ? null : _KirimUlang(onKirim: _kirimUlangKode),
          ),
        _Tahap.lupaBuat => _layarKode(
            judul: 'Buat PIN baru',
            sub: '6 angka. Hindari angka sama atau berurutan.',
            sembunyi: true,
            onSelesai: _pinDibuat,
          ),
        _Tahap.lupaUlang => _layarKode(
            judul: 'Ulangi PIN baru',
            sub: 'Masukkan sekali lagi untuk konfirmasi.',
            sembunyi: true,
            onSelesai: _pinDiulang,
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
              _daftar ? 'Kode verifikasi dikirim ke email kamu.' : 'Masuk dengan email atau nomor WhatsApp, lalu PIN.',
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
            TextFormField(
              controller: _wa,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
              decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp', hintText: '0812xxxxxxx', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) => normalisasiWa(v ?? '') == null ? 'Nomor WhatsApp tidak valid' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              readOnly: _google != null,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'nama@gmail.com',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
                suffixIcon: _google != null ? const Icon(Icons.verified_rounded, color: Warna.olive) : null,
                helperText: _google != null ? 'Terverifikasi lewat Google' : 'Untuk kode verifikasi, lupa PIN, dan laporan',
              ),
              validator: (v) => emailValid(v ?? '') ? null : 'Email tidak valid',
            ),
          ] else
            TextFormField(
              controller: _identitas,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email atau nomor WhatsApp',
                  hintText: 'nama@gmail.com / 0812xxxxxxx',
                  prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (v) {
                final s = (v ?? '').trim();
                return (s.contains('@') ? emailValid(s) : normalisasiWa(s) != null) ? null : 'Isi email atau nomor WhatsApp yang valid';
              },
            ),
          if (_lewatBri) ...[
            const SizedBox(height: 10),
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.check_circle_rounded, size: 16, color: Warna.olive),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text('Rekening BRI ****4521 akan langsung tersambung ke akun ini', style: TextStyle(fontSize: 12.5)),
              ),
            ]),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sibuk ? null : _kirimForm,
            child: _sibuk
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(_daftar ? (_google != null ? 'Lanjut buat PIN' : 'Kirim kode ke email') : 'Lanjut'),
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
            onTap: _sibuk ? () {} : _lewatGoogle,
            ikon: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Warna.garis)),
              alignment: Alignment.center,
              child: Text('G', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Warna.qris)),
            ),
            label: 'Lanjut dengan Google',
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 18),
          const Text(
            'Dengan mendaftar, kamu menyetujui Syarat & Ketentuan dan Kebijakan Privasi VoKas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Warna.redup, height: 1.5),
          ),
          const SizedBox(height: 12),
          const CatatanDemo('Akun juri: 0812 0000 2026, PIN 202611 (data 90 hari sudah terisi). '
              'Login BRImo masih simulasi sampai ada kerja sama penautan akun lewat BRIAPI.'),
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
  const _LembarBrimo({required this.nama});
  final String nama;

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
                _BarisData('Nama', widget.nama.isEmpty ? 'Sesuai data rekeningmu' : widget.nama.toUpperCase()),
                const _BarisData('Rekening', '****4521 (Tabungan)'),
                const _BarisData('Akses', 'Mutasi QRIS dan transfer'),
                const SizedBox(height: 16),
                const CatatanDemo('Simulasi. Versi resmi mengambil nama dan rekening langsung dari BRI, '
                    'jadi namanya selalu sama dengan pemilik akun.'),
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
