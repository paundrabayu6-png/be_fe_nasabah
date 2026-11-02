# RESIK Backend

## Registrasi admin

`POST /api/auth/admin/register` menerima `nama`, `email`, `telepon`, dan
`password`. Endpoint ini hanya dapat dipakai oleh admin yang sudah masuk
dengan token Bearer. Akun baru selalu dibuat dengan role `admin`; role
`superadmin` tidak dapat diberikan melalui formulir registrasi.

Jalankan `npm run migrate` agar kolom telepon admin tersedia pada database
yang sudah ada.

## Password reset nasabah

Pemulihan password menggunakan kode OTP 6 digit yang dikirim ke email akun
nasabah. OTP berlaku 10 menit, hanya dapat dicoba 5 kali, dan permintaan ulang
dibatasi sekali per menit per email serta 5 kali per 15 menit per alamat IP.
Respons permintaan kode tidak mengungkap apakah suatu email terdaftar.
Setelah password berhasil diubah, sesi login nasabah yang lama dicabut.

Atur konfigurasi berikut di `.env` backend sebelum mengaktifkan alur:

```env
PASSWORD_RESET_SECRET=<random secret at least 32 bytes>
SMTP_HOST=<SMTP server>
SMTP_PORT=587
SMTP_USER=<SMTP account>
SMTP_PASS=<SMTP app password>
SMTP_FROM=RESIK <no-reply@example.com>
```

Buat secret reset yang berbeda dari `JWT_SECRET`:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Jangan commit `.env` atau kredensial SMTP. Setelah mengisi environment, jalankan
migrasi schema lalu restart backend:

```bash
npm run migrate
npm start
```

Endpoint aplikasi:

- `GET /api/nasabah/dashboard/saya` (Bearer token nasabah) mengembalikan profil,
  ringkasan saldo/transaksi/notifikasi, setoran enam bulan, aktivitas terbaru,
  harga material aktif, dan titik setor.
- `POST /api/auth/nasabah/password-reset/request` dengan `{ "email": "..." }`
- `POST /api/auth/nasabah/password-reset/complete` dengan `{ "email": "...", "otp": "123456", "password": "password-baru" }`

Profil nasabah juga menyediakan endpoint `GET /api/nasabah/profil/saya` dan
`PUT /api/nasabah/profil/update` untuk membaca serta memperbarui data profil
dan alamat.

Metode pencairan dikelola melalui `GET /api/nasabah/rekening/saya`,
`POST /api/nasabah/rekening`, dan `PUT /api/nasabah/rekening/:id/utama`.
Endpoint tersebut hanya mengakses rekening milik nasabah yang sedang login.
`POST /api/auth/nasabah/logout` mencabut sesi nasabah di server.

Jalankan `npm run migrate` setelah pembaruan backend untuk menambahkan kolom
profil dan tabel rekening pencairan.

Password baru minimal 8 karakter. Kode reset dan email disimpan dalam bentuk
HMAC, dan kode hanya dapat digunakan satu kali.
