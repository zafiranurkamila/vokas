# VoKas

**Catat usaha, cukup lewat suara.**

VoKas adalah asisten pembukuan untuk pedagang kecil. Pedagang cukup bicara, misalnya
*"jual cilok tiga puluh bungkus dua ribuan, beli gas dua puluh dua ribu"*, lalu AI mengubahnya menjadi catatan
pemasukan dan pengeluaran. Pembayaran QRIS BRI ikut tercatat otomatis, laporan tersusun sendiri, dan catatan
harian menjadi **Rapor Kesiapan KUR** yang bisa dibagikan ke BRI.

Dibuat oleh Tim **Outthink** (Telkom University dan Universitas Airlangga) untuk BRImo Business Challenge 2026.

## Coba langsung

| | |
|---|---|
| Web | https://vokas-4e7cc.web.app |
| Android | lewat Firebase App Distribution (undangan tester) |
| Akun juri | nomor **0812 0000 2026**, PIN **202611**. Data jualan 90 hari sudah terisi. |

## Fitur

- **Catat lewat suara atau teks.** Kalimat sederhana dibaca parser aturan (gratis dan instan). Suara dan
  kalimat sulit dibaca Gemini.
- **Laporan** 7 atau 30 hari: omzet, pengeluaran, laba, porsi QRIS, grafik harian, barang terlaris.
- **Unduh dan kirim laporan:** PDF, Excel (.xlsx), atau kirim ke email dengan kedua lampiran.
- **Laporan berkala lewat email:** settlement QRIS harian (21.00 WIB) dan laporan bulanan (tanggal 1).
  Ringkasan singkat juga dikirim lewat WhatsApp bila kanal WhatsApp aktif.
- **Rapor Kesiapan KUR** (skor 0-100) dan kalkulator cicilan KUR.
- **Tanya AI** yang menjawab dari data usaha pedagang sendiri, dengan riwayat percakapan tersimpan.
- **QRIS BRI:** notifikasi uang masuk (tetap muncul saat aplikasi ditutup) dan **pengajuan merchant QRIS BRI**
  dari aplikasi. Data diteruskan ke BRI, BRI yang memverifikasi.
- **Akun:** daftar dengan email (kode verifikasi ke email) atau Google, masuk dengan email atau nomor WA dan PIN,
  serta lupa PIN lewat email. PIN disimpan sebagai hash PBKDF2 di server.

## Arsitektur

```
Aplikasi Flutter (Android + web)
        |  HTTPS + X-Api-Key
        v
Backend Spring Boot (Render) ----> Supabase PostgreSQL (Flyway)
        |-- Gemini API             membaca suara/teks, Tanya AI
        |-- Brevo API              email kode verifikasi dan laporan
        |-- Google tokeninfo       verifikasi login Google
        '-- BRIAPI SNAP (sandbox)  mutasi rekening (disiapkan)
```

| Bagian | Teknologi |
|---|---|
| Aplikasi | Flutter 3, `record`, `google_sign_in`, `flutter_local_notifications`, `share_plus` |
| Backend | Java 17, Spring Boot 3.3, JPA, Flyway, OpenPDF, fastexcel |
| Database | Supabase PostgreSQL (session pooler) |
| AI | Google Gemini (`gemini-3.5-flash-lite`, cadangan otomatis) |
| Hosting | Render (backend, Docker), Firebase Hosting (web), Firebase App Distribution (APK) |
| CI/CD | GitHub Actions: setiap push ke `frontend/**` membangun web dan APK |

## Struktur

```
backend/    Spring Boot API (lihat backend/README.md)
  src/main/java/id/vokas/
    auth/     daftar, masuk, lupa PIN, Google
    parser/   pembaca catatan: aturan + Gemini
    service/  laporan, rapor KUR, ekspor PDF/Excel, email, laporan berkala
    web/      REST controller
    bri/      klien BRIAPI SNAP
    whatsapp/ webhook WhatsApp Cloud API dan Twilio
  src/main/resources/db/migration/   skema database (Flyway)
frontend/   aplikasi Flutter (lihat frontend/README.md)
render.yaml Blueprint Render
```

## Menjalankan di komputer sendiri

Backend (butuh JDK 17 dan database PostgreSQL atau Supabase):

```bash
cd backend
cp .env.example .env   # isi nilainya, jangan di-commit
./mvnw spring-boot:run
```

Aplikasi (butuh Flutter):

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:8080
```

## Konfigurasi

Nilai rahasia **tidak** disimpan di repo. Isi di Render (backend) dan GitHub Actions (build aplikasi).

| Tempat | Nama | Keterangan |
|---|---|---|
| Render | `SUPABASE_DB_URL`, `SUPABASE_DB_USER`, `SUPABASE_DB_PASSWORD` | koneksi database |
| Render | `GEMINI_API_KEY`, `GEMINI_MODEL` | AI |
| Render | `VOKAS_API_KEY` | kunci API sederhana untuk aplikasi |
| Render | `BREVO_API_KEY`, `MAIL_FROM`, `MAIL_NAMA` | email lewat Brevo HTTP API (port SMTP diblokir di Render gratis) |
| Render | `GOOGLE_CLIENT_ID` | login Google (Web client ID) |
| Render | `BRI_*`, `WA_*`, `TWILIO_*` | opsional: BRIAPI dan WhatsApp |
| GitHub secret | `VOKAS_API_KEY`, `FIREBASE_SERVICE_ACCOUNT_VOKAS_4E7CC` | build dan deploy |
| GitHub secret | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` | kunci tanda tangan APK yang tetap |
| GitHub variable | `API_URL`, `GOOGLE_CLIENT_ID`, `FIREBASE_ANDROID_APP_ID`, `APP_TESTERS` | build dan distribusi |

## Yang masih simulasi

Prototipe ini jujur soal batasnya. Bagian berikut masih simulasi sampai ada kerja sama resmi:

- **Verifikasi pengajuan QRIS oleh BRI** (status berjalan otomatis sekitar 3 menit) dan login BRImo.
- **Notifikasi QRIS masuk** (pembayaran contoh). Versi resmi memakai notifikasi mutasi dari BRIAPI.
- **Kanal WhatsApp.** Kode webhook sudah siap, tetapi butuh Verifikasi Bisnis Meta atau layanan berbayar.
- **Mutasi BRIAPI** baru disiapkan untuk sandbox.

Rapor Kesiapan KUR adalah alat bantu, bukan keputusan kredit. Persetujuan KUR tetap dari BRI.
