import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nasabah_resik/main.dart';
import 'package:nasabah_resik/services/api_service.dart';

void main() {
  testWidgets('Layar login tampil', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Lupa Password?'), findsOneWidget);
    expect(find.text('Lanjut dengan Google'), findsOneWidget);
  });

  testWidgets('Ikon daun membuka chatbot dan tombol kembali menutupnya', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    await tester.tap(find.byKey(const Key('dashboard-chatbot-button')));
    await tester.pump();
    expect(find.text('Asisten DaurUang'), findsOneWidget);
    expect(find.text('Harga sampah hari ini?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chatbot-back-button')));
    await tester.pump();
    expect(find.byKey(const Key('dashboard-chatbot-button')), findsOneWidget);
  });

  testWidgets('Avatar dashboard membuka tab Profil', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    await tester.tap(find.byKey(const Key('dashboard-profile-button')));
    await tester.pump();

    expect(find.byKey(const Key('nasabah-profile-tab')), findsOneWidget);
  });

  testWidgets('Chatbot mengirim pesan dan memberi jawaban sesuai topik', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatPage())),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('chatbot-suggestion-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Cara setor sampah?'), findsNWidgets(2));
    expect(
      find.textContaining('Pisahkan dan bersihkan sampah'),
      findsOneWidget,
    );
  });

  testWidgets('Login memulihkan pilihan Ingat saya dan nomor akun tersimpan', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'resik_remember_me': true,
      'resik_remembered_login': '081234567890',
    });

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '081234567890',
    );
  });

  testWidgets(
    'Ingat saya langsung menyimpan akun dan tidak mengingat password',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'dhika@example.com');
      await tester.pumpAndSettle();

      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('resik_remember_me'), isTrue);
      expect(prefs.getString('resik_remembered_login'), 'dhika@example.com');
      expect(prefs.getString('resik_password'), isNull);

      await ApiService.saveToken('test-session-token');
      await ApiService.logout();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('resik_token'), isNull);
      expect(prefs.getBool('resik_remember_me'), isTrue);
      expect(prefs.getString('resik_remembered_login'), 'dhika@example.com');

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('resik_remember_me'), isFalse);
      expect(prefs.getString('resik_remembered_login'), isNull);
    },
  );

  testWidgets('Login menampilkan popup saat kredensial belum diisi', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Data belum lengkap'), findsOneWidget);
    expect(
      find.text('Masukkan nomor telepon atau email dan password untuk masuk.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.text('Data belum lengkap'), findsNothing);
  });

  testWidgets('Lupa password membuka form email dan memvalidasi email', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lupa Password?'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Masukkan email yang terhubung dengan akun RESIK untuk menerima kode verifikasi.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Kirim Kode'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan alamat email yang valid.'), findsOneWidget);
  });

  testWidgets('Lupa password dapat dibuka dari tab profil', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lupa Password?'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Masukkan email yang terhubung dengan akun RESIK untuk menerima kode verifikasi.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Profil menampilkan data API dan popup kelola rekening', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilNasabahPage(
          loadProfile: () async => {
            'data': {
              'nama': 'Dhika Ahmad',
              'telepon': '08123456789',
              'email': 'dhika@example.com',
              'nik': '1234567890123456',
              'jenis_tempat': 'Rumah Tangga',
              'alamat_lengkap': 'Jl. Sigura-gura',
              'rt': '005',
              'rw': '012',
              'kelurahan': 'Sigura-gura',
              'kecamatan': 'Lowokwaru',
              'kota': 'Malang',
              'latitude': '-7.95',
              'longitude': '112.61',
            },
          },
          loadPaymentMethods: () async => {'data': <dynamic>[]},
          pickProfilePhoto: () async => Uint8List.fromList([1, 2, 3]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dhika Ahmad'), findsNWidgets(2));
    expect(find.text('Member Gold'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-photo-button')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('resik_profile_photo_guest'), isNotNull);
    expect(find.byKey(const Key('profile-photo-image')), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Belum ada metode pencairan. Tambahkan rekening atau e-wallet.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Tambah Metode Pencairan'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Rekening Pencairan'), findsOneWidget);
    expect(find.text('Nomor Akun / Nomor Rekening'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Keluar dari Akun'));
    await tester.tap(find.text('Keluar dari Akun'));
    await tester.pumpAndSettle();
    expect(find.text('Yakin mau keluar?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Yakin mau keluar?'), findsNothing);
  });

  testWidgets('Registrasi menolak nomor tidak valid lalu lanjut ke password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterStep1()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Siti Aminah');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.ensureVisible(find.text('Lanjut'));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Nomor belum valid'), findsOneWidget);
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar Akun'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '+62 812 3456 7890');
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Satu langkah lagi!'), findsOneWidget);
  });

  testWidgets(
    'Sesi tanpa pilihan ingat saya tidak dipertahankan saat dibuka ulang',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await ApiService.saveToken('test-session-token');
      await ApiService.saveRememberMe(false);

      await tester.pumpWidget(const MaterialApp(home: SessionGate()));
      await tester.pumpAndSettle();

      expect(find.text('Selamat Datang'), findsOneWidget);
      expect(await ApiService.isLoggedIn(), isFalse);
    },
  );

  testWidgets('Tab setor menampilkan fallback jika API tidak tersedia', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Setor'));
    await tester.pumpAndSettle();

    expect(find.text('Data jenis sampah belum tersedia.'), findsOneWidget);
  });

  testWidgets('Tab tukar tetap tampil tanpa riwayat penarikan', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    await tester.tap(find.text('Tukar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Belum ada riwayat penarikan'), findsOneWidget);
  });

  testWidgets('Tukar meminta nomor tujuan lalu memberi popup saldo kurang', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Tukar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.ensureVisible(find.text('Tukar Sekarang'));
    await tester.tap(find.text('Tukar Sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan nomor tujuan'), findsOneWidget);

    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();
    expect(find.text('Nomor tujuan wajib diisi.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('exchange-destination-dialog-field')),
      '081234567890',
    );
    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();

    expect(find.text('Saldo tidak cukup'), findsOneWidget);
    expect(find.textContaining('Saldo tersedia'), findsOneWidget);
    expect(find.text('Ubah nominal'), findsOneWidget);
  });
}
