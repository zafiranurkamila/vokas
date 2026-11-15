# VoKas Backend

Backend VoKas: pembukuan pedagang kecil lewat voice note dan chat WhatsApp, dengan mutasi QRIS dan transfer
yang ikut tercatat, plus Rapor Kesiapan KUR.

- Java 17, Spring Boot 3.3, Maven
- Database: Supabase (PostgreSQL), skema dibuat otomatis oleh Flyway (`src/main/resources/db/migration`)
- AI: Gemini API free tier, hanya dipanggil untuk voice note dan kalimat yang tidak terbaca oleh parser aturan
- Deploy: Railway (Dockerfile). Frontend terpisah di Firebase Hosting.

## Alur membaca catatan

```
teks  -> PembacaAturan (gratis, instan) -- terbaca utuh? --> simpan
                    \-- tidak --> PembacaGemini --> simpan
suara -> PembacaGemini (audio langsung, transkrip + JSON dalam satu panggilan) --> simpan
```

Penyedia AI bisa diganti dengan membuat kelas baru yang mengimplementasikan `PembacaCatatan`.

## Menjalankan di PC

1. Buat project di Supabase. Ambil connection string dari **Connect > Session pooler** (port 5432).
   Pakai session pooler, bukan direct connection (Railway butuh IPv4) dan bukan transaction pooler (6543),
   karena Flyway dan prepared statement JDBC bermasalah di transaction pooler.
2. Buat API key Gemini di Google AI Studio.
3. Salin `.env.example` menjadi `.env`, isi nilainya. Jangan commit `.env`.
4. Jalankan (PowerShell):

   ```powershell
   Get-Content .env | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
     $k, $v = $_ -split '=', 2; [Environment]::SetEnvironmentVariable($k.Trim(), $v.Trim())
   }
   mvn spring-boot:run
   ```

5. Cek: `http://localhost:8080/actuator/health` harus `{"status":"UP"}`.

Tes unit (tidak butuh database): `mvn test`.

## Endpoint

Semua `/api/**` butuh header `X-Api-Key` bila `VOKAS_API_KEY` diisi.

| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/baca` | Coba baca kalimat tanpa menyimpan. Body `{"teks": "..."}` |
| POST | `/api/pedagang` | Daftar pedagang. Body `{"nama","namaUsaha","noWa":"62...","rekeningTerpisah"}` |
| GET/PATCH | `/api/pedagang/{id}` | Ambil / ubah profil |
| POST | `/api/pedagang/{id}/catat?simpan=true` | Catat dari teks |
| POST | `/api/pedagang/{id}/catat-suara` | Catat dari audio (multipart, field `audio`, maks 5 MB) |
| GET | `/api/pedagang/{id}/transaksi?dari=&sampai=` | Daftar transaksi (tanggal ISO, default hari ini) |
| POST | `/api/pedagang/{id}/transaksi` | Tambah manual |
| DELETE | `/api/pedagang/{id}/transaksi/{trxId}` | Hapus |
| POST | `/api/pedagang/{id}/mutasi/impor` | Impor mutasi rekening (QRIS, transfer masuk/keluar) |
| GET | `/api/pedagang/{id}/mutasi/perlu-cek` | Transfer yang menunggu konfirmasi |
| POST | `/api/pedagang/{id}/mutasi/{trxId}/konfirmasi` | `{"usaha": true}` hitung sebagai uang usaha, `false` buang |
| GET | `/api/pedagang/{id}/laporan?dari=&sampai=` | Omzet, pengeluaran, laba, harian, terlaris (default 7 hari) |
| GET | `/api/pedagang/{id}/rapor-kur` | Skor 0-100 dan lima kriteria |
| GET/POST | `/webhook/whatsapp` | Webhook WhatsApp Cloud API |
| GET | `/actuator/health` | Health check Railway |

Contoh:

```bash
curl -X POST localhost:8080/api/baca -H "Content-Type: application/json" \
  -d '{"teks":"jual cilok tiga puluh bungkus dua ribuan, beli gas melon 22 ribu"}'
```

### Mutasi QRIS dan transfer

Contoh body impor:

```json
[
  {"ref": "QR123", "tanggal": "2026-11-13", "nominal": 15000, "metode": "QRIS"},
  {"ref": "TF456", "tanggal": "2026-11-13", "nominal": 250000, "metode": "TRANSFER", "jenis": "MASUK", "keterangan": "Transfer dari Andi"},
  {"ref": "TF789", "tanggal": "2026-11-13", "nominal": 300000, "metode": "TRANSFER", "jenis": "KELUAR", "keterangan": "Bayar supplier"}
]
```

- QRIS masuk langsung dihitung sebagai omzet.
- Transfer (masuk maupun keluar) ditandai **perlu cek**, karena bisa jadi kiriman keluarga atau pindah dana
  pribadi. Transfer tidak masuk laporan atau rapor KUR sampai pedagang mengonfirmasinya.
- `ref` yang sama tidak diimpor dua kali.

Belum ada sambungan langsung ke sistem BRI. Untuk pilot, data mutasi berasal dari ekspor mutasi rekening
yang diunggah pedagang. Integrasi otomatis butuh kerja sama resmi dengan BRI (misalnya lewat BRIAPI).

## Deploy ke Render (gratis)

`render.yaml` di akar repo sudah menyiapkan semuanya.

1. Daftar di render.com dengan akun GitHub (paket gratis, tanpa kartu kredit).
2. **New > Blueprint**, pilih repo `vokas`. Render membaca `render.yaml` (root `backend`, Dockerfile, region Singapore).
3. Isi variabel rahasia yang diminta: Supabase, Gemini, dan WhatsApp (boleh dikosongkan dulu).
   `VOKAS_API_KEY` dibuat otomatis; salin nilainya untuk `--dart-define=API_KEY` di Flutter.
4. URL backend: `https://vokas-backend.onrender.com` (atau nama yang diberikan Render).

Keterbatasan paket gratis Render: layanan tidur setelah sekitar 15 menit tanpa request, dan bangun lagi
butuh kurang lebih satu menit (Spring Boot agak lambat start). Sebelum demo atau presentasi, buka
`/actuator/health` sekali supaya server sudah bangun.

Railway tetap bisa dipakai (ada `railway.json`); isi Root Directory dengan `backend`.

## Webhook WhatsApp (nanti)

1. Buat app di Meta for Developers, tambahkan produk WhatsApp. Nomor tes gratis tersedia di sana.
2. Callback URL `https://<domain-railway>/webhook/whatsapp`, verify token sama dengan `WA_VERIFY_TOKEN`.
3. Subscribe field `messages`. Isi `WA_ACCESS_TOKEN`, `WA_PHONE_NUMBER_ID`, `WA_APP_SECRET` di Railway.
4. Pedagang cukup kirim pesan ke nomor itu. Nomor baru otomatis terdaftar.
   Perintah: `laporan`, `rapor`, `bantuan`. Pesan lain dibaca sebagai catatan.

## Catatan keamanan dan privasi

- RLS aktif di semua tabel tanpa policy, jadi anon key Supabase tidak bisa membaca data. Backend memakai role
  database langsung.
- `X-Api-Key` hanya untuk pilot tertutup. Sebelum dibuka publik, ganti dengan Supabase Auth (JWT per pedagang).
- Data yang dikirim ke Gemini free tier dapat dipakai Google untuk perbaikan produk. Cantumkan di kebijakan
  privasi, atau pindah ke paket berbayar sebelum memproses data pedagang sungguhan dalam jumlah besar.

## Akun demo

| | |
|---|---|
| Nomor WhatsApp | `0812 0000 0001` |
| Kode OTP (mode demo) | `123456` |
| PIN | dibuat sendiri saat pertama masuk di perangkat itu |

Akun dibuat otomatis oleh migrasi `V2__akun_demo.sql`. Setelah masuk, buka **Profil > Isi data contoh 90 hari**
supaya Laporan dan Rapor KUR terisi.
