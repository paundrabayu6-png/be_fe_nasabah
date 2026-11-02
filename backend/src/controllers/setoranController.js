const pool = require('../db/connection');

/* ──────────────────────────────────────────────────────────────
   SETORAN CONTROLLER
   ────────────────────────────────────────────────────────────── */

/**
 * GET /api/setoran
 * Admin: Lihat semua setoran
 * Query: ?status=menunggu&nasabah_id=1&page=1&limit=10
 */
const getAllSetoran = async (req, res) => {
  try {
    const { status, nasabah_id, search, page = 1, limit = 10 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let where = 'WHERE 1=1';
    const params = [];

    if (status) {
      where += ' AND s.status = ?';
      params.push(status);
    }
    if (nasabah_id) {
      where += ' AND s.nasabah_id = ?';
      params.push(nasabah_id);
    }
    if (search) {
      where += ' AND (n.nama LIKE ? OR CAST(s.id AS CHAR) LIKE ? OR CAST(s.nasabah_id AS CHAR) LIKE ?)';
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    const [rows] = await pool.query(
      `SELECT 
        s.id, n.nama as nasabah, s.nasabah_id,
        js.nama as jenis, js.kode as jenis_kode,
        s.berat_kg, s.harga_per_kg, s.total_saldo,
        s.status, s.catatan, s.tanggal,
        a.nama as diverifikasi_oleh
       FROM setoran s
       JOIN nasabah n ON n.id = s.nasabah_id
       JOIN jenis_sampah js ON js.id = s.jenis_id
       LEFT JOIN admins a ON a.id = s.diverifikasi_oleh
       ${where}
       ORDER BY s.tanggal DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );

    const [[{ total }]] = await pool.query(
      `SELECT COUNT(*) as total FROM setoran s JOIN nasabah n ON n.id = s.nasabah_id ${where}`,
      params
    );

    return res.json({
      success: true,
      data: rows,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), totalPages: Math.ceil(total / limit) },
    });
  } catch (err) {
    console.error('getAllSetoran error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * GET /api/setoran/saya
 * Nasabah: Riwayat setoran milik sendiri
 */
const getSetoranSaya = async (req, res) => {
  try {
    const { id: nasabah_id } = req.user;
    const { status, page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let where = 'WHERE s.nasabah_id = ?';
    const params = [nasabah_id];

    if (status) {
      where += ' AND s.status = ?';
      params.push(status);
    }

    const [rows] = await pool.query(
      `SELECT 
        s.id, js.nama as jenis, js.kode as jenis_kode,
        s.berat_kg, s.harga_per_kg, s.total_saldo,
        s.status, s.catatan, s.tanggal
       FROM setoran s
       JOIN jenis_sampah js ON js.id = s.jenis_id
       ${where}
       ORDER BY s.tanggal DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );

    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('getSetoranSaya error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * POST /api/setoran
 * Nasabah: Buat setoran baru
 * Body: { jenis_id, berat_kg }
 */
const createSetoran = async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const { id: nasabah_id } = req.user;
    const { jenis_id, berat_kg, catatan } = req.body;

    if (!jenis_id || !berat_kg) {
      return res.status(400).json({ success: false, message: 'jenis_id dan berat_kg wajib diisi' });
    }

    if (parseFloat(berat_kg) <= 0) {
      return res.status(400).json({ success: false, message: 'Berat harus lebih dari 0' });
    }

    // Ambil harga per kg dari jenis sampah
    const [jenis] = await conn.query(
      'SELECT id, nama, harga_per_kg FROM jenis_sampah WHERE id = ? AND aktif = 1',
      [jenis_id]
    );
    if (jenis.length === 0) {
      return res.status(404).json({ success: false, message: 'Jenis sampah tidak ditemukan' });
    }

    const harga_per_kg = jenis[0].harga_per_kg;

    await conn.beginTransaction();

    const [result] = await conn.query(
      'INSERT INTO setoran (nasabah_id, jenis_id, berat_kg, harga_per_kg, status, catatan) VALUES (?, ?, ?, ?, "menunggu", ?)',
      [nasabah_id, jenis_id, parseFloat(berat_kg), harga_per_kg, catatan || null]
    );

    // Insert notifikasi
    const totalSaldo = parseFloat(berat_kg) * harga_per_kg;
    await conn.query(
      `INSERT INTO notifikasi (nasabah_id, judul, pesan, tipe)
       VALUES (?, 'Setoran Dikirim', ?, 'info')`,
      [nasabah_id, `Setoran ${jenis[0].nama} ${berat_kg} kg (Rp${totalSaldo.toLocaleString('id-ID')}) sedang menunggu verifikasi petugas.`]
    );

    await conn.commit();

    return res.status(201).json({
      success: true,
      message: 'Setoran berhasil dikirim, menunggu verifikasi',
      data: { id: result.insertId, jenis: jenis[0].nama, berat_kg, harga_per_kg, total_saldo: totalSaldo, status: 'menunggu' },
    });
  } catch (err) {
    await conn.rollback();
    console.error('createSetoran error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  } finally {
    conn.release();
  }
};

/**
 * PUT /api/setoran/:id/verifikasi
 * Admin: Verifikasi / tolak setoran
 * Body: { status: 'diterima' | 'ditolak', catatan }
 */
const verifikasiSetoran = async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const { id } = req.params;
    const { status, catatan } = req.body;
    const adminId = req.user.id;

    if (!['diterima', 'ditolak'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Status harus "diterima" atau "ditolak"' });
    }

    const [setoran] = await conn.query(
      `SELECT s.*, js.nama as jenis_nama FROM setoran s JOIN jenis_sampah js ON js.id = s.jenis_id WHERE s.id = ?`,
      [id]
    );
    if (setoran.length === 0) {
      return res.status(404).json({ success: false, message: 'Setoran tidak ditemukan' });
    }

    const s = setoran[0];
    if (!['menunggu', 'verifikasi'].includes(s.status)) {
      return res.status(400).json({ success: false, message: 'Setoran sudah diproses sebelumnya' });
    }

    await conn.beginTransaction();

    await conn.query(
      'UPDATE setoran SET status = ?, catatan = ?, diverifikasi_oleh = ?, updated_at = NOW() WHERE id = ?',
      [status, catatan || null, adminId, id]
    );

    if (status === 'diterima') {
      // Tambahkan saldo dan total_setoran nasabah
      await conn.query(
        'UPDATE nasabah SET saldo = saldo + ?, total_setoran = total_setoran + ? WHERE id = ?',
        [s.total_saldo, s.berat_kg, s.nasabah_id]
      );

      // Catat transaksi masuk
      await conn.query(
        `INSERT INTO transaksi (nasabah_id, tipe, jumlah, status, keterangan)
         VALUES (?, 'masuk', ?, 'berhasil', ?)`,
        [s.nasabah_id, s.total_saldo, `Setoran ${s.jenis_nama} ${s.berat_kg} kg`]
      );

      // Notifikasi nasabah
      await conn.query(
        `INSERT INTO notifikasi (nasabah_id, judul, pesan, tipe)
         VALUES (?, 'Setoran Diterima!', ?, 'sukses')`,
        [s.nasabah_id, `Setoran ${s.jenis_nama} ${s.berat_kg} kg senilai Rp${parseFloat(s.total_saldo).toLocaleString('id-ID')} telah dikonfirmasi.`]
      );
    } else {
      // Notifikasi ditolak
      await conn.query(
        `INSERT INTO notifikasi (nasabah_id, judul, pesan, tipe)
         VALUES (?, 'Setoran Ditolak', ?, 'peringatan')`,
        [s.nasabah_id, `Setoran ${s.jenis_nama} ${s.berat_kg} kg ditolak. Alasan: ${catatan || 'tidak ada keterangan'}.`]
      );
    }

    await conn.commit();

    return res.json({ success: true, message: `Setoran berhasil ${status}` });
  } catch (err) {
    await conn.rollback();
    console.error('verifikasiSetoran error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  } finally {
    conn.release();
  }
};

/**
 * GET /api/setoran/:id
 */
const getSetoranById = async (req, res) => {
  try {
    const { id } = req.params;
    const [rows] = await pool.query(
      `SELECT 
        s.id, n.nama as nasabah, s.nasabah_id,
        js.nama as jenis, js.kode as jenis_kode,
        s.berat_kg, s.harga_per_kg, s.total_saldo,
        s.status, s.catatan, s.tanggal, s.updated_at,
        a.nama as diverifikasi_oleh
       FROM setoran s
       JOIN nasabah n ON n.id = s.nasabah_id
       JOIN jenis_sampah js ON js.id = s.jenis_id
       LEFT JOIN admins a ON a.id = s.diverifikasi_oleh
       WHERE s.id = ?`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Setoran tidak ditemukan' });
    }

    return res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error('getSetoranById error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

module.exports = { getAllSetoran, getSetoranSaya, createSetoran, verifikasiSetoran, getSetoranById };
