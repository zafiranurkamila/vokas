import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../main.dart';
import '../sesi.dart';
import '../tema.dart';
import 'catat.dart';
import 'laporan.dart';
import 'rapor_kur.dart';

String tglIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Beranda extends StatefulWidget {
  const Beranda({super.key});

  @override
  State<Beranda> createState() => _BerandaState();
}

class _BerandaState extends State<Beranda> {
  int _tab = 0;
  int _versi = 0; // dinaikkan setelah mencatat, supaya tab memuat ulang data

  Future<void> _catat() async {
    final tersimpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Warna.latar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const LembarCatat(),
    );
    if (tersimpan == true) setState(() => _versi++);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TabBeranda(key: ValueKey('b$_versi'), keTab: (i) => setState(() => _tab = i)),
      TabLaporan(key: ValueKey('l$_versi')),
      TabRaporKur(key: ValueKey('k$_versi')),
    ];
    return Scaffold(
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: tabs[_tab]))),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _catat,
        backgroundColor: Warna.oliveTua,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: 'Catat',
        child: const Icon(Icons.mic_rounded, size: 40),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _Nav(Icons.home_rounded, 'Beranda', _tab == 0, () => setState(() => _tab = 0)),
          _Nav(Icons.bar_chart_rounded, 'Laporan', _tab == 1, () => setState(() => _tab = 1)),
          const SizedBox(width: 72),
          _Nav(Icons.verified_rounded, 'Rapor KUR', _tab == 2, () => setState(() => _tab = 2)),
          _Nav(Icons.logout_rounded, 'Keluar', false, () async {
            await Sesi.keluar();
            if (context.mounted) lanjut(context);
          }),
        ]),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav(this.ikon, this.label, this.aktif, this.onTap);
  final IconData ikon;
  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(ikon, color: aktif ? Warna.oliveTua : Warna.redup),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: aktif ? Warna.oliveTua : Warna.redup, fontWeight: aktif ? FontWeight.w600 : null)),
          ]),
        ),
      );
}

class TabBeranda extends StatefulWidget {
  const TabBeranda({super.key, required this.keTab});
  final ValueChanged<int> keTab;

  @override
  State<TabBeranda> createState() => _TabBerandaState();
}

class _TabBerandaState extends State<TabBeranda> {
  late Future<(Map<String, dynamic>, List<dynamic>, Map<String, dynamic>)> _data = _muat();

  Future<(Map<String, dynamic>, List<dynamic>, Map<String, dynamic>)> _muat() async {
    final id = Sesi.pedagangId!;
    final hari = tglIso(DateTime.now());
    final r = await Future.wait([
      Api.laporan(id, dari: hari, sampai: hari),
      Api.transaksi(id),
      Api.raporKur(id),
    ]);
    return (r[0] as Map<String, dynamic>, r[1] as List<dynamic>, r[2] as Map<String, dynamic>);
  }

  Future<void> _hapus(Map<String, dynamic> t) async {
    try {
      await Api.hapusTransaksi(Sesi.pedagangId!, t['id']);
      setState(() => _data = _muat());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesanGalat(e))));
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async {
          setState(() => _data = _muat());
          await _data;
        },
        child: FutureBuilder(
          future: _data,
          builder: (context, snap) {
            final kepala = _Sapaan();
            if (snap.hasError) {
              return ListView(padding: const EdgeInsets.all(20), children: [
                kepala,
                const SizedBox(height: 40),
                Text(pesanGalat(snap.error!), textAlign: TextAlign.center),
                TextButton(onPressed: () => setState(() => _data = _muat()), child: const Text('Coba lagi')),
              ]);
            }
            if (!snap.hasData) {
              return ListView(padding: const EdgeInsets.all(20), children: [
                kepala,
                const SizedBox(height: 80),
                const Center(child: CircularProgressIndicator()),
              ]);
            }
            final (lap, trx, kur) = snap.data!;
            return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 100), children: [
              kepala,
              const SizedBox(height: 16),
              _KartuUntung(lap),
              const SizedBox(height: 12),
              _BannerKur(kur, () => widget.keTab(2)),
              const SizedBox(height: 20),
              Row(children: [
                Text('Catatan hari ini', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${trx.length} transaksi', style: const TextStyle(color: Warna.redup, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              if (trx.isEmpty)
                const Kartu(
                  child: Text('Belum ada catatan. Tekan tombol mic lalu sebutkan jualanmu, misalnya '
                      '"jual cilok 30 bungkus dua ribuan".',
                      style: TextStyle(color: Warna.redup, height: 1.5)),
                )
              else
                ...trx.reversed.map((t) => BarisTransaksi(t as Map<String, dynamic>, onHapus: () => _hapus(t))),
            ]);
          },
        ),
      );
}

class _Sapaan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nama = Sesi.nama.isEmpty ? 'Juragan' : Sesi.nama.split(' ').first;
    final inisial = Sesi.nama.trim().isEmpty
        ? 'V'
        : Sesi.nama.trim().split(RegExp(r'\s+')).take(2).map((s) => s[0].toUpperCase()).join();
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Sesi.namaUsaha.isEmpty ? 'Halo,' : Sesi.namaUsaha, style: const TextStyle(color: Warna.redup, fontSize: 13)),
          Text('Halo, $nama', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
      ),
      CircleAvatar(
        radius: 22,
        backgroundColor: Warna.khaki,
        child: Text(inisial, style: const TextStyle(color: Warna.oliveTua, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

class _KartuUntung extends StatelessWidget {
  const _KartuUntung(this.lap);
  final Map<String, dynamic> lap;

  @override
  Widget build(BuildContext context) {
    final omzet = (lap['omzet'] as num?) ?? 0;
    final keluar = (lap['pengeluaran'] as num?) ?? 0;
    final qris = (lap['omzetQris'] as num?) ?? 0;
    final laba = (lap['laba'] as num?) ?? 0;
    return Kartu(
      warna: Warna.oliveTua,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Untung hari ini', style: TextStyle(color: Warna.khaki, fontSize: 13)),
        const SizedBox(height: 4),
        Text(rp(laba), style: GoogleFonts.poppins(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Row(children: [
          _Angka('Masuk', rp(omzet), Icons.south_west_rounded),
          _Angka('Keluar', rp(keluar), Icons.north_east_rounded),
          _Angka('Lewat QRIS', rp(qris), Icons.qr_code_2_rounded),
        ]),
      ]),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka(this.label, this.nilai, this.ikon);
  final String label, nilai;
  final IconData ikon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(ikon, size: 14, color: Warna.matahari),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: const TextStyle(color: Warna.khaki, fontSize: 11))),
          ]),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(nilai, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ]),
      );
}

class _BannerKur extends StatelessWidget {
  const _BannerKur(this.kur, this.onTap);
  final Map<String, dynamic> kur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Kartu(
          warna: Warna.khaki,
          child: Row(children: [
            const Icon(Icons.verified_rounded, color: Warna.oliveTua, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Rapor Kesiapan KUR', style: TextStyle(fontSize: 12, color: Warna.oliveTua)),
                Text('${kur['skor']} / 100',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Warna.tinta)),
                Text('${kur['status']}', style: const TextStyle(fontSize: 12, color: Warna.oliveTua)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Warna.oliveTua),
          ]),
        ),
      );
}

class BarisTransaksi extends StatelessWidget {
  const BarisTransaksi(this.t, {super.key, this.onHapus});
  final Map<String, dynamic> t;
  final VoidCallback? onHapus;

  @override
  Widget build(BuildContext context) {
    final masuk = t['jenis'] == 'MASUK';
    final qris = t['metode'] == 'QRIS';
    final jumlah = t['jumlah'] == null ? '' : '${t['jumlah']} ${t['satuan'] ?? ''}'.trim();
    final sumber = switch (t['sumber']) { 'SUARA' => 'Suara', 'TEKS' => 'Chat', 'QRIS' => 'QRIS', 'MUTASI' => 'Transfer', _ => 'Manual' };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Kartu(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: qris ? Warna.qris.withOpacity(.12) : (masuk ? Warna.khaki : Warna.merah.withOpacity(.12)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              qris ? Icons.qr_code_2_rounded : (masuk ? Icons.south_west_rounded : Icons.north_east_rounded),
              color: qris ? Warna.qris : (masuk ? Warna.oliveTua : Warna.merah),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t['namaItem']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text([if (jumlah.isNotEmpty) jumlah, sumber].join(' · '),
                  style: const TextStyle(fontSize: 12, color: Warna.redup)),
            ]),
          ),
          Text('${masuk ? '+' : '-'}${rp(t['total'] as num)}',
              style: TextStyle(fontWeight: FontWeight.w600, color: masuk ? Warna.oliveTua : Warna.merah)),
          if (onHapus != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: Warna.redup),
              onSelected: (_) => onHapus!(),
              itemBuilder: (_) => const [PopupMenuItem(value: 'hapus', child: Text('Hapus'))],
            ),
        ]),
      ),
    );
  }
}
