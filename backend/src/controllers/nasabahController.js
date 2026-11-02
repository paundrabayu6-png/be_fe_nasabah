const pool = require('../db/connection');

/* ──────────────────────────────────────────────────────────────
   NASABAH CONTROLLER (untuk admin)
   ────────────────────────────────────────────────────────────── */

/**
 * GET /api/nasabah
 * Query: ?status=aktif&search=nama&page=1&limit=10
 */
const getAllNasabah = async (req, res) => {
  try {
    const { status, search, page = 1, limit = 10 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let where = 'WHERE 1=1';
    const params = [];

    if (status) {
      where += ' AND n.status = ?';
      params.push(status);
    }
    if (search) {
      where += ' AND (n.nama LIKE ? OR n.telepon LIKE ? OR CAST(n.id AS CHAR) LIKE ?)';
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    const [rows] = await pool.query(
      `SELECT 
        n.id, n.nama, n.telepon, n.email, n.alamat,
        n.saldo, n.total_setoran, n.status, n.created_at,
        COUNT(s.id) as jumlah_setoran
       FROM nasabah n
       LEFT JOIN setoran s ON s.nasabah_id = n.id
       ${where}
       GROUP BY n.id
       ORDER BY n.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );

    const [[{ total }]] = await pool.query(
      `SELECT COUNT(*) as total FROM nasabah n ${where}`,
      params
    );

    return res.json({
      success: true,
      data: rows,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), totalPages: Math.ceil(total / limit) },
    });
  } catch (err) {
    console.error('getAllNasabah error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * GET /api/nasabah/:id
 */
const getNasabahById = async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query(
      `SELECT 
        n.id, n.nama, n.telepon, n.email, n.alamat,
        n.saldo, n.total_setoran, n.status, n.created_at,
        COUNT(s.id) as jumlah_setoran
       FROM nasabah n
       LEFT JOIN setoran s ON s.nasabah_id = n.id
       WHERE n.id = ?
       GROUP BY n.id`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Nasabah tidak ditemukan' });
    }

    return res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error('getNasabahById error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * PUT /api/nasabah/:id/status
 * Body: { status: 'aktif' | 'nonaktif' }
 */
const updateStatusNasabah = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!['aktif', 'nonaktif'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Status tidak valid' });
    }

    await pool.query('UPDATE nasabah SET status = ? WHERE id = ?', [status, id]);

    return res.json({ success: true, message: `Nasabah berhasil di-${status}kan` });
  } catch (err) {
    console.error('updateStatusNasabah error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * GET /api/nasabah/:id/riwayat
 */
const getRiwayatNasabah = async (req, res) => {
  try {
    const { id } = req.params;
    const [setoran] = await pool.query(
      `SELECT s.id, js.nama as jenis, s.berat_kg, s.harga_per_kg, s.total_saldo, 
              s.status, s.tanggal
       FROM setoran s
       JOIN jenis_sampah js ON js.id = s.jenis_id
       WHERE s.nasabah_id = ?
       ORDER BY s.tanggal DESC
       LIMIT 20`,
      [id]
    );

    return res.json({ success: true, data: setoran });
  } catch (err) {
    console.error('getRiwayatNasabah error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/* ──────────────────────────────────────────────────────────────
   PROFIL NASABAH (self-service)
   ────────────────────────────────────────────────────────────── */

/**
 * GET /api/nasabah/profil/saya
 * (nasabah login)
 */
const getProfilSaya = async (req, res) => {
  try {
    const { id } = req.user;
    const [rows] = await pool.query(
      `SELECT 
        n.id, n.nama, n.telepon, n.email, n.alamat, n.nik,
        n.jenis_tempat, n.alamat_lengkap, n.rt, n.rw,
        n.kelurahan, n.kecamatan, n.kota, n.latitude, n.longitude,
        n.saldo, n.total_setoran, n.status, n.created_at,
        (SELECT COUNT(*) FROM setoran WHERE nasabah_id = n.id AND status = 'diterima') as jumlah_setoran,
        (SELECT COUNT(*) FROM transaksi WHERE nasabah_id = n.id AND tipe = 'keluar' AND status = 'berhasil') as jumlah_penarikan
       FROM nasabah n
       WHERE n.id = ?`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Nasabah tidak ditemukan' });
    }

    return res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error('getProfilSaya error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * GET /api/nasabah/dashboard/saya
 * Ringkasan dashboard untuk nasabah yang sedang login.
 */
const getDashboardSaya = async (req, res) => {
  try {
    const { id } = req.user;
    const [profiles] = await pool.query(
      `SELECT id, nama, saldo, total_setoran
       FROM nasabah
       WHERE id = ?`,
      [id]
    );

    if (profiles.length === 0) {
      return res.status(404).json({ success: false, message: 'Nasabah tidak ditemukan' });
    }

    const [[summary]] = await pool.query(
      `SELECT
         (SELECT COUNT(*) FROM transaksi WHERE nasabah_id = ?) AS jumlah_transaksi,
         (SELECT COALESCE(SUM(jumlah), 0)
          FROM transaksi
          WHERE nasabah_id = ? AND tipe = 'masuk' AND status = 'berhasil'
            AND YEAR(created_at) = YEAR(CURDATE())
            AND MONTH(created_at) = MONTH(CURDATE())) AS saldo_masuk_bulan_ini,
         (SELECT COUNT(*) FROM notifikasi
          WHERE nasabah_id = ? AND sudah_dibaca = 0) AS notifikasi_belum_dibaca`,
      [id, id, id]
    );

    const [monthlyDeposits] = await pool.query(
      `SELECT YEAR(tanggal) AS tahun, MONTH(tanggal) AS bulan,
              COALESCE(SUM(berat_kg), 0) AS total_kg
       FROM setoran
       WHERE nasabah_id = ? AND status = 'diterima'
         AND tanggal >= DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 5 MONTH)
       GROUP BY YEAR(tanggal), MONTH(tanggal)
       ORDER BY tahun, bulan`,
      [id]
    );

    const [recentDeposits] = await pool.query(
      `SELECT s.id, js.nama AS jenis, s.berat_kg, s.total_saldo,
              s.status, s.tanggal
       FROM setoran s
       JOIN jenis_sampah js ON js.id = s.jenis_id
       WHERE s.nasabah_id = ?
       ORDER BY s.tanggal DESC
       LIMIT 5`,
      [id]
    );

    const [recentTransactions] = await pool.query(
      `SELECT id, tipe, jumlah, metode, status, keterangan, created_at
       FROM transaksi
       WHERE nasabah_id = ?
       ORDER BY created_at DESC
       LIMIT 5`,
      [id]
    );

    const [prices] = await pool.query(
      `SELECT id, nama, kode, harga_per_kg, satuan, keterangan
       FROM jenis_sampah
       WHERE aktif = 1
       ORDER BY nama`
    );

    const [dropPoints] = await pool.query(
      `SELECT id, nama, alamat, latitude, longitude, jam_buka, jam_tutup, status
       FROM titik_setor
       ORDER BY (status = 'buka') DESC, nama`
    );

    return res.json({
      success: true,
      data: {
        profile: profiles[0],
        summary,
        monthly_deposits: monthlyDeposits,
        recent_deposits: recentDeposits,
        recent_transactions: recentTransactions,
        prices,
        drop_points: dropPoints,
      },
    });
  } catch (err) {
    console.error('getDashboardSaya error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * PUT /api/nasabah/profil/update
 * Body: { nama, alamat, email }
 */
const updateProfil = async (req, res) => {
  try {
    const { id } = req.user;
    const fields = {
      nama: ['nama', (value) => value.trim()],
      email: ['email', (value) => value.trim().toLowerCase() || null],
      alamat: ['alamat', (value) => value.trim() || null],
      nik: ['nik', (value) => value.trim() || null],
      jenis_tempat: ['jenis_tempat', (value) => value.trim() || null],
      alamat_lengkap: ['alamat_lengkap', (value) => value.trim() || null],
      rt: ['rt', (value) => value.trim() || null],
      rw: ['rw', (value) => value.trim() || null],
      kelurahan: ['kelurahan', (value) => value.trim() || null],
      kecamatan: ['kecamatan', (value) => value.trim() || null],
      kota: ['kota', (value) => value.trim() || null],
    };
    const updates = [];
    const values = [];

    for (const [key, [column, normalize]] of Object.entries(fields)) {
      if (!Object.prototype.hasOwnProperty.call(req.body, key)) continue;
      const value = req.body[key];
      if (value !== null && typeof value !== 'string') {
        return res.status(400).json({ success: false, message: `Format ${key} tidak valid` });
      }
      const normalized = value === null ? null : normalize(value);
      if (key === 'nama' && !normalized) {
        return res.status(400).json({ success: false, message: 'Nama wajib diisi' });
      }
      if (key === 'email' && normalized && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalized)) {
        return res.status(400).json({ success: false, message: 'Format email tidak valid' });
      }
      if (key === 'nik' && normalized && !/^\d{16}$/.test(normalized)) {
        return res.status(400).json({ success: false, message: 'NIK harus terdiri dari 16 digit' });
      }
      updates.push(`\`${column}\` = ?`);
      values.push(normalized);
    }

    for (const key of ['latitude', 'longitude']) {
      if (!Object.prototype.hasOwnProperty.call(req.body, key)) continue;
      const value = req.body[key];
      if (value === null || value === '') {
        updates.push(`\`${key}\` = NULL`);
        continue;
      }
      const coordinate = Number(value);
      const limit = key === 'latitude' ? 90 : 180;
      if (!Number.isFinite(coordinate) || coordinate < -limit || coordinate > limit) {
        return res.status(400).json({ success: false, message: `Koordinat ${key} tidak valid` });
      }
      updates.push(`\`${key}\` = ?`);
      values.push(coordinate);
    }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'Tidak ada perubahan profil' });
    }
    await pool.query(`UPDATE nasabah SET ${updates.join(', ')} WHERE id = ?`, [...values, id]);

    return res.json({ success: true, message: 'Profil berhasil diperbarui' });
  } catch (err) {
    console.error('updateProfil error:', err);
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ success: false, message: 'Email sudah digunakan akun lain' });
    }
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

const getMetodePencairanSaya = async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT id, metode, nama_pemilik, nomor_rekening, utama, created_at
       FROM rekening_pencairan
       WHERE nasabah_id = ?
       ORDER BY utama DESC, created_at DESC`,
      [req.user.id],
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('getMetodePencairanSaya error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

const tambahMetodePencairan = async (req, res) => {
  const { metode, nama_pemilik, nomor_rekening } = req.body;
  const metodeDiizinkan = ['GoPay', 'DANA', 'OVO', 'ShopeePay', 'BCA', 'BRI', 'BNI', 'Mandiri'];
  if (!metodeDiizinkan.includes(metode)) {
    return res.status(400).json({ success: false, message: 'Metode pencairan tidak valid' });
  }
  if (typeof nama_pemilik !== 'string' || !nama_pemilik.trim() ||
      typeof nomor_rekening !== 'string' || !nomor_rekening.trim()) {
    return res.status(400).json({ success: false, message: 'Nama pemilik dan nomor rekening wajib diisi' });
  }
  if (nama_pemilik.trim().length > 100 || nomor_rekening.trim().length > 100) {
    return res.status(400).json({ success: false, message: 'Data rekening terlalu panjang' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [existing] = await connection.query(
      'SELECT id FROM rekening_pencairan WHERE nasabah_id = ? LIMIT 1 FOR UPDATE',
      [req.user.id],
    );
    const [result] = await connection.query(
      `INSERT INTO rekening_pencairan
        (nasabah_id, metode, nama_pemilik, nomor_rekening, utama)
       VALUES (?, ?, ?, ?, ?)`,
      [req.user.id, metode, nama_pemilik.trim(), nomor_rekening.trim(), existing.length ? 0 : 1],
    );
    await connection.commit();
    return res.status(201).json({
      success: true,
      message: 'Metode pencairan berhasil ditambahkan',
      data: { id: result.insertId, metode, nama_pemilik: nama_pemilik.trim(), nomor_rekening: nomor_rekening.trim(), utama: existing.length ? 0 : 1 },
    });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error('tambahMetodePencairan error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  } finally {
    if (connection) connection.release();
  }
};

const jadikanMetodePencairanUtama = async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [rows] = await connection.query(
      'SELECT id FROM rekening_pencairan WHERE id = ? AND nasabah_id = ? FOR UPDATE',
      [req.params.id, req.user.id],
    );
    if (!rows.length) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Metode pencairan tidak ditemukan' });
    }
    await connection.query(
      'UPDATE rekening_pencairan SET utama = 0 WHERE nasabah_id = ?',
      [req.user.id],
    );
    await connection.query(
      'UPDATE rekening_pencairan SET utama = 1 WHERE id = ? AND nasabah_id = ?',
      [req.params.id, req.user.id],
    );
    await connection.commit();
    return res.json({ success: true, message: 'Metode utama berhasil diperbarui' });
  } catch (err) {
    await connection.rollback();
    console.error('jadikanMetodePencairanUtama error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  } finally {
    connection.release();
  }
};

module.exports = {
  getAllNasabah,
  getNasabahById,
  updateStatusNasabah,
  getRiwayatNasabah,
  getDashboardSaya,
  getProfilSaya,
  updateProfil,
  getMetodePencairanSaya,
  tambahMetodePencairan,
  jadikanMetodePencairanUtama,
};
