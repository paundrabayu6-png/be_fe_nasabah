# RESIK Nasabah (Flutter)

Aplikasi nasabah RESIK terhubung ke RESIK Backend di `http://localhost:5000/api`
untuk web dan `http://10.0.2.2:5000/api` untuk Android emulator. Nilai dasar URL
bisa diubah dengan `--dart-define=API_BASE_URL=http://<host>:5000/api`.

Jalankan backend, migrasikan database, dan isi data demo lebih dulu. Kemudian
jalankan preview Flutter Web:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Untuk Android emulator, jalankan `flutter run` dan gunakan API default `10.0.2.2`.
Pada perangkat fisik, gunakan IP LAN komputer melalui `API_BASE_URL`.

Login demo nasabah dibuat oleh `backend/src/db/seed.js`.

Dashboard nasabah memakai `GET /api/nasabah/dashboard/saya` untuk mengambil
ringkasan akun, setoran bulanan, aktivitas, harga material, notifikasi, dan
titik setor dari backend.

Alur lupa password mengirim OTP ke email nasabah melalui konfigurasi SMTP.
Lihat `backend/README.md` untuk environment SMTP dan migrasi tabel OTP.
# RESIK-Lingkungan-Bank-Sampah-Digital
