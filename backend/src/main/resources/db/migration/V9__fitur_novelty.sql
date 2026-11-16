-- Fitur baru: rekaman voice note disimpan, catat dari foto nota, kasbon pelanggan, dan celengan cicilan KUR.

-- 1. Rekaman suara ikut disimpan di riwayat supaya bisa diputar ulang (dibatasi di aplikasi: maks 60 detik / WAV 16 kHz).
-- Disimpan di tabel terpisah supaya daftar riwayat tetap ringan (audio hanya diambil saat diputar).
alter table riwayat_ai add column ada_audio boolean not null default false;
create table riwayat_audio (
    riwayat_id uuid primary key references riwayat_ai(id) on delete cascade,
    mime       varchar(40) not null,
    audio      bytea not null
);

-- 2. Sumber transaksi baru: FOTO (nota dibaca AI)
alter table transaksi drop constraint if exists transaksi_sumber_check;
alter table transaksi add constraint transaksi_sumber_check
    check (sumber in ('SUARA', 'TEKS', 'QRIS', 'MUTASI', 'MANUAL', 'FOTO'));

-- 3. Kasbon: utang pelanggan ke pedagang
create table kasbon (
    id             uuid primary key default gen_random_uuid(),
    pedagang_id    uuid not null references pedagang(id) on delete cascade,
    nama_pelanggan varchar(80) not null,
    nominal        bigint not null check (nominal > 0),
    keterangan     varchar(200),
    no_wa          varchar(20),
    lunas          boolean not null default false,
    dibuat         timestamptz not null default now(),
    dilunasi       timestamptz
);
create index kasbon_pedagang on kasbon (pedagang_id, lunas, dibuat desc);

-- 4. Celengan: target tabungan (misal DP atau cicilan KUR) dan setorannya
create table celengan (
    pedagang_id uuid primary key references pedagang(id) on delete cascade,
    nama        varchar(80) not null,
    target      bigint not null check (target > 0),
    persen      int not null default 10 check (persen between 1 and 100),
    diubah      timestamptz not null default now()
);
create table celengan_setoran (
    id          uuid primary key default gen_random_uuid(),
    pedagang_id uuid not null references pedagang(id) on delete cascade,
    nominal     bigint not null,
    catatan     varchar(120),
    dibuat      timestamptz not null default now()
);
create index celengan_setoran_pedagang on celengan_setoran (pedagang_id, dibuat desc);
