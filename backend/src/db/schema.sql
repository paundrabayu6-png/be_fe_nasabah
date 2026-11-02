-- ============================================================
--  RESIK Bank Sampah - Database Schema
--  MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS resik_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE resik_db;

-- ============================================================
-- 1. ADMIN
-- ============================================================
CREATE TABLE IF NOT EXISTS admins (
  id          INT          AUTO_INCREMENT PRIMARY KEY,
  nama        VARCHAR(100) NOT NULL,
  email       VARCHAR(150) NOT NULL UNIQUE,
  telepon     VARCHAR(20)  UNIQUE,
  password    VARCHAR(255) NOT NULL,
  role        ENUM('superadmin','admin') DEFAULT 'admin',
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================================
-- 2. NASABAH
-- ============================================================
CREATE TABLE IF NOT EXISTS nasabah (
  id            INT          AUTO_INCREMENT PRIMARY KEY,
  nama          VARCHAR(100) NOT NULL,
  telepon       VARCHAR(20)  NOT NULL UNIQUE,
  email         VARCHAR(150) UNIQUE,
  password      VARCHAR(255) NOT NULL,
  alamat        TEXT,
  nik           VARCHAR(20),
  jenis_tempat  VARCHAR(40),
  alamat_lengkap TEXT,
  rt            VARCHAR(5),
  rw            VARCHAR(5),
  kelurahan     VARCHAR(100),
  kecamatan     VARCHAR(100),
  kota          VARCHAR(100),
  latitude      DECIMAL(10,8),
  longitude     DECIMAL(11,8),
  saldo         DECIMAL(12,2) DEFAULT 0.00,
  total_setoran DECIMAL(10,3) DEFAULT 0.000,  -- dalam kg
  status        ENUM('aktif','nonaktif') DEFAULT 'aktif',
  token_version INT UNSIGNED NOT NULL DEFAULT 0,
  created_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================================
-- 2A. METODE PENCAIRAN NASABAH
-- ============================================================
CREATE TABLE IF NOT EXISTS rekening_pencairan (
  id             INT          AUTO_INCREMENT PRIMARY KEY,
  nasabah_id     INT UNSIGNED NOT NULL,
  metode         VARCHAR(50)  NOT NULL,
  nama_pemilik   VARCHAR(100) NOT NULL,
  nomor_rekening VARCHAR(100) NOT NULL,
  utama          TINYINT(1)   NOT NULL DEFAULT 0,
  created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_rekening_nasabah (nasabah_id),
  FOREIGN KEY (nasabah_id) REFERENCES nasabah(id) ON DELETE CASCADE
);

-- ============================================================
-- 3. ONE-TIME PASSWORD RESET CODES
-- ============================================================
CREATE TABLE IF NOT EXISTS password_reset_otps (
  id          BIGINT       AUTO_INCREMENT PRIMARY KEY,
  email_hash  CHAR(64)     NOT NULL UNIQUE,
  nasabah_id  INT UNSIGNED NULL,
  otp_hash    CHAR(64)     NOT NULL,
  attempts    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  expires_at  DATETIME     NULL,
  sent_at     DATETIME     NULL,
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_password_reset_expires (expires_at),
  INDEX idx_password_reset_created (created_at),
  FOREIGN KEY (nasabah_id) REFERENCES nasabah(id) ON DELETE SET NULL
);

-- ============================================================
-- 4. JENIS SAMPAH & HARGA
-- ============================================================
CREATE TABLE IF NOT EXISTS jenis_sampah (
  id          INT          AUTO_INCREMENT PRIMARY KEY,
  nama        VARCHAR(100) NOT NULL,
  kode        VARCHAR(30)  NOT NULL UNIQUE,
  harga_per_kg DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  satuan      VARCHAR(20)  DEFAULT 'kg',
  keterangan  TEXT,
  aktif       TINYINT(1)   DEFAULT 1,
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================================
-- 5. SETORAN
-- ============================================================
CREATE TABLE IF NOT EXISTS setoran (
  id            INT          AUTO_INCREMENT PRIMARY KEY,
  nasabah_id    INT          NOT NULL,
  jenis_id      INT          NOT NULL,
  berat_kg      DECIMAL(10,3) NOT NULL,
  harga_per_kg  DECIMAL(10,2) NOT NULL,
  total_saldo   DECIMAL(12,2) GENERATED ALWAYS AS (berat_kg * harga_per_kg) STORED,
  status        ENUM('menunggu','verifikasi','diterima','ditolak') DEFAULT 'menunggu',
  catatan       TEXT,
  diverifikasi_oleh INT,
  tanggal       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (nasabah_id)        REFERENCES nasabah(id) ON DELETE CASCADE,
  FOREIGN KEY (jenis_id)          REFERENCES jenis_sampah(id),
  FOREIGN KEY (diverifikasi_oleh) REFERENCES admins(id) ON DELETE SET NULL
);

-- ============================================================
-- 6. TRANSAKSI SALDO (penarikan / tukar saldo)
-- ============================================================
CREATE TABLE IF NOT EXISTS transaksi (
  id          INT           AUTO_INCREMENT PRIMARY KEY,
  nasabah_id  INT           NOT NULL,
  tipe        ENUM('masuk','keluar') NOT NULL,   -- masuk=setoran, keluar=penarikan
  jumlah      DECIMAL(12,2) NOT NULL,
  metode      VARCHAR(50),     -- Gopay, Dana, BCA, dll
  nomor_tujuan VARCHAR(100),
  status      ENUM('pending','berhasil','gagal') DEFAULT 'pending',
  keterangan  TEXT,
  created_at  TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (nasabah_id) REFERENCES nasabah(id) ON DELETE CASCADE
);

-- ============================================================
-- 7. NOTIFIKASI
-- ============================================================
CREATE TABLE IF NOT EXISTS notifikasi (
  id          INT          AUTO_INCREMENT PRIMARY KEY,
  nasabah_id  INT,
  judul       VARCHAR(200) NOT NULL,
  pesan       TEXT         NOT NULL,
  tipe        ENUM('info','sukses','peringatan','error') DEFAULT 'info',
  sudah_dibaca TINYINT(1)  DEFAULT 0,
  admin_dibaca TINYINT(1)  DEFAULT 0,
  created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (nasabah_id) REFERENCES nasabah(id) ON DELETE CASCADE
);

-- ============================================================
-- 8. TITIK SETOR (drop point)
-- ============================================================
CREATE TABLE IF NOT EXISTS titik_setor (
  id          INT          AUTO_INCREMENT PRIMARY KEY,
  nama        VARCHAR(150) NOT NULL,
  alamat      TEXT,
  latitude    DECIMAL(10,8),
  longitude   DECIMAL(11,8),
  jam_buka    TIME,
  jam_tutup   TIME,
  status      ENUM('buka','tutup') DEFAULT 'buka',
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);
