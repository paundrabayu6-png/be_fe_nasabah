const pool = require('../db/connection');

/* ──────────────────────────────────────────────────────────────
   DASHBOARD CONTROLLER (Admin)
   ────────────────────────────────────────────────────────────── */

/**
 * GET /api/dashboard/stats
 * Statistik utama untuk admin
 */
const getDashboardStats = async (req, res) => {
  try {
    // Total nasabah
    const [[{ total_nasabah }]] = await pool.query(
      "SELECT COUNT(*) as total_nasabah FROM nasabah WHERE status = 'aktif'"
    );

    // Total setoran (berat dan nilai) bulan ini
    const [[setoranBulanIni]] = await pool.query(`
      SELECT 
        COUNT(*) as jumlah,
        COALESCE(SUM(berat_kg), 0) as total_kg,
        COALESCE(SUM(total_saldo), 0) as total_nilai
      FROM setoran
      WHERE status = 'diterima'
        AND MONTH(tanggal) = MONTH(NOW())
        AND YEAR(tanggal) = YEAR(NOW())
    `);

    // Setoran menunggu verifikasi
    const [[{ menunggu_verifikasi }]] = await pool.query(
      "SELECT COUNT(*) as menunggu_verifikasi FROM setoran WHERE status IN ('menunggu','verifikasi')"
    );

    // Total saldo terdistribusi
    const [[{ total_saldo_terdistribusi }]] = await pool.query(
      "SELECT COALESCE(SUM(jumlah), 0) as total_saldo_terdistribusi FROM transaksi WHERE tipe = 'masuk' AND status = 'berhasil'"
    );

    // Grafik setoran 6 bulan
    const [grafik6Bulan] = await pool.query(`
      SELECT 
        DATE_FORMAT(tanggal, '%b') as bulan,
        MONTH(tanggal) as bulan_no,
        YEAR(tanggal) as tahun,
        COALESCE(SUM(berat_kg), 0) as total_kg,
        COALESCE(SUM(total_saldo), 0) as total_nilai,
        COUNT(*) as jumlah_setoran
      FROM setoran
      WHERE status = 'diterima'
        AND tanggal >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
      GROUP BY bulan_no, tahun, bulan
      ORDER BY tahun, bulan_no
    `);

    // Setoran terbaru
    const [setoranTerbaru] = await pool.query(`
      SELECT s.id, n.nama as nasabah, js.nama as jenis,
             s.berat_kg, s.total_saldo, s.status, s.tanggal
      FROM setoran s
      JOIN nasabah n ON n.id = s.nasabah_id
      JOIN jenis_sampah js ON js.id = s.jenis_id
      ORDER BY s.tanggal DESC
      LIMIT 5
    `);

    // Distribusi jenis sampah (pie chart)
    const [distribusiJenis] = await pool.query(`
      SELECT js.nama, SUM(s.berat_kg) as total_kg
      FROM setoran s
      JOIN jenis_sampah js ON js.id = s.jenis_id
      WHERE s.status = 'diterima'
        AND YEAR(s.tanggal) = YEAR(NOW())
      GROUP BY js.id, js.nama
      ORDER BY total_kg DESC
    `);

    return res.json({
      success: true,
      data: {
        total_nasabah,
        setoran_bulan_ini: {
          jumlah: setoranBulanIni.jumlah,
          total_kg: parseFloat(setoranBulanIni.total_kg),
          total_nilai: parseFloat(setoranBulanIni.total_nilai),
        },
        menunggu_verifikasi,
        total_saldo_terdistribusi: parseFloat(total_saldo_terdistribusi),
        grafik_6_bulan: grafik6Bulan,
        setoran_terbaru: setoranTerbaru,
        distribusi_jenis: distribusiJenis,
      },
    });
  } catch (err) {
    console.error('getDashboardStats error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/* ──────────────────────────────────────────────────────────────
   JENIS SAMPAH
   ────────────────────────────────────────────────────────────── */

/**
 * GET /api/jenis-sampah
 * (Public / Nasabah / Admin)
 */
const getAllJenisSampah = async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, nama, kode, harga_per_kg, satuan, keterangan, aktif FROM jenis_sampah ORDER BY nama'
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('getAllJenisSampah error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * PUT /api/jenis-sampah/:id
 * Admin: Update harga
 * Body: { harga_per_kg }
 */
const updateHargaJenis = async (req, res) => {
  try {
    const { id } = req.params;
    const { harga_per_kg, aktif } = req.body;

    if (harga_per_kg !== undefined && parseFloat(harga_per_kg) < 0) {
      return res.status(400).json({ success: false, message: 'Harga tidak valid' });
    }

    await pool.query(
      'UPDATE jenis_sampah SET harga_per_kg = COALESCE(?, harga_per_kg), aktif = COALESCE(?, aktif) WHERE id = ?',
      [harga_per_kg || null, aktif !== undefined ? aktif : null, id]
    );

    return res.json({ success: true, message: 'Jenis sampah berhasil diperbarui' });
  } catch (err) {
    console.error('updateHargaJenis error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/* ──────────────────────────────────────────────────────────────
   NOTIFIKASI
   ────────────────────────────────────────────────────────────── */

/**
 * GET /api/notifikasi/saya
 * Nasabah: Notifikasi milik sendiri
 */
const getNotifikasiSaya = async (req, res) => {
  try {
    const { id: nasabah_id } = req.user;
    const [rows] = await pool.query(
      'SELECT id, judul, pesan, tipe, sudah_dibaca, created_at FROM notifikasi WHERE nasabah_id = ? ORDER BY created_at DESC LIMIT 30',
      [nasabah_id]
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('getNotifikasiSaya error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * PUT /api/notifikasi/:id/baca
 * Nasabah: Tandai notifikasi sudah dibaca
 */
const tandaiBaca = async (req, res) => {
  try {
    const { id } = req.params;
    const { id: nasabah_id } = req.user;
    await pool.query(
      'UPDATE notifikasi SET sudah_dibaca = 1 WHERE id = ? AND nasabah_id = ?',
      [id, nasabah_id]
    );
    return res.json({ success: true, message: 'Notifikasi ditandai sudah dibaca' });
  } catch (err) {
    console.error('tandaiBaca error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * GET /api/notifikasi/admin
 * Admin: Daftar notifikasi seluruh nasabah
 */
const getNotifikasiAdmin = async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT n.id, n.nasabah_id, ns.nama as nasabah, n.judul, n.pesan,
              n.tipe, n.admin_dibaca as sudah_dibaca, n.created_at
       FROM notifikasi n
       LEFT JOIN nasabah ns ON ns.id = n.nasabah_id
       ORDER BY n.created_at DESC
       LIMIT 100`
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('getNotifikasiAdmin error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * PUT /api/notifikasi/admin/:id/baca
 * Admin: Tandai notifikasi sebagai dibaca tanpa mengubah status baca nasabah
 */
const tandaiBacaAdmin = async (req, res) => {
  try {
    await pool.query('UPDATE notifikasi SET admin_dibaca = 1 WHERE id = ?', [req.params.id]);
    return res.json({ success: true, message: 'Notifikasi admin ditandai sudah dibaca' });
  } catch (err) {
    console.error('tandaiBacaAdmin error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

const tandaiSemuaBacaAdmin = async (req, res) => {
  try {
    await pool.query('UPDATE notifikasi SET admin_dibaca = 1 WHERE admin_dibaca = 0');
    return res.json({ success: true, message: 'Semua notifikasi admin ditandai sudah dibaca' });
  } catch (err) {
    console.error('tandaiSemuaBacaAdmin error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/* ──────────────────────────────────────────────────────────────
   TITIK SETOR
   ────────────────────────────────────────────────────────────── */

/**
 * GET /api/titik-setor
 * (Public)
 */
const getAllTitikSetor = async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, nama, alamat, latitude, longitude, jam_buka, jam_tutup, status FROM titik_setor ORDER BY status DESC, nama'
    );
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error('getAllTitikSetor error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/* ──────────────────────────────────────────────────────────────
   LAPORAN (Admin)
   ────────────────────────────────────────────────────────────── */

/**
 * GET /api/laporan/setoran
 * Query: ?bulan=10&tahun=2026
 */
const getLaporanSetoran = async (req, res) => {
  try {
    const { bulan, tahun } = req.query;
    const filterBulan = bulan || new Date().getMonth() + 1;
    const filterTahun = tahun || new Date().getFullYear();

    const [rows] = await pool.query(`
      SELECT 
        s.id, n.nama as nasabah, n.telepon,
        js.nama as jenis, s.berat_kg, s.harga_per_kg, s.total_saldo,
        s.status, s.tanggal
      FROM setoran s
      JOIN nasabah n ON n.id = s.nasabah_id
      JOIN jenis_sampah js ON js.id = s.jenis_id
      WHERE MONTH(s.tanggal) = ? AND YEAR(s.tanggal) = ?
      ORDER BY s.tanggal DESC
    `, [filterBulan, filterTahun]);

    const [[summary]] = await pool.query(`
      SELECT 
        COUNT(*) as total_setoran,
        COALESCE(SUM(berat_kg), 0) as total_kg,
        COALESCE(SUM(total_saldo), 0) as total_nilai,
        COUNT(DISTINCT nasabah_id) as total_nasabah_aktif
      FROM setoran
      WHERE MONTH(tanggal) = ? AND YEAR(tanggal) = ? AND status = 'diterima'
    `, [filterBulan, filterTahun]);

    return res.json({ success: true, data: rows, summary });
  } catch (err) {
    console.error('getLaporanSetoran error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

module.exports = {
  getDashboardStats,
  getAllJenisSampah,
  updateHargaJenis,
  getNotifikasiSaya,
  tandaiBaca,
  getNotifikasiAdmin,
  tandaiBacaAdmin,
  tandaiSemuaBacaAdmin,
  getAllTitikSetor,
  getLaporanSetoran,
};
