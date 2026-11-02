/**
 * migrate.js — Jalankan schema SQL ke database
 * Usage: node src/db/migrate.js
 */
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config();

async function migrate() {
  let conn;
  try {
    // Konek tanpa database dulu untuk bisa CREATE DATABASE
    conn = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT) || 3306,
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      multipleStatements: true,
    });

    const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf-8');
    await conn.query(sql);

    const ensureColumns = async (table, columns) => {
      const [existing] = await conn.query(`SHOW COLUMNS FROM \`${table}\``);
      const names = new Set(existing.map((column) => column.Field));
      for (const [name, definition] of columns) {
        if (!names.has(name)) {
          await conn.query(`ALTER TABLE \`${table}\` ADD COLUMN \`${name}\` ${definition}`);
        }
      }
    };

    await ensureColumns('admins', [
      ['telepon', 'VARCHAR(20) NULL UNIQUE'],
    ]);
    await ensureColumns('jenis_sampah', [
      ['satuan', "VARCHAR(20) DEFAULT 'kg'"],
      ['aktif', 'TINYINT(1) DEFAULT 1'],
    ]);
    await ensureColumns('setoran', [
      ['total_saldo', 'DECIMAL(12,2) GENERATED ALWAYS AS (berat_kg * harga_per_kg) STORED'],
      ['catatan', 'TEXT'],
      ['diverifikasi_oleh', 'INT NULL'],
    ]);
    await ensureColumns('notifikasi', [
      ['sudah_dibaca', 'TINYINT(1) DEFAULT 0'],
      ['admin_dibaca', 'TINYINT(1) DEFAULT 0'],
    ]);
    await ensureColumns('nasabah', [
      ['token_version', 'INT UNSIGNED NOT NULL DEFAULT 0'],
      ['nik', 'VARCHAR(20) NULL'],
      ['jenis_tempat', 'VARCHAR(40) NULL'],
      ['alamat_lengkap', 'TEXT NULL'],
      ['rt', 'VARCHAR(5) NULL'],
      ['rw', 'VARCHAR(5) NULL'],
      ['kelurahan', 'VARCHAR(100) NULL'],
      ['kecamatan', 'VARCHAR(100) NULL'],
      ['kota', 'VARCHAR(100) NULL'],
      ['latitude', 'DECIMAL(10,8) NULL'],
      ['longitude', 'DECIMAL(11,8) NULL'],
    ]);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS rekening_pencairan (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nasabah_id INT UNSIGNED NOT NULL,
        metode VARCHAR(50) NOT NULL,
        nama_pemilik VARCHAR(100) NOT NULL,
        nomor_rekening VARCHAR(100) NOT NULL,
        utama TINYINT(1) NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_rekening_nasabah (nasabah_id),
        FOREIGN KEY (nasabah_id) REFERENCES nasabah(id) ON DELETE CASCADE
      )
    `);

    const indexes = [
      ['setoran', 'idx_setoran_nasabah', 'nasabah_id'],
      ['setoran', 'idx_setoran_status', 'status'],
      ['transaksi', 'idx_transaksi_nasabah', 'nasabah_id'],
      ['notifikasi', 'idx_notifikasi_nasabah', 'nasabah_id'],
      ['password_reset_otps', 'idx_password_reset_created', 'created_at'],
    ];
    for (const [table, name, column] of indexes) {
      const [existing] = await conn.query(`SHOW INDEX FROM \`${table}\` WHERE Key_name = ?`, [name]);
      if (existing.length === 0) {
        await conn.query(`CREATE INDEX \`${name}\` ON \`${table}\` (\`${column}\`)`);
      }
    }
    console.log('✅ Migrasi database berhasil!');
  } catch (err) {
    console.error('❌ Migrasi gagal:', err.message);
    process.exit(1);
  } finally {
    if (conn) await conn.end();
  }
}

migrate();
