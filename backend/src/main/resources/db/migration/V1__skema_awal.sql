create table pedagang (
    id                uuid primary key default gen_random_uuid(),
    nama              varchar(120) not null,
    nama_usaha        varchar(160),
    no_wa             varchar(20) unique,
    rekening_terpisah boolean not null default false,
    dibuat            timestamptz not null default now()
);

create table produk (
    id          uuid primary key default gen_random_uuid(),
    pedagang_id uuid not null references pedagang(id) on delete cascade,
    nama        varchar(120) not null,
    satuan      varchar(30),
    harga_jual  bigint,
    unique (pedagang_id, nama)
);

create table transaksi (
    id            uuid primary key default gen_random_uuid(),
    pedagang_id   uuid not null references pedagang(id) on delete cascade,
    tanggal       date not null,
    jenis         varchar(10) not null check (jenis in ('MASUK', 'KELUAR')),
    nama_item     varchar(160) not null,
    jumlah        integer,
    satuan        varchar(30),
    harga_satuan  bigint,
    total         bigint not null check (total >= 0),
    metode        varchar(10) not null default 'TUNAI' check (metode in ('TUNAI', 'QRIS', 'TRANSFER')),
    sumber        varchar(10) not null check (sumber in ('SUARA', 'TEKS', 'QRIS', 'MUTASI', 'MANUAL')),
    catatan_asli  text,
    ref_eksternal varchar(80),
    -- transfer masuk belum tentu uang usaha: tidak dihitung di laporan sampai pedagang mengonfirmasi
    perlu_cek     boolean not null default false,
    dibuat        timestamptz not null default now(),
    unique (pedagang_id, ref_eksternal)
);

create index idx_transaksi_pedagang_tanggal on transaksi (pedagang_id, tanggal);

-- Tabel di schema public terbuka lewat API Supabase (anon key). RLS tanpa policy menutup akses itu;
-- backend memakai role postgres sehingga tetap bisa membaca dan menulis.
alter table pedagang  enable row level security;
alter table produk    enable row level security;
alter table transaksi enable row level security;
