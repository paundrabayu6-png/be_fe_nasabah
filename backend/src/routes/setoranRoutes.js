const express = require('express');
const router = express.Router();
const {
  getAllSetoran,
  getSetoranSaya,
  createSetoran,
  verifikasiSetoran,
  getSetoranById,
} = require('../controllers/setoranController');
const { authNasabah, authAdmin } = require('../middleware/auth');

// ─── NASABAH ───────────────────────────────────────────────────
router.get('/saya', authNasabah, getSetoranSaya);
router.post('/', authNasabah, createSetoran);

// ─── ADMIN ─────────────────────────────────────────────────────
router.get('/', authAdmin, getAllSetoran);
router.get('/:id', authAdmin, getSetoranById);
router.put('/:id/verifikasi', authAdmin, verifikasiSetoran);

module.exports = router;
