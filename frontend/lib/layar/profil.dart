import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../main.dart';
import '../sesi.dart';
import '../tema.dart';
import 'beranda.dart';
import 'sambung_bri.dart';
import '../izin.dart';
import '../widget/verifikasi_pin.dart';

class TabProfil extends StatefulWidget {
  const TabProfil({super.key, required this.onDataBerubah});
  final VoidCallback onDataBerubah;

  @override
  State<TabProfil> createState() => _TabProfilState();
}

class _TabProfilState extends State<TabProfil> {
  bool? _terpisah;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    Api.pedagang(Sesi.pedagangId!).then((p) {
      if (mounted) setState(() => _terpisah = p['rekeningTerpisah'] == true);
    }).catchError((_) {});
  }

  void _pesan(String s) => tampilPesan(context, s);

  Future<void> _ubahTerpisah(bool v) async {
    setState(() => _terpisah = v);
    try {
      await Api.ubahPedagang(Sesi.pedagangId!, {'nama': Sesi.nama, 'namaUsaha': Sesi.namaUsaha, 'rekeningTerpisah': v});
    } catch (e) {
      setState(() => _terpisah = !v);
      _pesan(pesanGalat(e));
    }
  }

  Future<void> _sambung() async {
    final ok = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const LayarSambungBri(dariProfil: true)));
    if (ok == true) setState(() {});
  }

  Future<void> _putuskan() async {
    final ya = await _konfirmasi('Putuskan rekening BRI?',
        'QRIS dan transfer tidak akan tercatat otomatis lagi. Catatan yang sudah ada tetap tersimpan.', 'Putuskan');
    if (ya && mounted && await verifikasiPin(context, 'Konfirmasi untuk memutus rekening BRI')) {
      await Sesi.putuskanBri();
      setState(() {});
    }
  }

  Future<void> _dataContoh(bool isi) async {
    if (!isi) {
      final ya = await _konfirmasi('Hapus data contoh?', 'Hanya data contoh yang dihapus. Catatanmu sendiri tetap aman.', 'Hapus');
      if (!ya || !mounted) return;
      if (!await verifikasiPin(context, 'Konfirmasi untuk menghapus data contoh')) return;
    }
    setState(() => _sibuk = true);
    try {
      if (isi) {
        await Api.isiDataContoh(Sesi.pedagangId!);
        _pesan('Data contoh 90 hari sudah diisi. Cek Laporan dan Rapor KUR.');
      } else {
        await Api.hapusDataContoh(Sesi.pedagangId!);
        _pesan('Data contoh dihapus.');
      }
      widget.onDataBerubah();
    } catch (e) {
      _pesan(pesanGalat(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _keluar() async {
    final ya = await _konfirmasi('Keluar dari VoKas?', 'Datamu tetap tersimpan. Masuk lagi dengan nomor WhatsApp dan PIN.', 'Keluar');
    if (!ya || !mounted) return;
    if (!await verifikasiPin(context, 'Konfirmasi untuk keluar dari akun')) return;
    await Sesi.keluar();
    if (mounted) lanjut(context);
  }

  Future<bool> _konfirmasi(String judul, String isi, String aksi) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(judul),
          content: Text(isi),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
              child: Text(aksi),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final bri = Sesi.briTersambung == true;
    return ListView(padding: paddingTab, children: [
      Text('Profil', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      Kartu(
        child: Row(children: [
          Avatar(Sesi.nama, radius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Sesi.nama, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600)),
              if (Sesi.namaUsaha.isNotEmpty) Text(Sesi.namaUsaha, style: const TextStyle(color: Warna.redup)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.phone_outlined, size: 14, color: Warna.redup),
                const SizedBox(width: 4),
                Text(samarkanWa(Sesi.noWa), style: const TextStyle(fontSize: 12.5, color: Warna.redup)),
              ]),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 22),
      const _Judul('Rekening BRI'),
      Kartu(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Warna.qris, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bri ? 'BRI ****${Sesi.briRekening}' : 'Belum tersambung',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(bri ? 'a.n. ${Sesi.briNama}' : 'Sambungkan supaya QRIS tercatat sendiri',
                    style: const TextStyle(fontSize: 12.5, color: Warna.redup)),
              ]),
            ),
            if (bri)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Warna.khaki, borderRadius: BorderRadius.circular(8)),
                child: const Text('Aktif', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Warna.oliveTua)),
              ),
          ]),
          const SizedBox(height: 12),
          if (bri)
            OutlinedButton(
              onPressed: _putuskan,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), foregroundColor: Warna.merah, side: const BorderSide(color: Warna.garis)),
              child: const Text('Putuskan sambungan'),
            )
          else
            FilledButton(
              onPressed: _sambung,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42), backgroundColor: Warna.qris),
              child: const Text('Hubungkan rekening BRI'),
            ),
        ]),
      ),
      const SizedBox(height: 22),
      const _Judul('Usaha'),
      Kartu(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: SwitchListTile(
          value: _terpisah ?? false,
          onChanged: _terpisah == null ? null : _ubahTerpisah,
          activeColor: Warna.oliveTua,
          title: const Text('Uang usaha di rekening terpisah', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5)),
          subtitle: const Text('Menambah 15 poin di Rapor KUR', style: TextStyle(fontSize: 12.5)),
        ),
      ),
      const SizedBox(height: 22),
      const _Judul('Data demo'),
      Kartu(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Isi 90 hari transaksi contoh warung cilok untuk mencoba Laporan dan Rapor KUR. '
              'Data contoh ditandai dan bisa dihapus kapan saja.',
              style: TextStyle(fontSize: 13, color: Warna.redup, height: 1.5)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sibuk ? null : () => _dataContoh(true),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            icon: _sibuk
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('Isi data contoh 90 hari'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _sibuk ? null : () => _dataContoh(false),
            style: TextButton.styleFrom(foregroundColor: Warna.merah),
            child: const Text('Hapus data contoh'),
          ),
        ]),
      ),
      const SizedBox(height: 22),
      const _Judul('Keamanan'),
      Kartu(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          const _Baris(Icons.lock_outline_rounded, 'PIN VoKas', 'Diminta saat keluar, memutus rekening, dan menghapus data'),
          const Divider(height: 1, color: Warna.garis, indent: 56),
          _Baris(Icons.location_on_outlined, 'Lokasi usaha',
              Sesi.lokasiUsaha.isEmpty ? 'Belum diisi, ketuk untuk mengambil' : Sesi.lokasiUsaha,
              onTap: () async {
                final ok = await Izin.mintaLokasi();
                if (!mounted) return;
                _pesan(ok ? 'Lokasi usaha tersimpan.' : 'Izin lokasi ditolak. Bisa diubah di pengaturan HP.');
                setState(() {});
              }),
          const Divider(height: 1, color: Warna.garis, indent: 56),
          _Baris(Icons.tune_rounded, 'Izin aplikasi', 'Mikrofon, notifikasi, lokasi', onTap: Izin.bukaPengaturan),
          const Divider(height: 1, color: Warna.garis, indent: 56),
          _Baris(Icons.shield_outlined, 'Yang disiapkan untuk versi resmi', 'Lihat rinciannya', onTap: () => _versiResmi(context)),
        ]),
      ),
      const SizedBox(height: 22),
      OutlinedButton.icon(
        onPressed: _keluar,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Keluar'),
        style: OutlinedButton.styleFrom(foregroundColor: Warna.merah, side: const BorderSide(color: Warna.garis), backgroundColor: Warna.kartu),
      ),
      const SizedBox(height: 28),
      const PoweredBy(),
    ]);
  }

  void _versiResmi(BuildContext context) => showModalBottomSheet(
        context: context,
        backgroundColor: Warna.latar,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const _LembarVersiResmi(),
      );
}

class _LembarVersiResmi extends StatelessWidget {
  const _LembarVersiResmi();

  static const _isi = [
    ('Akun & masuk', [
      'OTP dikirim lewat WhatsApp Cloud API, berlaku 5 menit, maksimal 3 percobaan',
      'Sesi memakai Supabase Auth (JWT) yang kedaluwarsa dan diperbarui otomatis',
      'PIN di-hash di server (bcrypt), terkunci sementara setelah 5 kali salah',
      'Login Google lewat Google Sign-In (OAuth 2.0)',
    ]),
    ('Rekening BRI', [
      'Penautan lewat BRIAPI setelah kerja sama resmi dengan BRI',
      'Cek nama pemilik rekening ke bank, OTP dikirim oleh BRI',
      'VoKas hanya menyimpan 4 digit terakhir nomor rekening',
      'Izin hanya baca mutasi; tidak bisa memindahkan uang',
    ]),
    ('Data', [
      'Koneksi HTTPS, database dengan Row Level Security',
      'Pedagang bisa ekspor dan hapus semua datanya',
      'Mengikuti UU Pelindungan Data Pribadi (UU 27/2022)',
    ]),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rencana keamanan versi resmi', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Di versi demo ini, OTP, login BRImo/Google, dan penautan rekening masih simulasi.',
                style: TextStyle(color: Warna.redup, fontSize: 13)),
            const SizedBox(height: 12),
            for (final (judul, poin) in _isi) ...[
              const SizedBox(height: 10),
              Text(judul, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              for (final p in poin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 5, color: Warna.olive)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p, style: const TextStyle(fontSize: 13.5, height: 1.45))),
                  ]),
                ),
            ],
          ]),
        ),
      );
}

class _Judul extends StatelessWidget {
  const _Judul(this.teks);
  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(teks.toUpperCase(),
            style: const TextStyle(fontSize: 11.5, letterSpacing: .8, fontWeight: FontWeight.w600, color: Warna.redup)),
      );
}

class _Baris extends StatelessWidget {
  const _Baris(this.ikon, this.judul, this.sub, {this.onTap});
  final IconData ikon;
  final String judul, sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(ikon, color: Warna.oliveTua),
        title: Text(judul, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12.5)),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      );
}

/// "Powered by VoKas Team", dipakai di splash dan profil.
class PoweredBy extends StatelessWidget {
  const PoweredBy({super.key, this.terang = false});
  final bool terang;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Powered by ', style: TextStyle(color: terang ? Warna.khaki : Warna.redup)),
            TextSpan(
                text: 'VoKas Team',
                style: TextStyle(fontWeight: FontWeight.w700, color: terang ? Colors.white : Warna.oliveTua)),
          ]),
          style: const TextStyle(fontSize: 12.5),
        ),
        const SizedBox(height: 2),
        Text('Versi 0.1 · demo', style: TextStyle(fontSize: 11, color: terang ? Warna.khaki.withOpacity(.7) : Warna.redup)),
      ]);
}
