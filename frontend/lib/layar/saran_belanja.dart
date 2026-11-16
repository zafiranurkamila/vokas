import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../sesi.dart';
import '../tema.dart';

/// Saran Belanja Besok: perkiraan omzet dan barang yang perlu disiapkan dari pola jualan 4 minggu,
/// pengingat belanjaan rutin, saran AI, dan peringatan pintar.
class LayarSaranBelanja extends StatefulWidget {
  const LayarSaranBelanja({super.key});

  @override
  State<LayarSaranBelanja> createState() => _LayarSaranBelanjaState();
}

class _LayarSaranBelanjaState extends State<LayarSaranBelanja> {
  late Future<(Map<String, dynamic>, List<dynamic>)> _data = _muat();

  Future<(Map<String, dynamic>, List<dynamic>)> _muat() async {
    final id = Sesi.pedagangId!;
    final r = await Future.wait([Api.saranBelanja(id), Api.peringatan(id)]);
    return (r[0] as Map<String, dynamic>, r[1] as List<dynamic>);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Saran Belanja Besok')),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() => _data = _muat());
            await _data;
          },
          child: FutureBuilder(
            future: _data,
            builder: (context, snap) {
              if (snap.hasError) {
                return ListView(padding: const EdgeInsets.all(24), children: [
                  Text(pesanGalat(snap.error!), textAlign: TextAlign.center),
                  TextButton(onPressed: () => setState(() => _data = _muat()), child: const Text('Coba lagi')),
                ]);
              }
              if (!snap.hasData) {
                return const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Membaca pola jualanmu...', style: TextStyle(color: Warna.redup)),
                  ]),
                );
              }
              final (s, peringatan) = snap.data!;
              final barang = ((s['barang'] as List?) ?? []).cast<Map<String, dynamic>>();
              final pengingat = ((s['pengingatBelanja'] as List?) ?? []).cast<Map<String, dynamic>>();
              final banding = s['bandingRataPersen'] as num?;
              return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Warna.oliveTua, borderRadius: BorderRadius.circular(24)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Besok, ${s['hari']}', style: const TextStyle(color: Warna.khaki)),
                    if (s['cukupData'] == true) ...[
                      Text('±${rp(s['perkiraanOmzet'] as num)}',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                      Text(
                        banding == null
                            ? 'perkiraan omzet dari rata-rata ${s['hariData']} hari berjualan'
                            : 'perkiraan omzet · ${banding >= 0 ? 'lebih ramai' : 'lebih sepi'} ${banding.abs()}% dari hari biasa',
                        style: const TextStyle(color: Warna.khaki, fontSize: 12.5),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Catat jualan minimal 3 hari dulu, nanti VoKas bisa memperkirakan jualan besok.',
                            style: TextStyle(color: Colors.white, height: 1.4)),
                      ),
                  ]),
                ),
                if (s['tipsAi'] != null) ...[
                  const SizedBox(height: 12),
                  Kartu(
                    warna: Warna.khaki,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.auto_awesome_rounded, color: Warna.oliveTua),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${s['tipsAi']}', style: const TextStyle(height: 1.45))),
                    ]),
                  ),
                ],
                if (barang.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Siapkan untuk besok', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                      s['polaHariSama'] == true
                          ? 'Dari rata-rata hari ${s['hari']} 4 minggu terakhir, dilebihkan 10%.'
                          : 'Dari rata-rata semua hari berjualan, dilebihkan 10%.',
                      style: const TextStyle(fontSize: 12, color: Warna.redup)),
                  const SizedBox(height: 8),
                  Kartu(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
                    child: Column(children: [
                      for (var i = 0; i < barang.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: Warna.garis),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_judul('${barang[i]['nama']}'), style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('biasanya ${rp(barang[i]['rataOmzet'] as num)}/hari',
                                    style: const TextStyle(fontSize: 12, color: Warna.redup)),
                              ]),
                            ),
                            if ((barang[i]['siapkan'] as num) > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Warna.khaki, borderRadius: BorderRadius.circular(12)),
                                child: Text('±${barang[i]['siapkan']} ${barang[i]['satuan'] ?? ''}'.trim(),
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Warna.oliveTua)),
                              ),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ],
                if (pengingat.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Waktunya belanja lagi', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final p in pengingat)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Kartu(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          const Icon(Icons.shopping_basket_rounded, color: Warna.olive),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_judul('${p['nama']}')}: biasanya dibeli tiap ${p['tiapHari']} hari, '
                              'terakhir ${p['terakhirHariLalu'] == 0 ? 'hari ini' : '${p['terakhirHariLalu']} hari lalu'}.',
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                          Text('±${rp(p['rataBelanja'] as num)}', style: const TextStyle(fontSize: 12.5, color: Warna.redup)),
                        ]),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                Text('Peringatan pintar', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (peringatan.isEmpty)
                  const Text('Tidak ada yang perlu dikhawatirkan. Usaha aman', style: TextStyle(color: Warna.redup)),
                for (final p in peringatan.cast<Map<String, dynamic>>()) ...[
                  KartuPeringatan(p),
                  const SizedBox(height: 8),
                ],
              ]);
            },
          ),
        ),
      );

  static String _judul(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Satu peringatan pintar (dipakai juga di beranda).
class KartuPeringatan extends StatelessWidget {
  const KartuPeringatan(this.p, {super.key, this.onTap});
  final Map<String, dynamic> p;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (warna, ikon) = switch (p['jenis']) {
      'BAHAYA' => (Warna.merah, Icons.trending_down_rounded),
      'WASPADA' => (const Color(0xFFB07D00), Icons.warning_amber_rounded),
      'BAIK' => (Warna.olive, Icons.celebration_rounded),
      _ => (Warna.qris, Icons.info_outline_rounded),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warna.withOpacity(.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ikon, color: warna),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['judul']}', style: TextStyle(fontWeight: FontWeight.w600, color: warna)),
              const SizedBox(height: 2),
              Text('${p['isi']}', style: const TextStyle(fontSize: 12.5, height: 1.4, color: Warna.tinta)),
            ]),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: warna),
        ]),
      ),
    );
  }
}
