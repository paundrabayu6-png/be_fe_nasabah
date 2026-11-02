const pool = require('../db/connection');

/* ──────────────────────────────────────────────────────────────
   TRANSAKSI / PENARIKAN SALDO
   ────────────────────────────────────────────────────────────── */

/**
 * POST /api/transaksi/tarik
 * Nasabah: Tarik / tukar saldo
 * Body: { jumlah, metode, nomor_tujuan }
 */
const tarikSaldo = async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const { id: nasabah_id } = req.user;
    const { jumlah, metode, nomor_tujuan } = req.body;

    const MINIMAL_TARIK = 50000;
    const BIAYA_LAYANAN = 1000;

    if (!jumlah || !metode || !nomor_tujuan) {
      return res.status(400).json({ success: false, message: 'Jumlah, metode, dan nomor_tujuan wajib diisi' });
    }

    const jumlahInt = parseInt(jumlah);
    if (jumlahInt < MINIMAL_TARIK) {
      return res.status(400).json({ success: false, message: `Minimal penarikan Rp${MINIMAL_TARIK.toLocaleString('id-ID')}` });
    }

    // Cek saldo
    const [rows] = await conn.query('SELECT saldo FROM nasabah WHERE id = ?', [nasabah_id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Nasabah tidak ditemukan' });
    }

    const saldo = parseFloat(rows[0].saldo);
    const totalKeluar = jumlahInt + BIAYA_LAYANAN;

    if (saldo < totalKeluar) {
      return res.status(400).json({ success: false, message: 'Saldo tidak cukup (termasuk biaya layanan Rp1.000)' });
    }

    await conn.beginTransaction();

    // Kurangi saldo
    await conn.query(
      'UPDATE nasabah SET saldo = saldo - ? WHERE id = ?',
      [totalKeluar, nasabah_id]
    );

    // Catat transaksi
    const [result] = await conn.query(
      `INSERT INTO transaksi (nasabah_id, tipe, jumlah, metode, nomor_tujuan, status, keterangan)
       VALUES (?, 'keluar', ?, ?, ?, 'berhasil', ?)`,
      [nasabah_id, jumlahInt, metode, nomor_tujuan, `Penarikan ke ${metode} - ${nomor_tujuan}`]
    );

    // Notifikasi
    await conn.query(
      `INSERT INTO notifikasi (nasabah_id, judul, pesan, tipe)
       VALUES (?, 'Penarikan Berhasil', ?, 'sukses')`,
      [nasabah_id, `Penarikan Rp${jumlahInt.toLocaleString('id-ID')} ke ${metode} (${nomor_tujuan}) berhasil diproses.`]
    );

    await conn.commit();

    return res.json({
      success: true,
      message: 'Penarikan berhasil',
      data: { id: result.insertId, jumlah: jumlahInt, biaya_layanan: BIAYA_LAYANAN, metode, nomor_tujuan, saldo_akhir: saldo - totalKeluar },
    });
  } catch (err) {
    await conn.rollback();
    console.error('tarikSaldo error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  } finally {
    conn.release();
  }
};

/**
 * GET /api/transaksi/saya
 * Nasabah: Riwayat transaksi sendiri
 */
const getRiwayatTransaksiSaya = async (req, res) => {
  try {
    const { id: nasabah_id } = req.user;
    const { tipe, page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let where = 'WHERE t.nasabah_id = ?';
    const params = [nasabah_id];

    if (tipe) {
      where += ' AND t.tipe = ?';
      params.push(tipe);
    }

    const [rows] = await pool.query(
      `SELECT id, tipe, jumlah, metode, nomor_tujuan, status, keterangan, created_at
       FROM transaksi t
       ${where}
       ORDER BY created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );

    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('getRiwayatTransaksiSaya error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * GET /api/transaksi
 * Admin: Semua transaksi
 */
const getAllTransaksi = async (req, res) => {
  try {
    const { tipe, nasabah_id, page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let where = 'WHERE 1=1';
    const params = [];

    if (tipe) { where += ' AND t.tipe = ?'; params.push(tipe); }
    if (nasabah_id) { where += ' AND t.nasabah_id = ?'; params.push(nasabah_id); }

    const [rows] = await pool.query(
      `SELECT t.id, n.nama as nasabah, t.nasabah_id,
              t.tipe, t.jumlah, t.metode, t.nomor_tujuan, t.status, t.keterangan, t.created_at
       FROM transaksi t
       JOIN nasabah n ON n.id = t.nasabah_id
       ${where}
       ORDER BY t.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );

    const [[{ total }]] = await pool.query(
      `SELECT COUNT(*) as total FROM transaksi t ${where}`, params
    );

    return res.json({
      success: true,
      data: rows,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), totalPages: Math.ceil(total / limit) },
    });
  } catch (err) {
    console.error('getAllTransaksi error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

module.exports = { tarikSaldo, getRiwayatTransaksiSaya, getAllTransaksi };
