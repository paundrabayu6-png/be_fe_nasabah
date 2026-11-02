const express = require('express');
const { rateLimit } = require('express-rate-limit');
const router = express.Router();
const {
  registerNasabah,
  loginNasabah,
  loginAdmin,
  registerAdmin,
  logoutNasabah,
  getMe,
} = require('../controllers/authController');
const {
  requestPasswordReset,
  completePasswordReset,
} = require('../controllers/passwordResetController');
const { authNasabah, authAdmin } = require('../middleware/auth');

// Nasabah auth
router.post('/nasabah/register', registerNasabah);
router.post('/nasabah/login', loginNasabah);
router.post('/nasabah/logout', authNasabah, logoutNasabah);
router.post(
  '/nasabah/password-reset/request',
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 5,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: {
      success: false,
      message: 'Terlalu banyak permintaan. Coba lagi beberapa saat.',
    },
  }),
  requestPasswordReset,
);
router.post(
  '/nasabah/password-reset/complete',
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 10,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: {
      success: false,
      message: 'Terlalu banyak percobaan. Coba lagi beberapa saat.',
    },
  }),
  completePasswordReset,
);

// Admin auth
router.post('/admin/login', loginAdmin);
router.post('/admin/register', authAdmin, registerAdmin);

// Get current user (nasabah atau admin), validating nasabah token version too.
router.get('/me', (req, res, next) => {
  const jwt = require('jsonwebtoken');
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ success: false, message: 'Token tidak ditemukan' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'resik_secret');
    req.user = decoded;
    if (decoded.role === 'nasabah') return authNasabah(req, res, next);
    if (['admin', 'superadmin'].includes(decoded.role)) {
      return authAdmin(req, res, next);
    }
    return res.status(403).json({ success: false, message: 'Akses ditolak' });
  } catch {
    return res.status(401).json({ success: false, message: 'Token tidak valid' });
  }
}, getMe);

module.exports = router;
