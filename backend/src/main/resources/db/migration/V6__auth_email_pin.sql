-- Auth: daftar/masuk dengan email atau nomor WA, PIN di-hash di server, lupa PIN lewat kode email, login Google.
alter table pedagang add column pin_hash varchar(200);
alter table pedagang add column google_sub varchar(64);
alter table pedagang add column gagal_pin int not null default 0;
alter table pedagang add column kunci_sampai timestamptz;
create unique index pedagang_email_unik on pedagang (lower(email)) where email is not null;
create unique index pedagang_google_unik on pedagang (google_sub) where google_sub is not null;

create table kode_otp (
    id          uuid primary key default gen_random_uuid(),
    email       varchar(160) not null,
    keperluan   varchar(20)  not null,   -- DAFTAR, MASUK, LUPA_PIN
    kode_hash   varchar(64)  not null,
    percobaan   int          not null default 0,
    kedaluwarsa timestamptz  not null,
    dibuat      timestamptz  not null default now()
);
create index kode_otp_email on kode_otp (lower(email), keperluan, dibuat desc);
