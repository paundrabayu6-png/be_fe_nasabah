require('dotenv').config();
const express = require('express');
const cors = require('cors');

// Inisialisasi koneksi DB
require('./db/connection');

// Routes
const authRoutes     = require('./routes/authRoutes');
const nasabahRoutes  = require('./routes/nasabahRoutes');
const setoranRoutes  = require('./routes/setoranRoutes');
const transaksiRoutes = require('./routes/transaksiRoutes');
const generalRoutes  = require('./routes/generalRoutes');

const app = express();

// ── MIDDLEWARE ──────────────────────────────────────────────────
app.use(cors({
  origin: [
    process.env.FRONTEND_URL || 'http://localhost:3000',
    'http://localhost:3001',   // Jika admin di port lain
    'http://localhost:8080',  // Flutter Web
    'http://127.0.0.1:8080',  // Flutter Web via loopback IP
    'http://localhost:8081',  // Flutter Web auth preview
    'http://127.0.0.1:8081',  // Flutter Web auth preview via loopback IP
  ],
  credentials: true,
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ── ROUTES ──────────────────────────────────────────────────────
app.use('/api/auth',     authRoutes);
app.use('/api/nasabah',  nasabahRoutes);
app.use('/api/setoran',  setoranRoutes);
app.use('/api/transaksi', transaksiRoutes);
app.use('/api',          generalRoutes);

// ── HEALTH CHECK ─────────────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    message: '🌿 RESIK Backend berjalan dengan baik',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// ── 404 HANDLER ──────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Endpoint ${req.method} ${req.url} tidak ditemukan` });
});

// ── ERROR HANDLER ────────────────────────────────────────────────
app.use((err, req, res, _next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ success: false, message: 'Terjadi kesalahan server' });
});

// ── START SERVER ─────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 RESIK Backend berjalan di http://localhost:${PORT}`);
  console.log(`📡 API: http://localhost:${PORT}/api`);
  console.log(`💚 Health: http://localhost:${PORT}/api/health`);
});

module.exports = app;
