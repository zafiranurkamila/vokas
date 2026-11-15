-- Akun demo untuk uji coba dan presentasi.
-- Masuk dengan nomor 0812 0000 0001, kode OTP demo 123456, lalu buat PIN.
-- Data transaksi 90 hari bisa diisi lewat Profil > Isi data contoh.
insert into pedagang (nama, nama_usaha, no_wa, rekening_terpisah)
values ('Sri Wahyuni', 'Cilok & Cireng Bu Sri (Demo)', '6281200000001', true)
on conflict (no_wa) do nothing;
