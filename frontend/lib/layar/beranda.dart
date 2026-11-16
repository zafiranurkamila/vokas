import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../notif.dart';
import '../sesi.dart';
import '../tema.dart';
import '../widget/tur.dart';
import 'catat.dart';
import 'hitung_kur.dart';
import 'daftar_qris.dart';
import 'tanya_ai.dart';
import 'terima_qris.dart';
import 'laporan.dart';
import 'profil.dart';
import 'rapor_kur.dart';

String tglIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Jarak atas yang sama untuk semua tab.
const paddingTab = EdgeInsets.fromLTRB(20, 28, 20, 110);

class Beranda extends StatefulWidget {
  const Beranda({super.key});

  @override
  State<Beranda> createState() => _BerandaState();
}

class _BerandaState extends State<Beranda> {
  int _tab = 0;
  int _versi = 0; // dinaikkan setelah mencatat/isi data contoh, supaya tab memuat ulang

  final _kunciMic = GlobalKey();
  final _kunciLaporan = GlobalKey();
  final _kunciKur = GlobalKey();
  final _kunciProfil = GlobalKey();

  @override
  void initState() {
    super.initState();
    final n = PusatNotif.i;
    // QRIS yang masuk selama aplikasi ditutup dicatat setelah riwayat notifikasi dimuat
    n.muat().then((_) => n.prosesTertunda());
    n.onTransaksiBaru = () {
      if (mounted) setState(() => _versi++);
    };
    n.mulaiSimulasi();
    if (!Sesi.sudahTur) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Future.delayed(const Duration(milliseconds: 500), _mulaiTur));
    }
  }

  void _mulaiTur() {
    if (!mounted) return;
    tampilkanTur(context, [
      const LangkahTur(
        judul: 'Selamat datang di VoKas',
        isi: 'Kenalan sebentar dengan fitur utamanya. Cuma 4 langkah.',
      ),
      LangkahTur(
        kunci: _kunciMic,
        judul: 'Catat lewat suara',
        isi: 'Tekan mic lalu bicara, misalnya "jual cilok tiga puluh bungkus dua ribuan". Bisa juga diketik.',
      ),
      LangkahTur(
        kunci: _kunciLaporan,
        judul: 'Laporan otomatis',
        isi: 'Omzet, pengeluaran, laba, dan barang paling laku tersusun sendiri per 7 atau 30 hari.',
      ),
      LangkahTur(
        kunci: _kunciKur,
        judul: 'Rapor Kesiapan KUR',
        isi: 'Skor 0-100 dari catatanmu. Semakin rajin dan rapi, semakin siap mengajukan KUR.',
      ),
      LangkahTur(
        kunci: _kunciProfil,
        judul: 'Profil & rekening BRI',
        isi: 'Sambungkan rekening BRI supaya QRIS tercatat sendiri. Di sini juga ada data contoh untuk mencoba.',
      ),
    ], onSelesai: Sesi.selesaiTur);
  }

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

  void _segarkan() => setState(() => _versi++);

  void _keTab(int i) {
    setState(() => _tab = i);
    PusatNotif.i.mulaiSimulasi(); // ikut menyala/mati bila status sambungan BRI berubah di Profil
  }

  @override
  void dispose() {
    PusatNotif.i
      ..hentikanSimulasi()
      ..onTransaksiBaru = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TabBeranda(key: ValueKey('b$_versi'), keTab: _keTab, onCatat: _catat),
      TabLaporan(key: ValueKey('l$_versi'), onDataBerubah: _segarkan),
      TabRaporKur(key: ValueKey('k$_versi'), onDataBerubah: _segarkan),
      TabProfil(key: ValueKey('p$_versi'), onDataBerubah: _segarkan),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: tabs[_tab])),
      ),
      floatingActionButton: FloatingActionButton(
        key: _kunciMic,
        onPressed: _catat,
        backgroundColor: Warna.oliveTua,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        tooltip: 'Catat transaksi',
        child: const Icon(Icons.mic_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        height: 68,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(children: [
          _Nav(Icons.home_rounded, 'Beranda', _tab == 0, () => _keTab(0)),
          _Nav(Icons.bar_chart_rounded, 'Laporan', _tab == 1, () => _keTab(1), kunci: _kunciLaporan),
          const SizedBox(width: 64),
          _Nav(Icons.verified_outlined, 'Rapor KUR', _tab == 2, () => _keTab(2), kunci: _kunciKur),
          _Nav(Icons.person_outline_rounded, 'Profil', _tab == 3, () => _keTab(3), kunci: _kunciProfil),
        ]),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav(this.ikon, this.label, this.aktif, this.onTap, {this.kunci});
  final IconData ikon;
  final String label;
  final bool aktif;
  final VoidCallback onTap;
  final Key? kunci;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          key: kunci,
          onTap: onTap,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ikon, size: 23, color: aktif ? Warna.oliveTua : Warna.redup),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: aktif ? Warna.oliveTua : Warna.redup, fontWeight: aktif ? FontWeight.w600 : null)),
          ]),
        ),
      );
}

class TabBeranda extends StatefulWidget {
  const TabBeranda({super.key, required this.keTab, required this.onCatat});
  final ValueChanged<int> keTab;
  final VoidCallback onCatat;

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

  Future<void> _buka(Widget layar) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => layar));
    if (mounted) setState(() => _data = _muat());
  }

  Future<void> _aturTarget() async {
    final ctrl = TextEditingController(text: Sesi.targetHarian > 0 ? '${Sesi.targetHarian}' : '');
    final hasil = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Target omzet harian'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Berapa omzet yang ingin dicapai setiap hari?', style: TextStyle(color: Warna.redup, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: 'Rp ', hintText: '300000'),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [
            for (final n in [200000, 300000, 500000])
              ActionChip(label: Text(rp(n)), onPressed: () => ctrl.text = '$n'),
          ]),
        ]),
        actions: [
          if (Sesi.targetHarian > 0) TextButton(onPressed: () => Navigator.pop(c, 0), child: const Text('Hapus target')),
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0),
            style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (hasil == null) return;
    await Sesi.simpanTarget(hasil);
    if (mounted) setState(() {});
  }

  Future<void> _hapus(Map<String, dynamic> t) async {
    try {
      await Api.hapusTransaksi(Sesi.pedagangId!, t['id']);
      setState(() => _data = _muat());
    } catch (e) {
      if (mounted) tampilPesan(context, pesanGalat(e), jenis: JenisPesan.gagal);
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
            final kepala = _Sapaan(onProfil: () => widget.keTab(3));
            if (snap.hasError) {
              return ListView(padding: paddingTab, children: [
                kepala,
                const SizedBox(height: 40),
                Text(pesanGalat(snap.error!), textAlign: TextAlign.center),
                TextButton(onPressed: () => setState(() => _data = _muat()), child: const Text('Coba lagi')),
              ]);
            }
            if (!snap.hasData) {
              return ListView(padding: paddingTab, children: [
                kepala,
                const SizedBox(height: 80),
                const MemuatServer(),
              ]);
            }
            final (lap, trx, kur) = snap.data!;
            final daftar = trx.reversed.cast<Map<String, dynamic>>().toList();
            return ListView(padding: paddingTab, children: [
              kepala,
              const SizedBox(height: 20),
              _KartuUntung(lap, target: Sesi.targetHarian, aksi: [
                _Aksi(Icons.auto_awesome_rounded, 'Tanya AI', () => _buka(const LayarTanyaAi())),
                _Aksi(Icons.qr_code_2_rounded, 'Terima QRIS', () => _buka(const LayarTerimaQris())),
                _Aksi(Icons.app_registration_rounded, 'Daftar QRIS', () => _buka(const LayarDaftarQris())),
                _Aksi(Icons.calculate_outlined, 'Hitung KUR', () => _buka(const LayarHitungKur())),
                _Aksi(Icons.flag_outlined, 'Target', _aturTarget),
              ]),
              const SizedBox(height: 16),
              _BannerKur(kur, () => widget.keTab(2)),
              if (Sesi.briTersambung != true) ...[
                const SizedBox(height: 10),
                _AjakSambung(() => widget.keTab(3)),
              ],
              const SizedBox(height: 24),
              JudulBagian('Catatan hari ini',
                  aksi: trx.isEmpty ? null : 'Lihat laporan', onAksi: () => widget.keTab(1)),
              const SizedBox(height: 10),
              if (trx.isEmpty)
                Kosong(
                  ikon: Icons.mic_none_rounded,
                  judul: 'Belum ada catatan hari ini',
                  isi: 'Tekan tombol mic lalu sebutkan jualanmu. Contoh: "jual cilok tiga puluh bungkus dua ribuan".',
                  tombol: 'Catat sekarang',
                  onTombol: widget.onCatat,
                )
              else
                Kartu(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    for (var i = 0; i < daftar.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 68, endIndent: 16, color: Warna.garis),
                      BarisTransaksi(daftar[i], onHapus: () => _hapus(daftar[i])),
                    ],
                  ]),
                ),
            ]);
          },
        ),
      );
}

class _Sapaan extends StatelessWidget {
  const _Sapaan({required this.onProfil});
  final VoidCallback onProfil;

  @override
  Widget build(BuildContext context) {
    final nama = Sesi.nama.isEmpty ? 'Juragan' : Sesi.nama.split(' ').first;
    final jam = DateTime.now().hour;
    final salam = jam < 11 ? 'Selamat pagi' : (jam < 15 ? 'Selamat siang' : (jam < 18 ? 'Selamat sore' : 'Selamat malam'));
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(salam, style: const TextStyle(color: Warna.redup, fontSize: 13)),
          Text('Halo, $nama', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
      ),
      const TombolNotif(),
      const SizedBox(width: 8),
      InkWell(
        onTap: onProfil,
        customBorder: const CircleBorder(),
        child: Avatar(Sesi.nama),
      ),
    ]);
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.nama, {super.key, this.radius = 22});
  final String nama;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bagian = nama.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2);
    final inisial = bagian.isEmpty ? 'V' : bagian.map((s) => s[0].toUpperCase()).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Warna.khaki,
      child: Text(inisial,
          style: TextStyle(color: Warna.oliveTua, fontWeight: FontWeight.w700, fontSize: radius * .7)),
    );
  }
}

class _Aksi {
  const _Aksi(this.ikon, this.label, this.onTap);
  final IconData ikon;
  final String label;
  final VoidCallback onTap;
}

class _KartuUntung extends StatelessWidget {
  const _KartuUntung(this.lap, {required this.aksi, this.target = 0});
  final Map<String, dynamic> lap;
  final List<_Aksi> aksi;
  final int target;

  @override
  Widget build(BuildContext context) {
    final omzet = (lap['omzet'] as num?) ?? 0;
    final keluar = (lap['pengeluaran'] as num?) ?? 0;
    final qris = (lap['omzetQris'] as num?) ?? 0;
    final laba = (lap['laba'] as num?) ?? 0;
    return Container(
      decoration: BoxDecoration(color: Warna.kartu, borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(color: Warna.oliveTua, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Untung hari ini', style: TextStyle(color: Warna.khaki, fontSize: 13)),
            const SizedBox(height: 2),
            Text(rp(laba), style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              _Angka('Masuk', rp(omzet), Icons.arrow_downward_rounded),
              _Angka('Keluar', rp(keluar), Icons.arrow_upward_rounded),
              _Angka('Lewat QRIS', rp(qris), Icons.qr_code_2_rounded),
            ]),
            if (target > 0) ...[
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.flag_rounded, size: 14, color: Warna.matahari),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Target ${rp(target)}',
                      style: const TextStyle(color: Warna.khaki, fontSize: 12)),
                ),
                Text(omzet >= target ? 'Tercapai!' : '${(100 * omzet / target).floor()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (omzet / target).clamp(0, 1).toDouble(),
                  minHeight: 7,
                  backgroundColor: Colors.white24,
                  color: Warna.matahari,
                ),
              ),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Column(children: [
            // 5 tombol per baris; ikon rata atas dan label selalu setinggi 2 baris supaya semua sejajar
            for (var b = 0; b < aksi.length; b += 5)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = b; i < b + 5; i++)
                  Expanded(child: i < aksi.length ? _TombolAksi(aksi[i]) : const SizedBox()),
              ]),
          ]),
        ),
      ]),
    );
  }
}

class _TombolAksi extends StatelessWidget {
  const _TombolAksi(this.a);
  final _Aksi a;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: a.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
          child: Column(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Warna.khaki.withOpacity(.7), borderRadius: BorderRadius.circular(14)),
              child: Icon(a.ikon, color: Warna.oliveTua, size: 22),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              child: Text(a.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, height: 1.25, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      );
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

class _AjakSambung extends StatelessWidget {
  const _AjakSambung(this.onTap);
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Kartu(
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Warna.qris.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_rounded, color: Warna.qris, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sambungkan rekening BRI', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('QRIS dan transfer tercatat sendiri', style: TextStyle(fontSize: 12, color: Warna.redup)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Warna.redup),
          ]),
        ),
      );
}

/// Tampilan kosong yang mengajak bertindak, dipakai di semua tab.
class Kosong extends StatelessWidget {
  const Kosong({super.key, required this.ikon, required this.judul, required this.isi, this.tombol, this.onTombol, this.tombol2, this.onTombol2});
  final IconData ikon;
  final String judul, isi;
  final String? tombol, tombol2;
  final VoidCallback? onTombol, onTombol2;

  @override
  Widget build(BuildContext context) => Kartu(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Warna.khaki.withOpacity(.6), shape: BoxShape.circle),
            child: Icon(ikon, color: Warna.oliveTua, size: 28),
          ),
          const SizedBox(height: 12),
          Text(judul, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 6),
          Text(isi, textAlign: TextAlign.center, style: const TextStyle(color: Warna.redup, fontSize: 13, height: 1.5)),
          if (tombol != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onTombol,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: Text(tombol!),
            ),
          ],
          if (tombol2 != null) ...[
            const SizedBox(height: 4),
            TextButton(onPressed: onTombol2, child: Text(tombol2!)),
          ],
        ]),
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
    final nama = '${t['namaItem']}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: qris ? Warna.qris.withOpacity(.12) : (masuk ? Warna.khaki : Warna.merah.withOpacity(.12)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              qris ? Icons.qr_code_2_rounded : (masuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
              color: qris ? Warna.qris : (masuk ? Warna.oliveTua : Warna.merah),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nama.isEmpty ? nama : nama[0].toUpperCase() + nama.substring(1),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
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
            )
          else
            const SizedBox(width: 10),
        ]),
    );
  }
}

/// Judul bagian dengan tautan aksi di kanan, seperti "Lihat semua".
class JudulBagian extends StatelessWidget {
  const JudulBagian(this.judul, {super.key, this.aksi, this.onAksi});
  final String judul;
  final String? aksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(judul, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))),
        if (aksi != null)
          InkWell(
            onTap: onAksi,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(aksi!, style: const TextStyle(color: Warna.olive, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
      ]);
}

/// Lonceng notifikasi dengan angka belum dibaca.
class TombolNotif extends StatelessWidget {
  const TombolNotif({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: PusatNotif.i,
        builder: (_, __) {
          final n = PusatNotif.i.belumDibaca;
          return InkWell(
            customBorder: const CircleBorder(),
            onTap: () => PusatNotif.i.bukaDaftar?.call(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: Warna.kartu, shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_none_rounded, color: Warna.tinta),
                ),
                if (n > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: Warna.merah,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Warna.latar, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(n > 9 ? '9+' : '$n',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ),
          );
        },
      );
}

/// Indikator memuat. Bila lebih dari 5 detik, beri tahu bahwa server gratis sedang bangun.
class MemuatServer extends StatefulWidget {
  const MemuatServer({super.key});

  @override
  State<MemuatServer> createState() => _MemuatServerState();
}

class _MemuatServerState extends State<MemuatServer> {
  bool _lama = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _lama = true);
    });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const CircularProgressIndicator(),
        AnimatedOpacity(
          opacity: _lama ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              'Menyiapkan datamu, sebentar ya...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Warna.redup, fontSize: 13, height: 1.5),
            ),
          ),
        ),
      ]);
}

