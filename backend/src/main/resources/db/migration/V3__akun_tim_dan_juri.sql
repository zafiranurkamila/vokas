-- Akun demo tambahan: 3 akun tim Outthink dan 1 akun khusus juri.
-- Semua masuk dengan kode OTP demo 123456, lalu buat PIN sendiri di HP masing-masing.
--   0812 0000 0002  Tim Outthink 1
--   0812 0000 0003  Tim Outthink 2
--   0812 0000 0004  Tim Outthink 3
--   0812 0000 2026  Juri BBC 2026 (data contoh 90 hari diisi otomatis setiap server menyala)
insert into pedagang (nama, nama_usaha, no_wa, rekening_terpisah) values
    ('Zafira', 'Warung Tim Outthink 1 (Demo)', '6281200000002', true),
    ('Zaskia', 'Warung Tim Outthink 2 (Demo)', '6281200000003', true),
    ('Tiara',  'Warung Tim Outthink 3 (Demo)', '6281200000004', true),
    ('Juri BBC', 'Cilok & Cireng Demo Juri', '6281200002026', true)
on conflict (no_wa) do nothing;
