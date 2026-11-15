-- Riwayat percakapan Tanya AI dan catatan suara/teks, supaya tidak hilang saat layar ditutup.
create table riwayat_ai (
    id          uuid primary key default gen_random_uuid(),
    pedagang_id uuid not null references pedagang(id) on delete cascade,
    jenis       varchar(10) not null,   -- TANYA atau CATAT
    sumber      varchar(10),            -- SUARA atau TEKS (untuk CATAT)
    masukan     text,                   -- pertanyaan, atau transkrip voice note / teks catatan
    jawaban     text,                   -- jawaban AI, atau hasil catat dalam bentuk JSON
    galat       text,
    dibuat      timestamptz not null default now()
);
create index riwayat_ai_pedagang on riwayat_ai (pedagang_id, jenis, dibuat desc);
