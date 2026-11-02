const bcrypt = require('bcryptjs');
const pool = require('../db/connection');
const { generateToken } = require('../middleware/auth');

/* ──────────────────────────────────────────────────────────────
   NASABAH AUTH
   ────────────────────────────────────────────────────────────── */

/**
 * POST /api/auth/nasabah/register
 * Body: { nama, telepon, email, password, alamat }
 */
const registerNasabah = async (req, res) => {
  try {
    const { nama, telepon, email, password, alamat } = req.body;

    if (!nama || !telepon || !password) {
      return res.status(400).json({ success: false, message: 'Nama, telepon, dan password wajib diisi' });
    }

    // Cek duplikat telepon / email
    const [existing] = await pool.query(
      'SELECT id FROM nasabah WHERE telepon = ? OR (email IS NOT NULL AND email = ?)',
      [telepon, email || null]
    );
    if (existing.length > 0) {
      return res.status(409).json({ success: false, message: 'Nomor telepon atau email sudah terdaftar' });
    }

    const hashed = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO nasabah (nama, telepon, email, password, alamat) VALUES (?, ?, ?, ?, ?)',
      [nama, telepon, email || null, hashed, alamat || null]
    );

    const token = generateToken({
      id: result.insertId,
      role: 'nasabah',
      nama,
      token_version: 0,
    });

    return res.status(201).json({
      success: true,
      message: 'Registrasi berhasil',
      data: { id: result.insertId, nama, telepon, email },
      token,
    });
  } catch (err) {
    console.error('registerNasabah error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * POST /api/auth/nasabah/login
 * Body: { telepon_atau_email, password }
 */
const loginNasabah = async (req, res) => {
  try {
    const { telepon_atau_email, password } = req.body;

    if (!telepon_atau_email || !password) {
      return res.status(400).json({ success: false, message: 'Telepon/email dan password wajib diisi' });
    }

    const [rows] = await pool.query(
      'SELECT * FROM nasabah WHERE telepon = ? OR email = ? LIMIT 1',
      [telepon_atau_email, telepon_atau_email]
    );

    if (rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Akun tidak ditemukan' });
    }

    const nasabah = rows[0];
    if (nasabah.status === 'nonaktif') {
      return res.status(403).json({ success: false, message: 'Akun tidak aktif. Hubungi admin.' });
    }

    const match = await bcrypt.compare(password, nasabah.password);
    if (!match) {
      return res.status(401).json({ success: false, message: 'Password salah' });
    }

    const token = generateToken({
      id: nasabah.id,
      role: 'nasabah',
      nama: nasabah.nama,
      token_version: Number(nasabah.token_version || 0),
    });

    return res.json({
      success: true,
      message: 'Login berhasil',
      data: {
        id: nasabah.id,
        nama: nasabah.nama,
        telepon: nasabah.telepon,
        email: nasabah.email,
        saldo: nasabah.saldo,
        total_setoran: nasabah.total_setoran,
        status: nasabah.status,
      },
      token,
    });
  } catch (err) {
    console.error('loginNasabah error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/* ──────────────────────────────────────────────────────────────
   ADMIN AUTH
   ────────────────────────────────────────────────────────────── */

/**
 * POST /api/auth/admin/login
 * Body: { email, password }
 */
const loginAdmin = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email dan password wajib diisi' });
    }

    const [rows] = await pool.query(
      'SELECT * FROM admins WHERE email = ? LIMIT 1',
      [email]
    );

    if (rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Akun admin tidak ditemukan' });
    }

    const admin = rows[0];
    const match = await bcrypt.compare(password, admin.password);
    if (!match) {
      return res.status(401).json({ success: false, message: 'Password salah' });
    }

    const token = generateToken({ id: admin.id, role: admin.role, nama: admin.nama });

    return res.json({
      success: true,
      message: 'Login admin berhasil',
      data: {
        id: admin.id,
        nama: admin.nama,
        email: admin.email,
        role: admin.role,
      },
      token,
    });
  } catch (err) {
    console.error('loginAdmin error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

/**
 * POST /api/auth/admin/register
 * Body: { nama, email, telepon, password }
 * Account creation is restricted to an authenticated admin.
 */
const registerAdmin = async (req, res) => {
  try {
    const nama = typeof req.body.nama === 'string' ? req.body.nama.trim() : '';
    const email = typeof req.body.email === 'string'
      ? req.body.email.trim().toLowerCase()
      : '';
    const telepon = typeof req.body.telepon === 'string'
      ? req.body.telepon.trim()
      : '';
    const password = typeof req.body.password === 'string' ? req.body.password : '';

    if (!nama || !email || !telepon || !password) {
      return res.status(400).json({
        success: false,
        message: 'Nama, email, nomor telepon, dan password wajib diisi',
      });
    }
    if (nama.length > 100 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Nama atau format email tidak valid',
      });
    }
    if (!/^[+()\d\s.-]{8,20}$/.test(telepon) || password.length < 8) {
      return res.status(400).json({
        success: false,
        message: 'Nomor telepon tidak valid atau password kurang dari 8 karakter',
      });
    }

    const [existing] = await pool.query(
      'SELECT id FROM admins WHERE email = ? OR telepon = ? LIMIT 1',
      [email, telepon],
    );
    if (existing.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Email atau nomor telepon sudah terdaftar sebagai admin',
      });
    }

    const hashed = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO admins (nama, email, telepon, password, role) VALUES (?, ?, ?, ?, ?)',
      [nama, email, telepon, hashed, 'admin'],
    );

    return res.status(201).json({
      success: true,
      message: 'Akun admin berhasil dibuat',
      data: {
        id: result.insertId,
        nama,
        email,
        telepon,
        role: 'admin',
      },
    });
  } catch (err) {
    console.error('registerAdmin error:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan server saat membuat akun admin',
    });
  }
};

const logoutNasabah = async (req, res) => {
  try {
    await pool.query(
      'UPDATE nasabah SET token_version = token_version + 1 WHERE id = ?',
      [req.user.id],
    );
    return res.json({ success: true, message: 'Berhasil keluar dari akun' });
  } catch (err) {
    console.error('logoutNasabah error:', err);
    return res.status(500).json({ success: false, message: 'Gagal mengakhiri sesi' });
  }
};

/**
 * GET /api/auth/me
 * Header: Authorization: Bearer <token>
 */
const getMe = async (req, res) => {
  try {
    const { id, role } = req.user;
    let user;

    if (role === 'nasabah') {
      const [rows] = await pool.query(
        'SELECT id, nama, telepon, email, saldo, total_setoran, status, created_at FROM nasabah WHERE id = ?',
        [id]
      );
      user = rows[0];
    } else {
      const [rows] = await pool.query(
        'SELECT id, nama, email, role, created_at FROM admins WHERE id = ?',
        [id]
      );
      user = rows[0];
    }

    if (!user) {
      return res.status(404).json({ success: false, message: 'Pengguna tidak ditemukan' });
    }

    return res.json({ success: true, data: { ...user, role } });
  } catch (err) {
    console.error('getMe error:', err);
    return res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
  }
};

module.exports = {
  registerNasabah,
  loginNasabah,
  loginAdmin,
  registerAdmin,
  logoutNasabah,
  getMe,
};
