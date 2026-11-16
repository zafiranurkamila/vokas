-- Email pedagang untuk laporan harian (settlement QRIS) dan bulanan, diverifikasi dengan kode OTP.
alter table pedagang add column email varchar(160);
alter table pedagang add column email_terverifikasi boolean not null default false;
alter table pedagang add column email_kode_hash varchar(64);
alter table pedagang add column email_kode_sampai timestamptz;
alter table pedagang add column laporan_email boolean not null default true;
