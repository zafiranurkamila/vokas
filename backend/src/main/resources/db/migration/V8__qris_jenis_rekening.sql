-- Jenis rekening BRI penampung dana QRIS (Simpedes, Simpedes UMi, BritAma, dll.)
alter table pengajuan_qris add column jenis_rekening varchar(40);
