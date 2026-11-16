-- Pengajuan merchant QRIS BRI lewat VoKas (alur kerja sama: VoKas mengumpulkan data, BRI memverifikasi).
create table pengajuan_qris (
    id              uuid primary key default gen_random_uuid(),
    pedagang_id     uuid not null unique references pedagang(id) on delete cascade,
    nama_pemilik    varchar(120) not null,
    nama_usaha      varchar(160) not null,
    kategori        varchar(60)  not null,
    alamat          varchar(300) not null,
    kota            varchar(80)  not null,
    kisaran_omzet   varchar(40)  not null,
    rekening_akhir  varchar(4)   not null,
    status          varchar(20)  not null default 'DIAJUKAN',  -- DIAJUKAN, VERIFIKASI, AKTIF
    nmid            varchar(20),
    referensi       varchar(30)  not null,
    dibuat          timestamptz  not null default now(),
    diperbarui      timestamptz  not null default now()
);
