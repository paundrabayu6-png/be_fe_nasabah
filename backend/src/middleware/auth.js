const jwt = require('jsonwebtoken');
const pool = require('../db/connection');

const JWT_SECRET = process.env.JWT_SECRET || 'resik_secret';

/**
 * Middleware: Verifikasi JWT token (untuk nasabah)
 */
const authNasabah = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, message: 'Token tidak ditemukan' });
  }

  let decoded;
  try {
    decoded = jwt.verify(token, JWT_SECRET);
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Token tidak valid atau kadaluarsa' });
  }

  if (decoded.role !== 'nasabah') {
    return res.status(403).json({ success: false, message: 'Akses ditolak' });
  }

  try {
    const [rows] = await pool.query(
      'SELECT token_version FROM nasabah WHERE id = ?',
      [decoded.id],
    );
    if (!rows.length ||
        Number(decoded.token_version || 0) !== Number(rows[0].token_version)) {
      return res.status(401).json({
        success: false,
        message: 'Sesi berakhir. Silakan masuk kembali.',
      });
    }
    req.user = decoded;
    return next();
  } catch (err) {
    console.error('authNasabah database error:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Gagal memvalidasi sesi. Coba lagi nanti.',
    });
  }
};

/**
 * Middleware: Verifikasi JWT token (untuk admin)
 */
const authAdmin = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, message: 'Token tidak ditemukan' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    if (!['admin', 'superadmin'].includes(decoded.role)) {
      return res.status(403).json({ success: false, message: 'Akses ditolak: bukan admin' });
    }
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Token tidak valid atau kadaluarsa' });
  }
};

/**
 * Generate JWT token
 */
const generateToken = (payload) => {
  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
};

module.exports = { authNasabah, authAdmin, generateToken };
