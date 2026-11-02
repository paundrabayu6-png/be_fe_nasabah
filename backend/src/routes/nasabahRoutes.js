const express = require('express');
const router = express.Router();
const {
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
} = require('../controllers/nasabahController');
const { authNasabah, authAdmin } = require('../middleware/auth');

// ─── SELF-SERVICE (Nasabah) ───────────────────────────────────
router.get('/dashboard/saya', authNasabah, getDashboardSaya);
router.get('/profil/saya', authNasabah, getProfilSaya);
router.put('/profil/update', authNasabah, updateProfil);
router.get('/rekening/saya', authNasabah, getMetodePencairanSaya);
router.post('/rekening', authNasabah, tambahMetodePencairan);
router.put('/rekening/:id/utama', authNasabah, jadikanMetodePencairanUtama);

// ─── ADMIN ONLY ───────────────────────────────────────────────
router.get('/', authAdmin, getAllNasabah);
router.get('/:id', authAdmin, getNasabahById);
router.put('/:id/status', authAdmin, updateStatusNasabah);
router.get('/:id/riwayat', authAdmin, getRiwayatNasabah);

module.exports = router;
