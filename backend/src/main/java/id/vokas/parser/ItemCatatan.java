package id.vokas.parser;

import id.vokas.model.Jenis;

/** Satu baris transaksi hasil membaca catatan pedagang. jumlah, satuan, hargaSatuan boleh null. */
public record ItemCatatan(Jenis jenis, String nama, Integer jumlah, String satuan, Long hargaSatuan, long total) {}
