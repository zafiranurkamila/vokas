# VoKas App (Flutter)

Alur: splash logo, intro 3 langkah, daftar/masuk dengan nomor WhatsApp, sambung rekening BRI (simulasi,
bisa "Nanti saja"), lalu beranda dengan tab Beranda, Laporan, Rapor KUR, dan tombol mic untuk mencatat.

## Pertama kali di PC

Flutter terpasang di `C:\Program Files\flutter`, jadi jalankan dari **PowerShell sebagai Administrator**
supaya Flutter bisa menulis cache-nya. Folder platform (`web/`, `android/`) belum ada di repo; buat sekali:

```powershell
cd frontend
flutter create . --project-name vokas_app --platforms web,android
flutter pub get
```

`flutter create .` hanya menambah file yang belum ada; `lib/` dan `pubspec.yaml` tidak ditimpa.

## Jalankan

Backend harus jalan dulu (lihat `../backend/README.md`).

```powershell
flutter run -d chrome --dart-define=API_URL=http://localhost:8080
```

Kalau backend memakai `VOKAS_API_KEY`, tambahkan `--dart-define=API_KEY=...`.

Untuk Android:
- Emulator: pakai `API_URL=http://10.0.2.2:8080`.
- Rekam suara butuh izin mikrofon. Tambahkan `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
  di `android/app/src/main/AndroidManifest.xml`.

## Deploy ke Firebase Hosting

```powershell
npm install -g firebase-tools     # sekali saja
firebase login
firebase use --add                # pilih project Firebase
flutter build web --release --dart-define=API_URL=https://<domain-railway> --dart-define=API_KEY=...
firebase deploy --only hosting
```

Setelah itu tambahkan domain `https://<project>.web.app` ke `CORS_ORIGINS` di Railway.

Catatan: nilai `API_KEY` ikut terbawa di file JavaScript hasil build dan bisa dilihat orang. Cukup untuk demo
dan pilot tertutup; sebelum publik ganti dengan login Supabase Auth.
