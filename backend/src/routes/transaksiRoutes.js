const express = require('express');
const router = express.Router();
const {
  tarikSaldo,
  getRiwayatTransaksiSaya,
  getAllTransaksi,
} = require('../controllers/transaksiController');
const { authNasabah, authAdmin } = require('../middleware/auth');

// ─── NASABAH ───────────────────────────────────────────────────
router.post('/tarik', authNasabah, tarikSaldo);
router.get('/saya', authNasabah, getRiwayatTransaksiSaya);

// ─── ADMIN ─────────────────────────────────────────────────────
router.get('/', authAdmin, getAllTransaksi);

module.exports = router;
