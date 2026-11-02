const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const nodemailer = require('nodemailer');
const pool = require('../db/connection');

const OTP_TTL_MINUTES = 10;
const OTP_RESEND_SECONDS = 60;
const MAX_OTP_ATTEMPTS = 5;

const genericRequestMessage =
  'Jika email terdaftar, kode verifikasi akan dikirim. Periksa kotak masuk atau folder spam.';
const invalidCodeMessage = 'Kode tidak valid atau sudah kedaluwarsa.';

function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function getResetSecret() {
  const secret = process.env.PASSWORD_RESET_SECRET;
  if (!secret || Buffer.byteLength(secret) < 32) {
    throw new Error('PASSWORD_RESET_SECRET must contain at least 32 bytes');
  }
  return secret;
}

function hashValue(value) {
  return crypto
    .createHmac('sha256', getResetSecret())
    .update(value)
    .digest('hex');
}

function isValidEmail(email) {
  return email.length <= 150 && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email);
}

function createTransport() {
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;
  const port = Number(SMTP_PORT);
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS || !Number.isInteger(port)) {
    throw new Error('SMTP_HOST, SMTP_PORT, SMTP_USER and SMTP_PASS are required');
  }

  return nodemailer.createTransport({
    host: SMTP_HOST,
    port,
    secure: port === 465,
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 15000,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
}

async function requestPasswordReset(req, res) {
  const email = normalizeEmail(req.body?.email);
  if (!isValidEmail(email)) {
    return res.status(400).json({ success: false, message: 'Masukkan alamat email yang valid.' });
  }

  let secret;
  let transporter;
  try {
    secret = getResetSecret();
    transporter = createTransport();
  } catch (error) {
    console.error('Password reset configuration error:', error.message);
    return res.status(503).json({
      success: false,
      message: 'Layanan reset password belum tersedia. Silakan hubungi admin.',
    });
  }

  const emailHash = crypto
    .createHmac('sha256', secret)
    .update(email)
    .digest('hex');
  let conn;
  let transactionStarted = false;

  try {
    conn = await pool.getConnection();
    await conn.beginTransaction();
    transactionStarted = true;
    await conn.query(
      'DELETE FROM password_reset_otps WHERE created_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY)',
    );
    await conn.query(
      `INSERT INTO password_reset_otps
        (email_hash, otp_hash, attempts, expires_at, sent_at)
       VALUES (?, ?, 0, NULL, NULL)
       ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)`,
      [emailHash, crypto.randomBytes(32).toString('hex')],
    );

    const [resetRows] = await conn.query(
      'SELECT id, sent_at FROM password_reset_otps WHERE email_hash = ? FOR UPDATE',
      [emailHash],
    );
    const reset = resetRows[0];
    const [customerRows] = await conn.query(
      `SELECT id, nama, email FROM nasabah
       WHERE LOWER(email) = ? AND status = 'aktif' LIMIT 1`,
      [email],
    );

    const [cooldownRows] = await conn.query(
      `SELECT sent_at > DATE_SUB(UTC_TIMESTAMP(), INTERVAL ${OTP_RESEND_SECONDS} SECOND) AS cooling_down
       FROM password_reset_otps WHERE id = ?`,
      [reset.id],
    );

    if (cooldownRows[0].cooling_down) {
      await conn.commit();
      transactionStarted = false;
      return res.json({ success: true, message: genericRequestMessage });
    }

    const customer = customerRows[0];
    if (customer) {
      const otp = crypto.randomInt(100000, 1000000).toString();
      await conn.query(
        `UPDATE password_reset_otps
         SET nasabah_id = ?, otp_hash = ?, attempts = 0,
             expires_at = DATE_ADD(UTC_TIMESTAMP(), INTERVAL ? MINUTE),
             sent_at = UTC_TIMESTAMP()
         WHERE id = ?`,
        [customer.id, hashValue(otp), OTP_TTL_MINUTES, reset.id],
      );
    } else {
      await conn.query(
        `UPDATE password_reset_otps
         SET nasabah_id = NULL, otp_hash = ?, attempts = 0,
             expires_at = NULL, sent_at = UTC_TIMESTAMP()
         WHERE id = ?`,
        [crypto.randomBytes(32).toString('hex'), reset.id],
      );
    }
    await conn.commit();
    transactionStarted = false;

    if (customer) {
      try {
        await transporter.sendMail({
          from: process.env.SMTP_FROM || process.env.SMTP_USER,
          to: customer.email,
          subject: 'Kode reset password RESIK',
          text: `Halo ${customer.nama},\n\nKode verifikasi reset password RESIK Anda adalah ${otp}. Kode berlaku selama ${OTP_TTL_MINUTES} menit. Jangan bagikan kode ini kepada siapa pun.\n\nJika Anda tidak meminta reset password, abaikan email ini.`,
          html: `<p>Halo ${escapeHtml(customer.nama)},</p><p>Kode verifikasi reset password RESIK Anda:</p><p style="font-size:28px;font-weight:bold;letter-spacing:6px">${otp}</p><p>Kode berlaku selama ${OTP_TTL_MINUTES} menit. Jangan bagikan kode ini kepada siapa pun.</p><p>Jika Anda tidak meminta reset password, abaikan email ini.</p>`,
        });
      } catch (error) {
        await pool.query(
          `UPDATE password_reset_otps
           SET nasabah_id = NULL, otp_hash = ?, expires_at = NULL
           WHERE id = ?`,
          [crypto.randomBytes(32).toString('hex'), reset.id],
        );
        console.error('Password reset email delivery failed:', error.message);
      }
    }

    return res.json({ success: true, message: genericRequestMessage });
  } catch (error) {
    if (conn && transactionStarted) await conn.rollback();
    console.error('Password reset request failed:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Permintaan reset password gagal diproses. Coba lagi nanti.',
    });
  } finally {
    if (conn) conn.release();
  }
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[character]);
}

async function completePasswordReset(req, res) {
  const email = normalizeEmail(req.body?.email);
  const otp = typeof req.body?.otp === 'string' ? req.body.otp.trim() : '';
  const password = typeof req.body?.password === 'string' ? req.body.password : '';

  if (!isValidEmail(email) || !/^\d{6}$/.test(otp) || password.length < 8) {
    return res.status(400).json({
      success: false,
      message: 'Email, kode 6 digit, dan password minimal 8 karakter diperlukan.',
    });
  }

  let submittedHash;
  try {
    submittedHash = hashValue(otp);
  } catch (error) {
    console.error('Password reset configuration error:', error.message);
    return res.status(503).json({
      success: false,
      message: 'Layanan reset password belum tersedia. Silakan hubungi admin.',
    });
  }

  const emailHash = hashValue(email);
  let conn;
  let transactionStarted = false;
  try {
    conn = await pool.getConnection();
    await conn.beginTransaction();
    transactionStarted = true;
    const [rows] = await conn.query(
      `SELECT id, nasabah_id, otp_hash, attempts,
              expires_at > UTC_TIMESTAMP() AS is_valid
       FROM password_reset_otps
       WHERE email_hash = ? AND sent_at > DATE_SUB(UTC_TIMESTAMP(), INTERVAL ${OTP_TTL_MINUTES * 60} SECOND)
       FOR UPDATE`,
      [emailHash],
    );
    const reset = rows[0];

    if (!reset || !reset.nasabah_id || !reset.is_valid || reset.attempts >= MAX_OTP_ATTEMPTS) {
      if (conn) await conn.rollback();
      transactionStarted = false;
      return res.status(400).json({ success: false, message: invalidCodeMessage });
    }

    const expectedHash = Buffer.from(reset.otp_hash, 'hex');
    const actualHash = Buffer.from(submittedHash, 'hex');
    const matches = expectedHash.length === actualHash.length &&
      crypto.timingSafeEqual(expectedHash, actualHash);

    if (!matches) {
      await conn.query(
        'UPDATE password_reset_otps SET attempts = attempts + 1 WHERE id = ?',
        [reset.id],
      );
      await conn.commit();
      transactionStarted = false;
      return res.status(400).json({ success: false, message: invalidCodeMessage });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const [updatedCustomer] = await conn.query(
      'UPDATE nasabah SET password = ?, token_version = token_version + 1 WHERE id = ? AND status = ?',
      [passwordHash, reset.nasabah_id, 'aktif'],
    );
    if (!updatedCustomer.affectedRows) {
      await conn.rollback();
      transactionStarted = false;
      return res.status(400).json({ success: false, message: invalidCodeMessage });
    }
    await conn.query(
      'DELETE FROM password_reset_otps WHERE nasabah_id = ?',
      [reset.nasabah_id],
    );
    await conn.commit();
    transactionStarted = false;

    return res.json({
      success: true,
      message: 'Password berhasil diubah. Silakan masuk menggunakan password baru.',
    });
  } catch (error) {
    if (conn && transactionStarted) await conn.rollback();
    console.error('Password reset completion failed:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Password gagal diubah. Coba lagi nanti.',
    });
  } finally {
    if (conn) conn.release();
  }
}

module.exports = { requestPasswordReset, completePasswordReset };
