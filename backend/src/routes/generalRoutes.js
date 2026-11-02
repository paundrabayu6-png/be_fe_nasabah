const express = require('express');
const router = express.Router();
const {
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
} = require('../controllers/dashboardController');
const { authNasabah, authAdmin } = require('../middleware/auth');

// ─── DASHBOARD (Admin only) ────────────────────────────────────
router.get('/stats', authAdmin, getDashboardStats);

// ─── JENIS SAMPAH (Public + Admin update) ─────────────────────
router.get('/jenis-sampah', getAllJenisSampah);
router.put('/jenis-sampah/:id', authAdmin, updateHargaJenis);

// ─── NOTIFIKASI (Nasabah) ─────────────────────────────────────
router.get('/notifikasi/saya', authNasabah, getNotifikasiSaya);
router.put('/notifikasi/:id/baca', authNasabah, tandaiBaca);
router.get('/notifikasi/admin', authAdmin, getNotifikasiAdmin);
router.put('/notifikasi/admin/:id/baca', authAdmin, tandaiBacaAdmin);
router.put('/notifikasi/admin/baca-semua', authAdmin, tandaiSemuaBacaAdmin);

// ─── TITIK SETOR (Public) ─────────────────────────────────────
router.get('/titik-setor', getAllTitikSetor);

// ─── LAPORAN (Admin) ──────────────────────────────────────────
router.get('/laporan/setoran', authAdmin, getLaporanSetoran);

module.exports = router;
