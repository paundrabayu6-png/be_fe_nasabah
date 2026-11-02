/**
 * seed.js — Data awal untuk testing
 * Usage: node src/db/seed.js
 */
const bcrypt = require('bcryptjs');
const pool = require('./connection');

async function seed() {
  const conn = await pool.getConnection();
  try {
    // Seed Admin
    const adminHash = await bcrypt.hash('admin123', 10);
    await conn.query(`
      INSERT IGNORE INTO admins (nama, email, password, role)
      VALUES
        ('Super Admin RESIK', 'admin@resik.id', ?, 'superadmin'),
        ('Petugas RW 03', 'petugas@resik.id', ?, 'admin')
    `, [adminHash, adminHash]);

    // Seed Nasabah
    const nasabahHash = await bcrypt.hash('nasabah123', 10);
    await conn.query(`
      INSERT IGNORE INTO nasabah (nama, telepon, email, password, alamat, saldo, total_setoran, status)
      VALUES
        ('Budi Santoso', '081234567890', 'budi@email.com', ?, 'Jl. Melati No. 5, Bekasi', 171770, 116.2, 'aktif'),
        ('Siti Rahayu', '081234567891', 'siti@email.com', ?, 'Jl. Mawar No. 10, Bekasi', 85000, 58.5, 'aktif'),
        ('Dika Pratama', '081234567892', 'dika@email.com', ?, 'Jl. Kenanga No. 3, Bekasi', 212450, 90.0, 'aktif'),
        ('Ahmad Fauzi', '081234567893', 'ahmad@email.com', ?, 'Jl. Anggrek No. 7, Bekasi', 0, 0, 'nonaktif')
    `, [nasabahHash, nasabahHash, nasabahHash, nasabahHash]);

    // Seed Jenis Sampah
    await conn.query(`
      INSERT IGNORE INTO jenis_sampah (nama, kode, harga_per_kg, keterangan)
      VALUES
        ('Plastik PET',    'PLASTIK_PET',  3500,  'Botol bening & kemasan plastik'),
        ('Kertas & Kardus','KERTAS',       2200,  'Koran, karton, buku'),
        ('Logam & Besi',   'LOGAM',        4000,  'Kaleng, besi tua'),
        ('Organik Dapur',  'ORGANIK',      1000,  'Eceng & sisa dapur'),
        ('Minyak Jelantah','MINYAK',       5000,  'Minyak goreng bekas'),
        ('Lainnya',        'LAINNYA',      1500,  'Sampah lain yang diterima')
    `);

    // Seed Setoran
    await conn.query(`
      INSERT IGNORE INTO setoran (nasabah_id, jenis_id, berat_kg, harga_per_kg, status, tanggal)
      VALUES
        (1, 1, 3.2,  3500, 'diterima', '2026-10-17 10:20:00'),
        (1, 2, 4.0,  2200, 'diterima', '2026-10-16 09:15:00'),
        (1, 3, 5.5,  4000, 'diterima', '2026-10-10 14:00:00'),
        (2, 1, 2.0,  3500, 'verifikasi', '2026-10-20 08:30:00'),
        (3, 5, 6.0,  5000, 'diterima', '2026-10-18 11:00:00'),
        (3, 2, 4.0,  2200, 'menunggu', '2026-10-21 08:00:00')
    `);

    // Seed Titik Setor
    await conn.query(`
      INSERT IGNORE INTO titik_setor (nama, alamat, latitude, longitude, jam_buka, jam_tutup, status)
      VALUES
        ('Pos Melati Indah', 'Jl. Bigum-guza Barat No. 12', -6.3979, 106.8210, '08:00', '17:00', 'buka'),
        ('Drop Point RW 05', 'Jl. Mawar Permai No. 3',      -6.4012, 106.8255, '07:00', '16:00', 'buka'),
        ('Bank Sampah Induk', 'Jl. Raya Bekasi Km 25',      -6.3950, 106.8300, '08:00', '15:00', 'tutup')
    `);

    // Seed Transaksi
    await conn.query(`
      INSERT IGNORE INTO transaksi (nasabah_id, tipe, jumlah, metode, nomor_tujuan, status, keterangan)
      VALUES
        (1, 'masuk',  11200, NULL, NULL, 'berhasil', 'Setoran Plastik PET'),
        (1, 'masuk',   8800, NULL, NULL, 'berhasil', 'Setoran Kertas'),
        (1, 'keluar', 150000, 'Gopay', '0812***', 'berhasil', 'Penarikan saldo'),
        (3, 'masuk',  30000, NULL, NULL, 'berhasil', 'Setoran Minyak Jelantah')
    `);

    // Seed Notifikasi
    await conn.query(`
      INSERT IGNORE INTO notifikasi (nasabah_id, judul, pesan, tipe)
      VALUES
        (1, 'Setoran Diterima!', 'Setoran Plastik PET 3.2 kg senilai Rp11.200 telah dikonfirmasi.', 'sukses'),
        (1, 'Target Tercapai!', 'Selamat! Target setor bulan Oktober sudah 100%. Bonus Rp10.000 akan masuk akhir bulan.', 'info'),
        (2, 'Setoran Menunggu Verifikasi', 'Setoran kamu sedang diverifikasi petugas. Tunggu ya!', 'info'),
        (3, 'Penarikan Berhasil', 'Penarikan Rp150.000 ke Gopay berhasil diproses.', 'sukses')
    `);

    console.log('✅ Seed data berhasil dimasukkan!');
  } catch (err) {
    console.error('❌ Seed gagal:', err.message);
  } finally {
    conn.release();
    pool.end();
  }
}

seed();
