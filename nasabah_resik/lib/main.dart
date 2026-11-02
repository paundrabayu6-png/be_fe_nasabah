import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nasabah_resik/services/api_service.dart';

void main() => runApp(const ResikApp());

// ---------------------------------------------------------------
// WARNA & HELPER
// ---------------------------------------------------------------
class AppColors {
  static const bg = Color(0xFFF3EEE3); // krem
  static const dark = Color(0xFF17472A); // hijau tua
  static const green = Color(0xFF3B7A2F); // hijau
  static const orange = Color(0xFFE8582B); // aksen
  static const muted = Color(0xFF7A7A6E); // teks abu
}

String rupiah(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp $buf';
}

/// Font judul / angka besar (serif display seperti di desain).
/// Kalau di Figma fontnya beda, ganti GoogleFonts.fraunces di sini saja.
TextStyle display({
  double size = 14,
  FontWeight weight = FontWeight.w800,
  Color color = AppColors.dark,
}) => GoogleFonts.fraunces(fontSize: size, fontWeight: weight, color: color);

Future<void> _showAuthPopup(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  Color accent = AppColors.orange,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.dark, width: 1.5),
        boxShadow: const [
          BoxShadow(color: AppColors.dark, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 31),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: display(size: 22)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Mengerti',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

// ---------------------------------------------------------------
// APP
// ---------------------------------------------------------------
class ResikApp extends StatelessWidget {
  const ResikApp({super.key});

  // google_fonts v9 punya tipe TextTheme sendiri, jadi font dipasang
  // per-style ke TextTheme bawaan Flutter.
  TextTheme _spaceGrotesk(TextTheme t) {
    TextStyle? f(TextStyle? s) =>
        s == null ? null : GoogleFonts.spaceGrotesk(textStyle: s);
    return t.copyWith(
      displayLarge: f(t.displayLarge),
      displayMedium: f(t.displayMedium),
      displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge),
      headlineMedium: f(t.headlineMedium),
      headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge),
      titleMedium: f(t.titleMedium),
      titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge),
      bodyMedium: f(t.bodyMedium),
      bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge),
      labelMedium: f(t.labelMedium),
      labelSmall: f(t.labelSmall),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green),
      useMaterial3: true,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RESIK',
      theme: base.copyWith(textTheme: _spaceGrotesk(base.textTheme)),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<bool> _session = _checkSession();

  Future<bool> _checkSession() async {
    if (!await ApiService.isLoggedIn()) return false;
    if (!await ApiService.shouldRememberMe()) {
      await ApiService.logout();
      return false;
    }
    try {
      await ApiService.getProfilSaya();
      return true;
    } on ApiException {
      await ApiService.logout();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Tidak dapat memeriksa sesi ke server RESIK: ${snapshot.error}',
              ),
            ),
          ),
        );
      }
      return snapshot.data == true ? const MainShell() : const LoginScreen();
    },
  );
}

// ---------------------------------------------------------------
// SHELL: halaman + bottom navigation
// ---------------------------------------------------------------
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  bool showNotifications = false;
  bool showChat = false;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        onNotifications: () => setState(() {
          showNotifications = true;
          showChat = false;
        }),
        onChat: () => setState(() {
          showChat = true;
          showNotifications = false;
        }),
        onProfile: () => setState(() {
          index = 4;
          showChat = false;
          showNotifications = false;
        }),
      ),
      TukarSaldoPage(onBack: () => setState(() => index = 0)),
      SetorPage(onBack: () => setState(() => index = 0)),
      RiwayatPage(onBack: () => setState(() => index = 0)),
      ProfilNasabahPage(
        key: const Key('nasabah-profile-tab'),
        onBack: () => setState(() => index = 0),
        onChat: () => setState(() {
          showChat = true;
          showNotifications = false;
        }),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: showChat
            ? ChatPage(onBack: () => setState(() => showChat = false))
            : showNotifications
            ? NotifikasiNasabahPage(
                onBack: () => setState(() => showNotifications = false),
              )
            : pages[index],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE6DFCF)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_outlined, 'Beranda'),
              _navItem(1, Icons.account_balance_wallet_outlined, 'Tukar'),
              _navItem(2, Icons.recycling_rounded, 'Setor'),
              _navItem(3, Icons.receipt_long_outlined, 'Riwayat'),
              _navItem(4, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final active = index == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        index = i;
        showChat = false;
        showNotifications = false;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? AppColors.orange : AppColors.dark),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: active ? AppColors.orange : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilNasabahPage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function()? loadProfile;
  final Future<Map<String, dynamic>> Function()? loadPaymentMethods;
  final Future<Uint8List?> Function()? pickProfilePhoto;
  final VoidCallback? onBack;
  final VoidCallback? onChat;

  const ProfilNasabahPage({
    super.key,
    this.loadProfile,
    this.loadPaymentMethods,
    this.pickProfilePhoto,
    this.onBack,
    this.onChat,
  });

  @override
  State<ProfilNasabahPage> createState() => _ProfilNasabahPageState();
}

class _ProfilNasabahPageState extends State<ProfilNasabahPage> {
  final Map<String, TextEditingController> _fields = {
    for (final key in [
      'nama',
      'telepon',
      'email',
      'nik',
      'alamatLengkap',
      'rt',
      'rw',
      'kelurahan',
      'kecamatan',
      'kota',
      'latitude',
      'longitude',
    ])
      key: TextEditingController(),
  };
  List<Map<String, dynamic>> _paymentMethods = [];
  String _jenisTempat = 'Rumah Tangga';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Uint8List? _profilePhoto;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    unawaited(_loadProfilePhoto());
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        widget.loadProfile?.call() ?? ApiService.getProfilSaya(),
        widget.loadPaymentMethods?.call() ??
            ApiService.getMetodePencairanSaya(),
      ]);
      final data = responses[0]['data'];
      final paymentRows = responses[1]['data'];
      if (data is! Map<String, dynamic> || paymentRows is! List<dynamic>) {
        throw const FormatException('Data profil tidak valid.');
      }
      final values = <String, String>{
        'nama': '${data['nama'] ?? ''}',
        'telepon': '${data['telepon'] ?? ''}',
        'email': '${data['email'] ?? ''}',
        'nik': '${data['nik'] ?? ''}',
        'alamatLengkap': '${data['alamat_lengkap'] ?? data['alamat'] ?? ''}',
        'rt': '${data['rt'] ?? ''}',
        'rw': '${data['rw'] ?? ''}',
        'kelurahan': '${data['kelurahan'] ?? ''}',
        'kecamatan': '${data['kecamatan'] ?? ''}',
        'kota': '${data['kota'] ?? ''}',
        'latitude': '${data['latitude'] ?? ''}',
        'longitude': '${data['longitude'] ?? ''}',
      };
      for (final entry in values.entries) {
        _fields[entry.key]!.text = entry.value == 'null' ? '' : entry.value;
      }
      final types = ['Rumah Tangga', 'Sekolah', 'Kantor', 'Usaha'];
      final savedType = '${data['jenis_tempat'] ?? types.first}';
      setState(() {
        _jenisTempat = types.contains(savedType) ? savedType : types.first;
        _paymentMethods = paymentRows
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat profil dari server: $error';
      });
    }
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final photo = await ApiService.getProfilePhoto();
      if (mounted) setState(() => _profilePhoto = photo);
    } catch (error) {
      if (!mounted) return;
      await _showAuthPopup(
        context,
        title: 'Foto profil tidak dapat dimuat',
        message: 'Periksa penyimpanan foto profil dan coba lagi. $error',
        icon: Icons.broken_image_outlined,
      );
    }
  }

  Future<void> _changeProfilePhoto() async {
    try {
      final photo = widget.pickProfilePhoto != null
          ? await widget.pickProfilePhoto!()
          : await _pickProfilePhotoFromGallery();
      if (photo == null || !mounted) return;
      if (photo.lengthInBytes > 2 * 1024 * 1024) {
        await _showAuthPopup(
          context,
          title: 'Ukuran foto terlalu besar',
          message: 'Pilih foto dengan ukuran maksimal 2 MB.',
          icon: Icons.image_not_supported_outlined,
        );
        return;
      }
      await ApiService.saveProfilePhoto(photo);
      if (!mounted) return;
      setState(() => _profilePhoto = photo);
    } catch (error) {
      if (!mounted) return;
      await _showAuthPopup(
        context,
        title: 'Foto profil gagal diperbarui',
        message: 'Coba pilih foto lain. $error',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<Uint8List?> _pickProfilePhotoFromGallery() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    return image?.readAsBytes();
  }

  Future<void> _saveProfile() async {
    final name = _fields['nama']!.text.trim();
    if (name.isEmpty) {
      await _showAuthPopup(
        context,
        title: 'Nama wajib diisi',
        message: 'Masukkan nama lengkap sebelum menyimpan profil.',
        icon: Icons.person_outline_rounded,
      );
      return;
    }
    if (_fields['nik']!.text.trim().isNotEmpty &&
        !RegExp(r'^\d{16}$').hasMatch(_fields['nik']!.text.trim())) {
      await _showAuthPopup(
        context,
        title: 'NIK belum valid',
        message: 'NIK harus terdiri dari 16 digit angka.',
        icon: Icons.badge_outlined,
      );
      return;
    }
    final latitude = double.tryParse(_fields['latitude']!.text.trim());
    final longitude = double.tryParse(_fields['longitude']!.text.trim());
    if ((_fields['latitude']!.text.trim().isNotEmpty && latitude == null) ||
        (_fields['longitude']!.text.trim().isNotEmpty && longitude == null) ||
        (latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180))) {
      await _showAuthPopup(
        context,
        title: 'Koordinat belum valid',
        message: 'Periksa kembali nilai lintang dan bujur lokasi rumahmu.',
        icon: Icons.location_on_outlined,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.updateProfil(
        nama: name,
        alamat: _fields['alamatLengkap']!.text.trim(),
        email: _fields['email']!.text.trim(),
        nik: _fields['nik']!.text.trim(),
        jenisTempat: _jenisTempat,
        alamatLengkap: _fields['alamatLengkap']!.text.trim(),
        rt: _fields['rt']!.text.trim(),
        rw: _fields['rw']!.text.trim(),
        kelurahan: _fields['kelurahan']!.text.trim(),
        kecamatan: _fields['kecamatan']!.text.trim(),
        kota: _fields['kota']!.text.trim(),
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
    } catch (error) {
      if (!mounted) return;
      await _showAuthPopup(
        context,
        title: 'Profil belum tersimpan',
        message: error is ApiException ? error.message : '$error',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editLocation() async {
    final latitudeController = TextEditingController(
      text: _fields['latitude']!.text,
    );
    final longitudeController = TextEditingController(
      text: _fields['longitude']!.text,
    );
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ubah lokasi', style: display(size: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitude'),
            ),
            TextField(
              controller: longitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Longitude'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              latitudeController.text.trim(),
              longitudeController.text.trim(),
            )),
            child: const Text('Pakai Lokasi'),
          ),
        ],
      ),
    );
    latitudeController.dispose();
    longitudeController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _fields['latitude']!.text = result.$1;
      _fields['longitude']!.text = result.$2;
    });
  }

  Future<void> _addPaymentMethod() async {
    final ownerController = TextEditingController(
      text: _fields['nama']!.text.trim(),
    );
    final numberController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var method = 'GoPay';
    var submitting = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.dark, width: 1.5),
              boxShadow: const [
                BoxShadow(color: AppColors.dark, offset: Offset(0, 5)),
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Tambah Rekening Pencairan',
                          style: display(size: 18),
                        ),
                      ),
                      IconButton(
                        onPressed: submitting
                            ? null
                            : () => Navigator.pop(dialogContext, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(
                      labelText: 'Metode Pencairan',
                    ),
                    items:
                        const [
                          'GoPay',
                          'DANA',
                          'OVO',
                          'ShopeePay',
                          'BCA',
                          'BRI',
                          'BNI',
                          'Mandiri',
                        ].map((item) {
                          return DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                    onChanged: (value) =>
                        setDialogState(() => method = value ?? method),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: ownerController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pemilik',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nama pemilik wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: numberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Akun / Nomor Rekening',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nomor akun wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: submitting
                          ? null
                          : () async {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              setDialogState(() => submitting = true);
                              try {
                                await ApiService.tambahMetodePencairan(
                                  metode: method,
                                  namaPemilik: ownerController.text.trim(),
                                  nomorRekening: numberController.text.trim(),
                                );
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext, true);
                                }
                              } catch (error) {
                                if (!dialogContext.mounted) return;
                                setDialogState(() => submitting = false);
                                await _showAuthPopup(
                                  dialogContext,
                                  title: 'Rekening belum ditambahkan',
                                  message: error is ApiException
                                      ? error.message
                                      : '$error',
                                  icon: Icons.error_outline_rounded,
                                );
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Tambah'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    ownerController.dispose();
    numberController.dispose();
    if (result == true && mounted) {
      try {
        await _reloadMethods();
      } catch (error) {
        if (!mounted) return;
        await _showAuthPopup(
          context,
          title: 'Metode belum dimuat',
          message: error is ApiException ? error.message : '$error',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _reloadMethods() async {
    final response = await ApiService.getMetodePencairanSaya();
    final rows = response['data'];
    if (rows is! List<dynamic>) {
      throw const FormatException('Daftar rekening tidak valid.');
    }
    if (mounted) {
      setState(() {
        _paymentMethods = rows.whereType<Map<String, dynamic>>().toList();
      });
    }
  }

  Future<void> _makePrimary(Map<String, dynamic> method) async {
    final id = int.tryParse('${method['id']}');
    if (id == null) {
      await _showAuthPopup(
        context,
        title: 'Data rekening tidak valid',
        message: 'Tidak dapat mengubah rekening utama. Muat ulang halaman.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    try {
      await ApiService.jadikanMetodePencairanUtama(id);
      await _reloadMethods();
    } catch (error) {
      if (!mounted) return;
      await _showAuthPopup(
        context,
        title: 'Metode belum berubah',
        message: error is ApiException ? error.message : '$error',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.logout_rounded,
          color: AppColors.orange,
          size: 34,
        ),
        title: Text('Yakin mau keluar?', style: display(size: 21)),
        content: const Text(
          'Kamu akan keluar dari akun RESIK. Saldo dan riwayat setoran tetap aman, masuk lagi kapan saja.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Ya, Keluar'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.logoutNasabah();
      if (mounted) _goLogin(context);
    } catch (error) {
      if (!mounted) return;
      await _showAuthPopup(
        context,
        title: 'Sesi lokal dihapus',
        message: error is ApiException ? error.message : 'Akun telah dikeluarkan dari perangkat, tetapi server belum dapat mengakhiri sesi.',
        icon: Icons.info_outline_rounded,
        accent: AppColors.dark,
      );
      if (mounted) _goLogin(context);
    }
  }

  Widget _profileTopBar() => Row(
    children: [
      IconButton(
        tooltip: 'Kembali ke Beranda',
        onPressed: widget.onBack,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.dark,
          side: const BorderSide(color: AppColors.dark, width: 1.3),
          fixedSize: const Size(38, 38),
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text('Profil', style: display(size: 22))),
      IconButton(
        key: const Key('profile-chatbot-button'),
        tooltip: 'Buka Asisten DaurUang',
        onPressed: widget.onChat,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          fixedSize: const Size(38, 38),
        ),
        icon: const Icon(Icons.eco_rounded, size: 20),
      ),
    ],
  );

  Widget _profileHeaderCard(String initial) {
    final name = _fields['nama']!.text.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          InkWell(
            key: const Key('profile-photo-button'),
            onTap: _changeProfilePhoto,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 62,
              height: 62,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EDD9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.orange, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _profilePhoto == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 34,
                              color: AppColors.dark,
                            )
                          : Image.memory(
                              _profilePhoto!,
                              key: const Key('profile-photo-image'),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image_outlined,
                                size: 30,
                                color: AppColors.dark,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? initial : name,
                  key: const Key('profile-header-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(size: 16),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBEBC8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Member Gold',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A5A00),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
            color: AppColors.dark,
          ),
        ),
      ],
    ),
  );

  Widget _field(
    String key,
    String label, {
    bool readOnly = false,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              color: AppColors.muted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextField(
          controller: _fields[key],
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 11, color: AppColors.dark),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: readOnly ? const Color(0xFFF5F3ED) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: AppColors.orange),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _paymentCard(Map<String, dynamic> method) {
    final isPrimary = method['utama'] == 1 || method['utama'] == true;
    final number = '${method['nomor_rekening'] ?? ''}';
    final masked = number.length > 4
        ? '${'•' * (number.length - 4)}${number.substring(number.length - 4)}'
        : number;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Color(0x25000000), offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isPrimary ? 'METODE UTAMA' : 'METODE PENCAIRAN',
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.white70,
                    letterSpacing: .5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                isPrimary
                    ? Icons.check_circle_rounded
                    : Icons.account_balance_wallet_outlined,
                size: 15,
                color: AppColors.orange,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${method['metode'] ?? ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'NOMOR AKUN',
            style: TextStyle(fontSize: 7.5, color: Colors.white70),
          ),
          Text(
            masked,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NAMA PEMILIK',
                      style: TextStyle(fontSize: 7.5, color: Colors.white70),
                    ),
                    Text(
                      '${method['nama_pemilik'] ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (!isPrimary)
                TextButton(
                  onPressed: () => _makePrimary(method),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'JADIKAN UTAMA',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationMap() {
    final lat = _fields['latitude']!.text;
    final lon = _fields['longitude']!.text;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 132,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ProfileMapPainter(),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFD8D7A9), Color(0xFFB9C39A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.location_pin,
                color: AppColors.orange,
                size: 37,
                shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lat.isEmpty || lon.isEmpty
                            ? 'Koordinat lokasi belum diatur'
                            : 'Koordinat: $lat, $lon',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          color: AppColors.dark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: _editLocation,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Ubah Lokasi',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.orange),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadProfile,
                child: const Text('Coba lagi'),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PasswordResetScreen(),
                  ),
                ),
                child: const Text('Lupa Password?'),
              ),
            ],
          ),
        ),
      );
    }
    final initial = _fields['nama']!.text.trim().isEmpty
        ? 'R'
        : _fields['nama']!.text.trim()[0].toUpperCase();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _profileTopBar(),
            const SizedBox(height: 16),
            _profileHeaderCard(initial),
            const SizedBox(height: 18),
            _sectionLabel('DATA PRIBADI'),
            const SizedBox(height: 10),
            _field('nama', 'Nama Lengkap (Sesuai KTP)'),
            _field('telepon', 'Nomor HP / WhatsApp', readOnly: true),
            _field('nik', 'NIK (KTP)', keyboardType: TextInputType.number),
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 2, bottom: 4),
                    child: Text(
                      'TIPE PENGGUNA',
                      style: TextStyle(
                        fontSize: 8,
                        color: AppColors.muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _jenisTempat,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: _line),
                      ),
                    ),
                    items: const ['Rumah Tangga', 'Sekolah', 'Kantor', 'Usaha']
                        .map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        })
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _jenisTempat = value);
                    },
                  ),
                ],
              ),
            ),
            _sectionLabel('ALAMAT'),
            _field('alamatLengkap', 'Alamat Lengkap'),
            Row(
              children: [
                Expanded(child: _field('rt', 'RT')),
                const SizedBox(width: 8),
                Expanded(child: _field('rw', 'RW')),
              ],
            ),
            _field('kelurahan', 'Kelurahan / Desa'),
            _field('kecamatan', 'Kecamatan'),
            _field('kota', 'Kota / Kabupaten'),
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                'PINDAI LOKASI',
                style: const TextStyle(
                  fontSize: 8,
                  color: AppColors.muted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _locationMap(),
            const SizedBox(height: 16),
            _sectionLabel('REKENING PENCAIRAN'),
            if (_paymentMethods.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: const Text(
                  'Belum ada metode pencairan. Tambahkan rekening atau e-wallet.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              )
            else
              ..._paymentMethods.map(_paymentCard),
            OutlinedButton.icon(
              onPressed: _addPaymentMethod,
              icon: const Icon(Icons.add_circle, color: AppColors.orange),
              label: const Text('Tambah Metode Pencairan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dark,
                side: const BorderSide(color: _line),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving ? null : _saveProfile,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Perubahan'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, color: AppColors.orange),
              label: const Text('Keluar dari Akun'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orange,
                side: const BorderSide(color: _line),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PasswordResetScreen()),
              ),
              child: const Text('Lupa Password?'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFF3EED8)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final minorRoad = Paint()
      ..color = const Color(0xFFE8E2C7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final roads = [
      Path()
        ..moveTo(0, size.height * .78)
        ..cubicTo(
          size.width * .25,
          size.height * .55,
          size.width * .55,
          size.height * .8,
          size.width,
          size.height * .42,
        ),
      Path()
        ..moveTo(size.width * .12, 0)
        ..cubicTo(
          size.width * .35,
          size.height * .25,
          size.width * .55,
          size.height * .2,
          size.width * .76,
          size.height,
        ),
      Path()
        ..moveTo(size.width * .62, 0)
        ..lineTo(size.width * .48, size.height * .46)
        ..lineTo(size.width, size.height * .82),
      Path()
        ..moveTo(0, size.height * .32)
        ..lineTo(size.width * .4, size.height * .48)
        ..lineTo(size.width * .82, size.height * .08),
    ];
    for (final path in roads) {
      canvas.drawPath(path, roadPaint);
      canvas.drawPath(path, minorRoad);
    }
    final parkPaint = Paint()..color = const Color(0x503B7A2F);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .04,
          size.height * .05,
          size.width * .24,
          size.height * .19,
        ),
        const Radius.circular(9),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .73,
          size.height * .58,
          size.width * .22,
          size.height * .23,
        ),
        const Radius.circular(9),
      ),
      parkPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Halaman $title (belum dibuat)'),
        if (title == 'Profil')
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PasswordResetScreen()),
            ),
            child: const Text('Lupa Password?'),
          ),
      ],
    ),
  );
}

class RiwayatPage extends StatefulWidget {
  final VoidCallback? onBack;
  const RiwayatPage({super.key, this.onBack});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  late final Future<List<_RiwayatItem>> _history = _loadHistory();

  Future<List<_RiwayatItem>> _loadHistory() async {
    final responses = await Future.wait([
      ApiService.getSetoranSaya(),
      ApiService.getRiwayatTransaksi(),
    ]);
    final rows = <_RiwayatItem>[];
    final deposits = responses[0];
    final transactions = responses[1];
    for (final item
        in (deposits['data'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()) {
      final status = '${item['status']}'.toLowerCase();
      final berat = num.tryParse('${item['berat_kg']}') ?? 0;
      rows.add(
        _RiwayatItem(
          title: 'Setor ${item['jenis']}',
          date: DateTime.tryParse('${item['tanggal']}'),
          status: status == 'diterima'
              ? 'Selesai'
              : status == 'ditolak'
              ? 'Ditolak'
              : 'Diproses',
          amount: (num.tryParse('${item['total_saldo']}') ?? 0).round(),
          incoming: true,
          detail: '${berat.toStringAsFixed(berat % 1 == 0 ? 0 : 1)} KG',
          icon: _iconForWaste('${item['jenis']}'),
        ),
      );
    }
    for (final item
        in (transactions['data'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()) {
      final keluar = item['tipe'] == 'keluar';
      final date = DateTime.tryParse('${item['created_at']}');
      final status = '${item['status']}'.toLowerCase();
      rows.add(
        _RiwayatItem(
          title: keluar
              ? 'Tarik Saldo\n(${item['metode'] ?? 'Penarikan'})'
              : 'Saldo Setoran',
          date: date,
          status: status == 'berhasil' || status == 'berhasil diproses'
              ? 'Selesai'
              : 'Diproses',
          amount: (num.tryParse('${item['jumlah']}') ?? 0).round(),
          incoming: !keluar,
          detail: keluar
              ? 'TUJUAN ${item['nomor_tujuan'] ?? '-'}'
              : 'SALDO MASUK',
          icon: keluar
              ? Icons.payments_outlined
              : Icons.account_balance_wallet_outlined,
        ),
      );
    }
    rows.sort((a, b) {
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return rows;
  }

  IconData _iconForWaste(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('kertas') || normalized.contains('kardus')) {
      return Icons.inventory_2_outlined;
    }
    if (normalized.contains('minyak')) return Icons.eco_outlined;
    if (normalized.contains('plastik')) return Icons.local_drink_outlined;
    return Icons.recycling_rounded;
  }

  String _groupLabel(DateTime? date) {
    if (date == null) return 'TANGGAL TIDAK TERSEDIA';
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'HARI INI';
    if (day == today.subtract(const Duration(days: 1))) return 'KEMARIN';
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MEI',
      'JUN',
      'JUL',
      'AGU',
      'SEP',
      'OKT',
      'NOV',
      'DES',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _timeLabel(DateTime? date) {
    if (date == null) return '--:--';
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_RiwayatItem>>(
    future: _history,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat riwayat: ${snapshot.error}'),
          ),
        );
      }
      final rows = snapshot.data ?? [];
      final grouped = <String, List<_RiwayatItem>>{};
      for (final row in rows) {
        grouped.putIfAbsent(_groupLabel(row.date), () => []).add(row);
      }
      final summaryDate = DateTime.now();
      final thisMonth = rows
          .where(
            (row) =>
                row.date?.year == summaryDate.year &&
                row.date?.month == summaryDate.month &&
                row.incoming &&
                row.status == 'Selesai',
          )
          .toList();
      final totalKg = rows
          .where(
            (row) =>
                row.date?.year == summaryDate.year &&
                row.date?.month == summaryDate.month &&
                row.title.toLowerCase().startsWith('setor'),
          )
          .fold<double>(0, (sum, row) => sum + row.weightKg);
      final totalSaldo = thisMonth.fold<int>(0, (sum, row) => sum + row.amount);

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topBar(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    icon: Icons.recycling_rounded,
                    label: 'TERKUMPUL',
                    value: '${totalKg.toStringAsFixed(1)} Kg',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _summaryCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'SALDO MASUK',
                    value: _compactRupiah(totalSaldo),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _monthHeader(_monthLabel(summaryDate)),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('Belum ada aktivitas.')),
              )
            else
              for (final entry in grouped.entries) ...[
                _groupHeader(entry.key),
                const SizedBox(height: 12),
                for (final row in entry.value) _historyCard(row),
                const SizedBox(height: 6),
              ],
          ],
        ),
      );
    },
  );

  Widget _topBar() => Row(
    children: [
      GestureDetector(
        onTap: widget.onBack,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.dark, width: 1.5),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: AppColors.dark,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text('Riwayat', style: display(size: 22))),
      Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.dark,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.eco, size: 15, color: Colors.white),
      ),
    ],
  );

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) => Container(
    margin: const EdgeInsets.only(right: 4, bottom: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.dark, width: 1.5),
      boxShadow: const [BoxShadow(color: AppColors.dark, offset: Offset(4, 4))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFFADBD0),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(icon, size: 11, color: AppColors.orange),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 8,
                  letterSpacing: .5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(value, style: display(size: 22)),
      ],
    ),
  );

  Widget _monthHeader(String text) => Row(
    children: [
      Text(text, style: display(size: 14, weight: FontWeight.w700)),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: Color(0xFFE6DFCF), height: 1)),
      const SizedBox(width: 6),
      const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 18,
        color: AppColors.muted,
      ),
    ],
  );

  Widget _groupHeader(String text) => Row(
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 9.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: Color(0xFFE6DFCF), height: 1)),
    ],
  );

  Widget _historyCard(_RiwayatItem item) {
    final complete = item.status == 'Selesai';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6DFCF)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.incoming
                  ? const Color(0xFFFADBD0)
                  : const Color(0xFFE6E0CF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              size: 22,
              color: item.incoming ? AppColors.orange : AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    text: '${_timeLabel(item.date)} · ',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                    children: [
                      TextSpan(
                        text: item.status,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: complete ? AppColors.green : AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.incoming ? '+' : '-'}${rupiah(item.amount)}',
                style: display(size: 15, weight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                item.detail,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 8,
                  letterSpacing: .5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _compactRupiah(int amount) => amount >= 1000000
      ? 'Rp ${(amount / 1000000).toStringAsFixed(1)}jt'
      : 'Rp ${amount ~/ 1000}k';
}

class _RiwayatItem {
  final String title;
  final DateTime? date;
  final String status;
  final int amount;
  final bool incoming;
  final String detail;
  final IconData icon;

  const _RiwayatItem({
    required this.title,
    required this.date,
    required this.status,
    required this.amount,
    required this.incoming,
    required this.detail,
    required this.icon,
  });

  double get weightKg {
    final match = RegExp(r'[\d,.]+').firstMatch(detail);
    return double.tryParse(match?.group(0)?.replaceAll(',', '.') ?? '') ?? 0;
  }
}

class NotifikasiNasabahPage extends StatefulWidget {
  final VoidCallback onBack;
  const NotifikasiNasabahPage({super.key, required this.onBack});

  @override
  State<NotifikasiNasabahPage> createState() => _NotifikasiNasabahPageState();
}

class _NotifikasiNasabahPageState extends State<NotifikasiNasabahPage> {
  late Future<List<Map<String, dynamic>>> _notifications = _loadNotifications();
  String? _error;

  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    final response = await ApiService.getNotifikasi();
    return (response['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  bool _isRead(Map<String, dynamic> notification) {
    final value = notification['sudah_dibaca'];
    return value == true || value == 1 || value == '1';
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    if (_isRead(notification)) return;
    try {
      await ApiService.tandaiNotifikasiBaca(int.parse('${notification['id']}'));
      if (!mounted) return;
      setState(() {
        notification['sudah_dibaca'] = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memperbarui notifikasi: $error');
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'sukses':
        return Icons.check_circle_outline_rounded;
      case 'peringatan':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _notifications,
    builder: (context, snapshot) {
      final items = snapshot.data ?? [];
      final unread = items.where((item) => !_isRead(item)).length;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.dark, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Notifikasi', style: display(size: 22))),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$unread baru',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (snapshot.hasError)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Gagal memuat notifikasi: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _notifications = _loadNotifications();
                          });
                        },
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (items.isEmpty)
            const Expanded(child: Center(child: Text('Belum ada notifikasi.')))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: _isRead(item)
                            ? Colors.white.withValues(alpha: .75)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _markRead(item),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isRead(item)
                                    ? const Color(0xFFE6DFCF)
                                    : AppColors.green,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFADBD0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _iconFor('${item['tipe']}'),
                                    color: AppColors.orange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item['judul'] ?? 'Notifikasi'}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.dark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item['pesan'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        DateTime.tryParse(
                                                  '${item['created_at']}',
                                                )
                                                ?.toLocal()
                                                .toString()
                                                .substring(0, 16) ??
                                            '',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isRead(item))
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8, top: 4),
                                    child: CircleAvatar(
                                      radius: 4,
                                      backgroundColor: AppColors.orange,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------
// LAYAR: SETOR SAMPAH
// ---------------------------------------------------------------

/// Data satu jenis sampah.
class _Jenis {
  final int id;
  final String nama;
  final IconData icon;
  final int hargaPerKg;
  const _Jenis(this.id, this.nama, this.icon, this.hargaPerKg);
}

class SetorPage extends StatefulWidget {
  final VoidCallback? onBack;
  const SetorPage({super.key, this.onBack});

  @override
  State<SetorPage> createState() => _SetorPageState();
}

class _SetorPageState extends State<SetorPage> {
  final List<int> selected = [];
  final List<TextEditingController> controllers = [];
  List<_Jenis> jenis = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadJenis();
  }

  Future<void> _loadJenis() async {
    try {
      final response = await ApiService.getJenisSampah();
      final data = response['data'] as List<dynamic>;
      final loaded = data
          .where(
            (item) =>
                item is Map<String, dynamic> &&
                (item['aktif'] == 1 || item['aktif'] == true),
          )
          .map((item) {
            final row = item as Map<String, dynamic>;
            final name = (row['nama'] as String).toUpperCase();
            final icon = name.contains('MINYAK')
                ? Icons.opacity_outlined
                : name.contains('KARDUS') || name.contains('KERTAS')
                ? Icons.inventory_2_outlined
                : name.contains('PLASTIK')
                ? Icons.local_drink_outlined
                : Icons.recycling_rounded;
            return _Jenis(
              int.parse('${row['id']}'),
              name,
              icon,
              (num.tryParse('${row['harga_per_kg']}') ?? 0).round(),
            );
          })
          .toList();
      if (!mounted) return;
      for (final controller in controllers) {
        controller.dispose();
      }
      setState(() {
        jenis = loaded;
        controllers.addAll(
          List.generate(
            loaded.length,
            (_) => TextEditingController(text: '2.5'),
          ),
        );
        if (loaded.isNotEmpty) selected.add(0);
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat jenis sampah: $error')),
      );
    }
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- logika ----------
  double _kg(int i) =>
      double.tryParse(controllers[i].text.replaceAll(',', '.')) ?? 0;

  int _harga(int i) => (_kg(i) * jenis[i].hargaPerKg).round();

  double get totalKg => selected.fold(0.0, (s, i) => s + _kg(i));
  int get totalSaldo => selected.fold(0, (s, i) => s + _harga(i));

  String _fmtKg(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  void _toggle(int i) {
    setState(() {
      if (selected.contains(i)) {
        if (selected.length > 1) selected.remove(i); // minimal 1 jenis
      } else {
        selected.add(i);
      }
    });
  }

  void _tambahJenis() {
    final sisa = List.generate(
      jenis.length,
      (i) => i,
    ).where((i) => !selected.contains(i));
    if (sisa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua jenis sampah sudah ditambahkan')),
      );
      return;
    }
    setState(() => selected.add(sisa.first));
  }

  Future<void> _konfirmasi() async {
    if (loading || jenis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jenis sampah belum tersedia')),
      );
      return;
    }
    if (totalKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi estimasi berat terlebih dahulu')),
      );
      return;
    }
    try {
      for (final i in selected) {
        await ApiService.kirimSetoran(jenisId: jenis[i].id, beratKg: _kg(i));
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Setoran gagal dikirim: $error')));
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.dark, width: 2.5),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 34,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'SETORAN BERHASIL',
                style: display(size: 16, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // tutup popup
  }

  // ---------- tampilan ----------
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (jenis.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Data jenis sampah belum tersedia.'),
            TextButton(onPressed: _loadJenis, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(),
          const SizedBox(height: 14),
          _stepper(),
          const SizedBox(height: 18),
          Text(
            'Pilih Kategori Sampah',
            style: display(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _kategoriRow(),
          const SizedBox(height: 16),
          for (final i in selected) _beratCard(i),
          const SizedBox(height: 4),
          _ringkasan(),
          const SizedBox(height: 18),
          _konfirmasiButton(),
          const SizedBox(height: 18),
          _caraSetor(),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onBack,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.dark, width: 1.5),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AppColors.dark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text('Setor Sampah', style: display(size: 22))),
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.dark,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.eco, size: 15, color: Colors.white),
        ),
      ],
    );
  }

  Widget _stepper() {
    Widget step(String no, String label, bool active) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.dark : _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.dark : Colors.transparent,
              border: active ? null : Border.all(color: AppColors.muted),
            ),
            child: Text(
              no,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.dark : AppColors.muted,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          step('1', 'Pilih Kategori', true),
          const Expanded(child: Divider(color: _line, indent: 6, endIndent: 6)),
          step('2', 'Konfirmasi', false),
        ],
      ),
    );
  }

  Widget _kategoriRow() {
    return Row(
      children: [
        for (int i = 0; i < jenis.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == jenis.length - 1 ? 0 : 10),
              child: _kategoriTile(i),
            ),
          ),
      ],
    );
  }

  Widget _kategoriTile(int i) {
    final j = jenis[i];
    final on = selected.contains(i);
    return GestureDetector(
      onTap: () => _toggle(i),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? AppColors.orange : _line,
            width: on ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              j.icon,
              size: 24,
              color: on ? AppColors.orange : AppColors.muted,
            ),
            const SizedBox(height: 6),
            Text(
              j.nama,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
                color: on ? AppColors.orange : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _beratCard(int i) {
    final j = jenis[i];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16, right: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dark, width: 1.5),
        boxShadow: const [
          BoxShadow(color: AppColors.dark, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTIMASI BERAT (KG)',
            style: TextStyle(
              fontSize: 8.5,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEDEAE0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.dark, width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controllers[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: display(size: 22),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Text(
                  'KG',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTIMASI PENDAPATAN',
                      style: TextStyle(
                        fontSize: 8.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(rupiah(_harga(i)), style: display(size: 20)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEAE0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'RP ${rupiah(j.hargaPerKg).substring(3)} / KG',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _tambahJenis,
            child: CustomPaint(
              foregroundPainter: const _DashedBorderPainter(
                color: AppColors.dark,
                radius: 10,
              ),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_rounded,
                      size: 15,
                      color: AppColors.dark,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tambah Jenis Sampah',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ringkasan() {
    return Column(
      children: [
        Row(
          children: [
            Text('Ringkasan Setoran', style: display(size: 15)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${selected.length} JENIS',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Berat',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            Text(
              '${_fmtKg(totalKg)} Kg',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, color: _line),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Saldo Diterima',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
            Text(
              rupiah(totalSaldo),
              style: display(size: 18, color: AppColors.orange),
            ),
          ],
        ),
      ],
    );
  }

  Widget _konfirmasiButton() {
    return GestureDetector(
      onTap: _konfirmasi,
      child: Container(
        height: 50,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black26, offset: Offset(0, 3)),
          ],
        ),
        child: const Text(
          'Konfirmasi Setoran',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _caraSetor() {
    Widget item(String no, String judul, String isi) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              no,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isi,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 15, color: AppColors.dark),
              const SizedBox(width: 6),
              Text('Cara Setor Sampah', style: display(size: 13)),
            ],
          ),
          const SizedBox(height: 12),
          item(
            '1',
            'Pilih & Kategorikan',
            'Pisahkan sampah sesuai terlebih dahulu hingga bersih.',
          ),
          item(
            '2',
            'Bawa ke Drop Point',
            'Sari titik penjemputan atau datang langsung ke titik terdekat.',
          ),
          item(
            '3',
            'Timbang & Cairkan',
            'Petugas akan menimbang sampahmu dan saldo akan langsung masuk.',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// WIDGET UMUM
// ---------------------------------------------------------------
class AppCard extends StatelessWidget {
  final Widget child;
  final Color color;
  const AppCard({super.key, required this.child, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6DFCF)),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    ),
  );
}

class Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool light;
  const Stat({
    super.key,
    required this.label,
    required this.value,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: light ? Colors.white70 : AppColors.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: light ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class ActivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  const ActivityTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.bg,
            child: Icon(icon, size: 18, color: AppColors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// LAYAR: BERANDA (RESIK)
// ---------------------------------------------------------------
class CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final bool light;
  const CardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white70 : AppColors.muted;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: light ? Colors.white12 : AppColors.bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class DashedLine extends StatelessWidget {
  final Color color;
  const DashedLine({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final n = (box.maxWidth / 8).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            n,
            (_) => Container(width: 4, height: 1.5, color: color),
          ),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback? onNotifications;
  final VoidCallback? onChat;
  final VoidCallback? onProfile;

  const HomePage({
    super.key,
    this.onNotifications,
    this.onChat,
    this.onProfile,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _name = '';
  int? _balance;
  double? _totalKg;
  int? _transactionCount;
  double _monthKg = 0;
  int _monthCredit = 0;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _monthlyDeposits = [];
  List<Map<String, dynamic>> _recentDeposits = [];
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _prices = [];
  List<Map<String, dynamic>> _dropPoints = [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    try {
      final response = await ApiService.getDashboardSaya();
      final dashboard = response['data'];
      if (dashboard is! Map<String, dynamic>) {
        throw ApiException('Data dashboard tidak valid', 500);
      }
      final profile = dashboard['profile'];
      final summary = dashboard['summary'];
      if (profile is! Map<String, dynamic> ||
          summary is! Map<String, dynamic>) {
        throw ApiException('Ringkasan dashboard tidak lengkap', 500);
      }
      final now = DateTime.now();
      final monthlyDeposits = _rows(dashboard['monthly_deposits']);
      final currentMonth = monthlyDeposits.where(
        (item) =>
            _integer(item['tahun']) == now.year &&
            _integer(item['bulan']) == now.month,
      );
      final currentMonthKg = currentMonth.fold<double>(
        0,
        (total, item) => total + _decimal(item['total_kg']),
      );
      final recentDeposits = _rows(dashboard['recent_deposits']);
      final recentTransactions = _rows(dashboard['recent_transactions']);
      if (!mounted) return;
      setState(() {
        _name = (profile['nama'] as String?) ?? '';
        _balance = (num.tryParse('${profile['saldo']}') ?? 0).round();
        _totalKg = num.tryParse('${profile['total_setoran']}')?.toDouble() ?? 0;
        _transactionCount = _integer(summary['jumlah_transaksi']);
        _monthKg = currentMonthKg;
        _monthCredit = _integer(summary['saldo_masuk_bulan_ini']);
        _unreadNotifications = _integer(summary['notifikasi_belum_dibaca']);
        _monthlyDeposits = monthlyDeposits;
        _recentDeposits = recentDeposits;
        _recentTransactions = recentTransactions;
        _prices = _rows(dashboard['prices']);
        _dropPoints = _rows(dashboard['drop_points']);
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  int _integer(dynamic value) => num.tryParse('$value')?.round() ?? 0;

  double _decimal(dynamic value) => num.tryParse('$value')?.toDouble() ?? 0;

  String _formatToday() {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  DateTime? _parseDate(dynamic value) => DateTime.tryParse('$value');

  String _formatDateTime(dynamic value) {
    final date = _parseDate(value)?.toLocal();
    if (date == null) return 'Waktu tidak tersedia';
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final dayLabel = day == today
        ? 'Hari ini'
        : day == today.subtract(const Duration(days: 1))
        ? 'Kemarin'
        : '${date.day}/${date.month}/${date.year}';
    return '$dayLabel · ${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return '--:--';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 18),
          Text(
            'Halo, ${_name.isEmpty ? 'Nasabah' : _name}',
            style: display(size: 26),
          ),
          Text(
            _formatToday(),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gagal memuat data dashboard: $_loadError',
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadOverview,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          _saldoCard(),
          _targetCard(),
          _chartCard(),
          _priceCard(),
          _transaksiCard(),
          _mapCard(),
        ],
      ),
    );
  }

  // ---------- Header ----------
  Widget _header() {
    return Row(
      children: [
        // Logo RESIK (assets/images/Overlay.png)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/Overlay.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Text('RESIK', style: display(size: 20)),
        const Spacer(),
        IconButton(
          tooltip: 'Notifikasi',
          onPressed: widget.onNotifications,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.orange,
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: CircleAvatar(
                    radius: 7,
                    backgroundColor: AppColors.orange,
                    child: Text(
                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          key: const Key('dashboard-chatbot-button'),
          onTap: widget.onChat,
          customBorder: const CircleBorder(),
          child: const CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.green,
            child: Icon(Icons.eco, size: 15, color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          key: const Key('dashboard-profile-button'),
          onTap: widget.onProfile,
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.dark,
            child: Text(
              _name.isEmpty ? 'N' : _name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Saldo tabungan ----------
  Widget _saldoCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            icon: Icons.account_balance_wallet_outlined,
            title: 'SALDO TABUNGAN',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE3EDD9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Saldo RESIK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Rp', style: display(size: 16, weight: FontWeight.w400)),
              const SizedBox(width: 6),
              Text(
                _balance == null ? '—' : rupiah(_balance!).substring(3),
                style: display(size: 44),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Stat(
                  label: 'SETORAN',
                  value: _totalKg == null
                      ? '—'
                      : '${_totalKg!.toStringAsFixed(1)} kg',
                ),
              ),
              Expanded(
                child: Stat(
                  label: 'SALDO MASUK BULAN INI',
                  value: rupiah(_monthCredit),
                ),
              ),
              Expanded(
                child: Stat(
                  label: 'TRANSAKSI',
                  value: _transactionCount?.toString() ?? '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Target September (kartu hijau tua) ----------
  Widget _targetCard() {
    const targetKg = 20.0;
    final progress = (_monthKg / targetKg).clamp(0.0, 1.0);
    final remaining = (targetKg - _monthKg).clamp(0.0, targetKg);
    return AppCard(
      color: AppColors.dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(
            icon: Icons.track_changes,
            title: 'TARGET BULAN INI',
            light: true,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        color: AppColors.orange,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'tercapai',
                          style: TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_monthKg.toStringAsFixed(1)} / ${targetKg.toStringAsFixed(0)} kg',
                      style: display(size: 24, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remaining == 0
                          ? 'Target bulanan tercapai. Terima kasih sudah memilah sampah!'
                          : 'Kurang ${remaining.toStringAsFixed(1)} kg untuk mencapai target bulan ini.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 26, color: Colors.white24),
          Row(
            children: [
              Expanded(
                child: Stat(
                  label: 'SETORAN BULAN INI',
                  value: '${_monthKg.toStringAsFixed(1)} kg',
                  light: true,
                ),
              ),
              Expanded(
                child: Stat(
                  label: 'SALDO MASUK BULAN INI',
                  value: rupiah(_monthCredit),
                  light: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Grafik setoran 6 bulan ----------
  Widget _chartCard() {
    final now = DateTime.now();
    final monthRows = <Map<String, dynamic>>[];
    for (var offset = 5; offset >= 0; offset--) {
      final month = DateTime(now.year, now.month - offset);
      final result = _monthlyDeposits.where(
        (item) =>
            _integer(item['tahun']) == month.year &&
            _integer(item['bulan']) == month.month,
      );
      monthRows.add({
        'label': _shortMonth(month.month),
        'kg': result.fold<double>(
          0,
          (total, item) => total + _decimal(item['total_kg']),
        ),
        'current': month.year == now.year && month.month == now.month,
      });
    }
    final maxKg = monthRows.fold<double>(20, (maximum, item) {
      final kg = item['kg'] as double;
      return kg > maximum ? kg : maximum;
    });
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            icon: Icons.bar_chart_rounded,
            title: 'SETORAN 6 BULAN',
            trailing: const Text(
              'kg / bulan',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                Positioned(
                  top: 120 - 92 * (20 / maxKg),
                  left: 0,
                  right: 0,
                  child: const DashedLine(color: AppColors.orange),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: monthRows
                      .map(
                        (item) => _Bar(
                          label: item['label'] as String,
                          kg: item['kg'] as double,
                          maxKg: maxKg,
                          highlight: item['current'] as bool,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Harga hari ini ----------
  String _shortMonth(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ][month - 1];

  Widget _priceCard() {
    const iconBackgrounds = [
      Color(0xFFE3EDD9),
      Color(0xFFFBEBC8),
      Color(0xFFFADBD0),
    ];
    final now = DateTime.now();
    return AppCard(
      child: Column(
        children: [
          CardHeader(
            icon: Icons.sell_outlined,
            title: 'HARGA HARI INI',
            trailing: Text(
              '${now.day} ${_shortMonth(now.month)}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 8),
          if (_prices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada harga material aktif.'),
            )
          else
            for (var i = 0; i < _prices.length; i++)
              _PriceRow(
                icon: _priceIcon(_prices[i]['nama']?.toString() ?? ''),
                iconBg: iconBackgrounds[i % iconBackgrounds.length],
                name: _prices[i]['nama']?.toString() ?? 'Material',
                sub:
                    _prices[i]['keterangan']?.toString() ??
                    'Harga berlaku per ${_prices[i]['satuan'] ?? 'kg'}',
                price:
                    '${rupiah(_integer(_prices[i]['harga_per_kg']))}/${_prices[i]['satuan'] ?? 'kg'}',
              ),
        ],
      ),
    );
  }

  IconData _priceIcon(String name) {
    final value = name.toLowerCase();
    if (value.contains('organik') || value.contains('minyak')) {
      return Icons.eco_outlined;
    }
    if (value.contains('plastik')) return Icons.local_drink_outlined;
    if (value.contains('kertas') || value.contains('kardus')) {
      return Icons.inventory_2_outlined;
    }
    return Icons.recycling_rounded;
  }

  // ---------- Aktivitas terbaru ----------
  Widget _transaksiCard() {
    final activities = <Map<String, dynamic>>[
      ..._recentDeposits.map(
        (item) => {'kind': 'setoran', 'item': item, 'at': item['tanggal']},
      ),
      ..._recentTransactions.map(
        (item) => {'kind': 'transaksi', 'item': item, 'at': item['created_at']},
      ),
    ];
    activities.sort((left, right) {
      final leftDate = _parseDate(left['at']) ?? DateTime(0);
      final rightDate = _parseDate(right['at']) ?? DateTime(0);
      return rightDate.compareTo(leftDate);
    });

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            icon: Icons.receipt_long_outlined,
            title: 'AKTIVITAS TERAKHIR',
            trailing: const Text(
              'Terbaru',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.orange,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada aktivitas.'),
            )
          else
            for (final activity in activities.take(3)) _activityTile(activity),
        ],
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> activity) {
    final item = activity['item'] as Map<String, dynamic>;
    final isDeposit = activity['kind'] == 'setoran';
    final status = item['status']?.toString() ?? '';
    final approved = status == 'diterima' || status == 'berhasil';
    final amount = _integer(isDeposit ? item['total_saldo'] : item['jumlah']);
    final name = isDeposit
        ? item['jenis']?.toString() ?? 'Setoran'
        : item['keterangan']?.toString() ??
              (item['tipe'] == 'keluar'
                  ? 'Penarikan saldo'
                  : 'Transaksi saldo');
    final details = isDeposit
        ? '${_formatDateTime(activity['at'])} · ${_decimal(item['berat_kg']).toStringAsFixed(1)} kg · ${_statusLabel(status)}'
        : '${_formatDateTime(activity['at'])} · ${_statusLabel(status)}';
    final amountLabel = !approved
        ? _statusLabel(status)
        : '${item['tipe'] == 'keluar' ? '−' : '+'}${rupiah(amount)}';

    return ActivityTile(
      icon: isDeposit
          ? Icons.recycling_rounded
          : item['tipe'] == 'keluar'
          ? Icons.south_west_rounded
          : Icons.account_balance_wallet_outlined,
      title: name,
      subtitle: details,
      amount: amountLabel,
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'diterima':
      case 'berhasil':
        return 'Berhasil';
      case 'ditolak':
      case 'gagal':
        return 'Ditolak';
      case 'menunggu':
      case 'verifikasi':
      case 'pending':
        return 'Menunggu';
      default:
        return status.isEmpty ? 'Status tidak tersedia' : status;
    }
  }

  // ---------- Titik setor aktif ----------
  Widget _mapCard() {
    final point = _dropPoints.isEmpty ? null : _dropPoints.first;
    final latitude = point?['latitude']?.toString();
    final longitude = point?['longitude']?.toString();
    final hasCoordinates =
        latitude != null &&
        longitude != null &&
        num.tryParse(latitude) != null &&
        num.tryParse(longitude) != null;
    final isOpen = point?['status'] == 'buka';
    final openingHours = point == null
        ? ''
        : '${_formatTime(point['jam_buka'])}–${_formatTime(point['jam_tutup'])}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            icon: Icons.location_on_outlined,
            title: 'TITIK SETOR AKTIF',
            trailing: Text(
              '${_dropPoints.length} titik',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.orange,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 120,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFDCE6D0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _MapLinesPainter()),
                ),
                const Center(
                  child: Icon(
                    Icons.location_on,
                    color: AppColors.orange,
                    size: 38,
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      point == null
                          ? 'Belum ada titik setor terdaftar'
                          : hasCoordinates
                          ? 'Koordinat: $latitude, $longitude'
                          : 'Lokasi tersedia di data titik setor',
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (point == null)
            const Text('Data titik setor belum tersedia.')
          else ...[
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: isOpen ? AppColors.green : AppColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point['nama']?.toString() ?? 'Titik setor',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  isOpen ? 'Buka' : 'Tutup',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOpen ? AppColors.green : AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const SizedBox(width: 17),
                Expanded(
                  child: Text(
                    point['alamat']?.toString() ?? 'Alamat belum tersedia',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Text(
                  openingHours,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MapLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8C9A8)
      ..strokeWidth = 2;
    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 12), paint);
    }
    for (var i = 1; i <= 5; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x - 10, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Bar extends StatelessWidget {
  final String label;
  final double kg;
  final double maxKg;
  final bool highlight;
  const _Bar({
    required this.label,
    required this.kg,
    required this.maxKg,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${kg.toStringAsFixed(0)} kg',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: highlight ? AppColors.orange : AppColors.muted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 26,
          height: kg == 0 ? 4 : (kg / maxKg * 92).clamp(4, 92).toDouble(),
          decoration: BoxDecoration(
            color: highlight ? AppColors.orange : AppColors.green,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String name;
  final String sub;
  final String price;
  const _PriceRow({
    required this.icon,
    required this.iconBg,
    required this.name,
    required this.sub,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.dark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool isBot;
  final String text;
  final String time;

  const _ChatMessage(this.isBot, this.text, this.time);
}

String _chatTime() {
  final now = DateTime.now();
  final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  return '${hour.toString().padLeft(2, '0')}:$minute '
      '${now.hour < 12 ? 'AM' : 'PM'}';
}

List<_ChatMessage> _newChatHistory() => [
  _ChatMessage(
    true,
    'Halo! Saya Asisten DaurUang. Ada yang bisa saya bantu seputar sampah, '
    'harga, atau penarikan saldo?',
    _chatTime(),
  ),
];

final List<_ChatMessage> _chatHistory = _newChatHistory();

String _chatAnswer(String question) {
  final text = question.toLowerCase();
  bool includes(List<String> terms) => terms.any(text.contains);

  if (includes(['harga'])) {
    return 'Silakan cek harga terbaru pada bagian Harga Sampah di halaman '
        'Beranda karena nilainya dapat berubah setiap hari.';
  }
  if (includes(['pet', 'hdpe', 'bedakan', 'plastik'])) {
    return 'PET (kode 1) biasanya jernih dan digunakan untuk botol air mineral. '
        'HDPE (kode 2) lebih tebal dan sering digunakan untuk botol deterjen '
        'atau susu.';
  }
  if (includes(['tarik', 'tukar', 'saldo', 'cair'])) {
    return 'Saldo dapat ditarik lewat menu Tukar ke E-Wallet atau Transfer '
        'Bank. Minimal penarikan Rp50.000 dengan biaya layanan Rp1.000.';
  }
  if (includes(['jadwal', 'jemput', 'ambil'])) {
    return 'Kamu akan mendapat notifikasi saat armada penjemputan menuju '
        'lokasimu. Pastikan sampah sudah terpilah dan bersih.';
  }
  if (includes(['setor', 'cara'])) {
    return 'Pisahkan dan bersihkan sampah, lalu bawa ke drop point atau '
        'gunakan layanan penjemputan. Setelah ditimbang, saldo akan masuk '
        'ke akunmu.';
  }
  if (includes(['terima kasih', 'makasih', 'thanks'])) {
    return 'Sama-sama! Senang bisa membantu.';
  }
  if (includes(['halo', 'hai', 'hi ', 'pagi', 'siang', 'sore', 'malam'])) {
    return 'Halo! Ada yang bisa saya bantu seputar sampah, harga, atau '
        'penarikan saldo?';
  }
  return 'Maaf, saya belum paham pertanyaan itu. Coba tanyakan tentang harga '
      'sampah, cara setor, jadwal penjemputan, cara tarik saldo, atau jenis '
      'plastik.';
}

class ChatPage extends StatefulWidget {
  final VoidCallback? onBack;

  const ChatPage({super.key, this.onBack});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _typing = false;

  static const _suggestions = [
    'Harga sampah hari ini?',
    'Cara setor sampah?',
    'Jadwal penjemputan?',
    'Cara tarik saldo?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String value) async {
    final text = value.trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    setState(() {
      _chatHistory.add(_ChatMessage(false, text, _chatTime()));
      _typing = true;
    });
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 500));
    _chatHistory.add(_ChatMessage(true, _chatAnswer(text), _chatTime()));
    if (!mounted) return;
    setState(() => _typing = false);
    _scrollToBottom();
  }

  Future<void> _clearConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus percakapan?'),
        content: const Text('Semua pesan di chat ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _chatHistory
        ..clear()
        ..addAll(_newChatHistory());
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              IconButton(
                key: const Key('chatbot-back-button'),
                tooltip: 'Kembali',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.dark,
                child: Icon(Icons.eco, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asisten DaurUang',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                    Text(
                      'Online • Siap membantu',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opsi percakapan',
                onSelected: (value) {
                  if (value == 'clear') _clearConversation();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'clear',
                    child: Text('Hapus percakapan'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: const Key('chatbot-message-list'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6E0CF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'HARI INI',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final message in List<_ChatMessage>.of(_chatHistory))
                _messageBubble(message),
              if (_typing) _typingBubble(),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ActionChip(
              key: Key('chatbot-suggestion-$index'),
              label: Text(
                _suggestions[index],
                style: const TextStyle(fontSize: 10),
              ),
              onPressed: _typing ? null : () => _send(_suggestions[index]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.muted.withValues(alpha: .3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chatbot-message-input'),
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: const InputDecoration(
                      hintText: 'Tulis pesan...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('chatbot-send-button'),
                  tooltip: 'Kirim pesan',
                  onPressed: _typing ? null : () => _send(_input.text),
                  icon: const Icon(Icons.send_rounded, color: AppColors.green),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageBubble(_ChatMessage message) {
    final time = Text(
      message.time,
      style: const TextStyle(fontSize: 8, color: AppColors.muted),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: message.isBot
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.dark,
                  child: Icon(Icons.eco, size: 13, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.muted.withValues(alpha: .2),
                          ),
                        ),
                        child: Text(
                          message.text,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.dark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      time,
                    ],
                  ),
                ),
              ],
            )
          : Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * .72,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      message.text,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  time,
                ],
              ),
            ),
    );
  }

  Widget _typingBubble() => const Padding(
    padding: EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.dark,
          child: Icon(Icons.eco, size: 13, color: Colors.white),
        ),
        SizedBox(width: 8),
        Text(
          'Sedang mengetik...',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------
// LAYAR: TUKAR SALDO (E-Wallet & Transfer Bank)
// ---------------------------------------------------------------

/// Format angka jadi 150.000 saat mengetik.
class RibuanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final text = rupiah(int.parse(digits)).substring(3); // buang "Rp "
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Kotak dengan border putus-putus (kartu ringkasan & tombol tambah).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

class TukarSaldoPage extends StatefulWidget {
  final VoidCallback? onBack;
  const TukarSaldoPage({super.key, this.onBack});

  @override
  State<TukarSaldoPage> createState() => _TukarSaldoPageState();
}

class _TukarSaldoPageState extends State<TukarSaldoPage> {
  static const int minimal = 50000;
  static const int biayaLayanan = 1000;

  int saldo = 0;
  bool loading = true;
  bool submitting = false;
  final controller = TextEditingController(text: '150.000');
  final destinationController = TextEditingController();
  int amount = 150000;
  int method = 0; // 0 = E-Wallet, 1 = Transfer Bank
  int provider = 0; // index provider pada daftar metode yang aktif
  final quickAmounts = [50000, 100000, 150000, 200000];

  // daftar provider untuk tiap metode
  static const ewallets = ['Gopay', 'Dana', 'OVO', 'ShopeePay'];
  static const banks = ['Mandiri', 'BCA', 'BNI', 'BRI'];
  List<String> get providers => method == 0 ? ewallets : banks;

  // riwayat penarikan (terbaru di index 0)
  final List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final profile =
          (await ApiService.getProfilSaya())['data'] as Map<String, dynamic>;
      final response = await ApiService.getRiwayatTransaksi(tipe: 'keluar');
      final transactions = response['data'] as List<dynamic>;
      if (!mounted) return;
      setState(() {
        saldo = (num.tryParse('${profile['saldo']}') ?? 0).round();
        history
          ..clear()
          ..addAll(
            transactions.whereType<Map<String, dynamic>>().map(
              (item) => {
                'name':
                    '${item['metode'] ?? 'Penarikan'} - ${item['nomor_tujuan'] ?? ''}',
                'date':
                    DateTime.tryParse('${item['created_at']}')
                        ?.toLocal()
                        .toString()
                        .substring(0, 10) ??
                    '',
                'amount': (num.tryParse('${item['jumlah']}') ?? 0).round(),
              },
            ),
          );
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memuat saldo: $error')));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    destinationController.dispose();
    super.dispose();
  }

  void setAmount(int v) {
    setState(() {
      amount = v;
      controller.text = rupiah(v).substring(3);
    });
  }

  Future<void> _submit() async {
    if (amount < minimal) {
      await _showNoticeDialog(
        icon: Icons.info_outline_rounded,
        title: 'Nominal belum memenuhi minimum',
        message: 'Minimal penukaran saldo adalah ${rupiah(minimal)}.',
        actionLabel: 'Ubah nominal',
      );
      return;
    }

    if (destinationController.text.trim().isEmpty) {
      final enteredDestination = await _showDestinationDialog();
      if (enteredDestination != true || !mounted) return;
    }

    final totalDebit = amount + biayaLayanan;
    if (totalDebit > saldo) {
      await _showInsufficientBalanceDialog(totalDebit);
      return;
    }

    final confirmed = await _showExchangeConfirmation(totalDebit);
    if (confirmed != true || !mounted) return;

    await _performWithdrawal();
  }

  Future<bool?> _showDestinationDialog() {
    String? validationMessage;
    return showDialog<bool>(
      context: context,
      builder: (routeContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF8),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFE6DFCF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3317472A),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogIcon(Icons.account_balance_wallet_outlined),
                const SizedBox(height: 16),
                Text('Masukkan nomor tujuan', style: display(size: 21)),
                const SizedBox(height: 7),
                Text(
                  'Nomor tujuan ${providers[provider]} diperlukan untuk memproses penukaran saldo.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('exchange-destination-dialog-field'),
                  controller: destinationController,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) {
                    if (validationMessage != null) {
                      setDialogState(() => validationMessage = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: method == 0
                        ? 'Nomor e-wallet tujuan'
                        : 'Nomor rekening tujuan',
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    errorText: validationMessage,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.dark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          if (destinationController.text.trim().isEmpty) {
                            setDialogState(
                              () => validationMessage =
                                  'Nomor tujuan wajib diisi.',
                            );
                            return;
                          }
                          Navigator.pop(dialogContext, true);
                        },
                        child: const Text('Lanjutkan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showInsufficientBalanceDialog(int totalDebit) {
    final shortfall = totalDebit - saldo;
    return _showNoticeDialog(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Saldo tidak cukup',
      message:
          'Saldo tersedia ${rupiah(saldo)}. Total yang dibutuhkan ${rupiah(totalDebit)} termasuk biaya layanan ${rupiah(biayaLayanan)}. Tambahkan saldo atau kurangi nominal sebesar minimal ${rupiah(shortfall)}.',
      actionLabel: 'Ubah nominal',
      secondaryLabel: 'Mengerti',
    );
  }

  Future<void> _showNoticeDialog({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    String? secondaryLabel,
  }) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF8),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6DFCF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3317472A),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogIcon(icon),
            const SizedBox(height: 16),
            Text(title, style: display(size: 21)),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(actionLabel),
              ),
            ),
            if (secondaryLabel != null)
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(secondaryLabel),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<bool?> _showExchangeConfirmation(int totalDebit) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF8),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6DFCF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3317472A),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogIcon(Icons.payments_outlined),
            const SizedBox(height: 16),
            Text('Konfirmasi penukaran', style: display(size: 21)),
            const SizedBox(height: 6),
            const Text(
              'Pastikan detail tujuan dan nominal sudah benar.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            _confirmationRow('Metode', providers[provider]),
            _confirmationRow('Nomor tujuan', destinationController.text.trim()),
            _confirmationRow('Dana diterima', rupiah(amount)),
            _confirmationRow('Biaya layanan', rupiah(biayaLayanan)),
            const Divider(height: 20),
            _confirmationRow(
              'Total potong saldo',
              rupiah(totalDebit),
              emphasize: true,
            ),
            _confirmationRow('Sisa saldo', rupiah(saldo - totalDebit)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('confirm-exchange-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Tukar sekarang'),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Periksa kembali'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _dialogIcon(IconData icon) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: const Color(0xFFFADBD0),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Icon(icon, color: AppColors.orange, size: 27),
  );

  Widget _confirmationRow(
    String label,
    String value, {
    bool emphasize = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? AppColors.dark : AppColors.muted,
              fontSize: 12,
              fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: emphasize ? AppColors.orange : AppColors.dark,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _performWithdrawal() async {
    if (submitting) return;
    setState(() => submitting = true);
    Map<String, dynamic> withdrawal;
    try {
      final response = await ApiService.tarikSaldo(
        jumlah: amount,
        metode: providers[provider],
        nomorTujuan: destinationController.text.trim(),
      );
      withdrawal = response['data'] as Map<String, dynamic>;
    } catch (error) {
      if (!mounted) return;
      if (error.toString().toLowerCase().contains('saldo tidak cukup')) {
        await _showInsufficientBalanceDialog(amount + biayaLayanan);
      } else {
        await _showNoticeDialog(
          icon: Icons.error_outline_rounded,
          title: 'Penukaran belum berhasil',
          message: 'Permintaan gagal diproses: $error',
          actionLabel: 'Coba lagi',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => submitting = false);
    }
    if (!mounted) return;

    // popup "PENUKARAN BERHASIL"
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.dark, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.dark, width: 2.5),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 32,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'PENUKARAN BERHASIL',
                style: display(size: 14, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );

    // catat ke riwayat & kurangi saldo
    final now = DateTime.now();
    setState(() {
      saldo = (num.tryParse('${withdrawal['saldo_akhir']}') ?? saldo).round();
      history.insert(0, {
        'name': '${withdrawal['metode']} - ${withdrawal['nomor_tujuan']}',
        'date': '${now.day}/${now.month}/${now.year}',
        'amount': (num.tryParse('${withdrawal['jumlah']}') ?? amount).round(),
      });
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // tutup popup
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(),
          const SizedBox(height: 18),
          _saldoCard(),
          const SizedBox(height: 22),
          _label('METODE PENARIKAN'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _methodBox(0, Icons.smartphone_rounded, 'E-Wallet'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _methodBox(
                  1,
                  Icons.account_balance_rounded,
                  'Transfer Bank',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _providerRow(),
          const SizedBox(height: 12),
          _destinationField(),
          const SizedBox(height: 14),
          _nominalBox(),
          const SizedBox(height: 8),
          Text(
            '*Minimal Penarikan ${rupiah(minimal)}',
            style: TextStyle(
              fontSize: 11,
              color: amount < minimal ? AppColors.orange : AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          _quickChips(),
          const SizedBox(height: 18),
          _summaryCard(),
          const SizedBox(height: 22),
          _submitButton(),
          const SizedBox(height: 26),
          Row(
            children: [
              _label('TARIK TERAKHIR'),
              const Spacer(),
              const Text(
                'LIHAT SEMUA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _historyTile(),
        ],
      ),
    );
  }

  // ---------- bagian-bagian layar ----------
  Widget _topBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onBack,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.dark, width: 1.5),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AppColors.dark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('Tukar Saldo', style: display(size: 22)),
        const Spacer(),
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.dark,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.eco, size: 15, color: Colors.white),
        ),
      ],
    );
  }

  Widget _saldoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.orange, offset: Offset(5, 5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SALDO TERSEDIA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rupiah(saldo),
                  style: display(size: 32, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco, size: 11, color: Colors.white70),
                      SizedBox(width: 5),
                      Text(
                        'Eco-Warrior Level 2',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 40,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
    ),
  );

  Widget _providerRow() {
    final list = providers;
    return Row(
      children: [
        for (int i = 0; i < list.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == list.length - 1 ? 0 : 8),
              child: GestureDetector(
                onTap: () => setState(() => provider = i),
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: provider == i ? AppColors.dark : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.dark),
                  ),
                  child: Text(
                    list[i],
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: provider == i ? Colors.white : AppColors.dark,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _destinationField() => TextField(
    controller: destinationController,
    keyboardType: TextInputType.phone,
    decoration: InputDecoration(
      labelText: method == 0
          ? 'Nomor e-wallet tujuan'
          : 'Nomor rekening tujuan',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _methodBox(int i, IconData icon, String label) {
    final selected = method == i;
    return GestureDetector(
      onTap: () => setState(() {
        method = i;
        provider = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.orange : const Color(0xFFE6DFCF),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFADBD0)
                    : const Color(0xFFEDE9DF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 19,
                color: selected ? AppColors.orange : AppColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? AppColors.dark : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nominalBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.dark, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOMINAL PENARIKAN',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Rp',
                style: display(
                  size: 26,
                  weight: FontWeight.w700,
                  color: const Color(0xFF9AA598),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                    RibuanFormatter(),
                  ],
                  style: display(size: 30),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => setState(
                    () => amount = int.tryParse(v.replaceAll('.', '')) ?? 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickChips() {
    return Row(
      children: [
        for (int i = 0; i < quickAmounts.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i == quickAmounts.length - 1 ? 0 : 8,
              ),
              child: GestureDetector(
                onTap: () => setAmount(quickAmounts[i]),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: amount == quickAmounts[i]
                        ? AppColors.dark
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.dark),
                  ),
                  child: Text(
                    '${quickAmounts[i] ~/ 1000}k',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: amount == quickAmounts[i]
                          ? Colors.white
                          : AppColors.dark,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryCard() {
    return CustomPaint(
      foregroundPainter: const _DashedBorderPainter(
        color: Color(0xFFB9B3A2),
        radius: 16,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE8DA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _summaryRow('Biaya Layanan', rupiah(biayaLayanan)),
            _summaryRow('Estimasi Tiba', 'Instan ( < 10 Menit )'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, color: Color(0xFFD8D2C2)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Diterima',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                  Text(
                    rupiah(amount),
                    style: display(size: 18, color: AppColors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return GestureDetector(
      onTap: submitting ? null : _submit,
      child: Container(
        height: 58,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: AppColors.orange, offset: Offset(5, 5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              submitting
                  ? Icons.hourglass_top_rounded
                  : Icons.payments_outlined,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              submitting ? 'Memproses...' : 'Tukar Sekarang',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile() {
    if (history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6DFCF)),
        ),
        child: const Row(
          children: [
            Icon(Icons.credit_card_rounded, size: 20, color: AppColors.muted),
            SizedBox(width: 10),
            Text(
              'Belum ada riwayat penarikan',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      );
    }
    final last = history.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6DFCF)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE6E0CF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.credit_card_rounded,
              size: 17,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last['name'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  last['date'] as String,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            rupiah(last['amount'] as int),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ===============================================================
// AUTH: LOGIN, REGISTRASI STEP 1 & 2, SUKSES
// ===============================================================

const _line = Color(0xFFE6DFCF); // border krem, sama dengan AppCard
const _card = Color(0xFFFDFBF5);

void _goHome(BuildContext context) => Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => const MainShell()),
  (r) => false,
);

void _goLogin(BuildContext context) => Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => const LoginScreen()),
  (r) => false,
);

String _authErrorMessage(String action, Object error) {
  if (error is ApiException) return error.message;
  if (error is TimeoutException) {
    return 'Server tidak merespons. Periksa koneksi lalu coba lagi.';
  }
  return '$action gagal: $error';
}

String _normalizePhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('62')) return '0${digits.substring(2)}';
  if (digits.startsWith('8')) return '0$digits';
  return digits;
}

String _normalizeLoginIdentifier(String value) {
  final identifier = value.trim();
  if (identifier.contains('@')) return identifier.toLowerCase();
  if (RegExp(r'^[+0-9()\s.-]+$').hasMatch(identifier)) {
    return _normalizePhone(identifier);
  }
  return identifier;
}

// ---------------------------------------------------------------
// WIDGET BERSAMA
// ---------------------------------------------------------------
class AuthLogo extends StatelessWidget {
  final double size;
  const AuthLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .3),
    child: Image.asset(
      'assets/images/Overlay.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        color: AppColors.orange,
        child: Icon(Icons.eco_rounded, color: Colors.white, size: size * .5),
      ),
    ),
  );
}

class HardButton extends StatelessWidget {
  final String label;
  final IconData? trailing;
  final VoidCallback onTap;
  const HardButton({
    super.key,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => _Pressable(
    onTap: onTap,
    child: Container(
      height: 52,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: AppColors.dark, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Icon(trailing, color: Colors.white, size: 16),
          ],
        ],
      ),
    ),
  );
}

class GoogleButton extends StatelessWidget {
  final Color background;
  final VoidCallback onTap;
  const GoogleButton({
    super.key,
    required this.onTap,
    this.background = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) => _Pressable(
    onTap: onTap,
    child: Container(
      height: 48,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dark, width: 1.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'G',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4285F4),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Lanjut dengan Google',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .97 : 1,
    duration: const Duration(milliseconds: 110),
    curve: Curves.easeOut,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
        onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
        borderRadius: BorderRadius.circular(12),
        child: widget.child,
      ),
    ),
  );
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: Divider(color: _line)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'ATAU',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Expanded(child: Divider(color: _line)),
    ],
  );
}

class LabeledField extends StatelessWidget {
  final String label, hint;
  final bool obscure;
  final Widget? trailingLabel;
  final TextInputType? keyboard;
  final TextEditingController? controller;
  const LabeledField({
    super.key,
    required this.label,
    required this.hint,
    this.obscure = false,
    this.trailingLabel,
    this.keyboard,
    this.controller,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
            if (trailingLabel != null) trailingLabel!,
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppColors.muted.withValues(alpha: .6),
            ),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.dark, width: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}

class BottomLink extends StatelessWidget {
  final String text, action;
  final Color actionColor;
  final VoidCallback onTap;
  const BottomLink({
    super.key,
    required this.text,
    required this.action,
    required this.onTap,
    this.actionColor = AppColors.dark,
  });

  @override
  Widget build(BuildContext context) => _Pressable(
    onTap: onTap,
    child: Text.rich(
      TextSpan(
        text: '$text ',
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
        children: [
          TextSpan(
            text: action,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: actionColor,
            ),
          ),
        ],
      ),
    ),
  );
}

class AuthTopBar extends StatelessWidget {
  final int step; // 1 atau 2
  const AuthTopBar({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    Widget seg(Color c) => Expanded(
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
    final off = Colors.white.withValues(alpha: .8);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const AuthLogo(size: 36),
            const Text(
              'Daftar Akun',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            seg(step == 1 ? AppColors.orange : AppColors.dark),
            const SizedBox(width: 4),
            seg(step == 2 ? AppColors.orange : off),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DATA DIRI',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                letterSpacing: .5,
                color: step == 1 ? AppColors.orange : AppColors.muted,
              ),
            ),
            Text(
              'BUAT PASSWORD',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                letterSpacing: .5,
                color: step == 2 ? AppColors.orange : AppColors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// 1. LOGIN
// ---------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool remember = false, hide = true;
  bool _loading = false;
  bool _rememberPreferenceChanged = false;
  bool _loginEdited = false;
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreRememberedLogin();
  }

  Future<void> _restoreRememberedLogin() async {
    final values = await Future.wait<Object?>([
      ApiService.getRememberMePreference(),
      ApiService.getRememberedLogin(),
    ]);
    if (!mounted) return;
    final shouldRemember = values[0] as bool? ?? false;
    final rememberedLogin = values[1] as String?;
    setState(() {
      if (!_rememberPreferenceChanged) remember = shouldRemember;
      if (!_loginEdited &&
          shouldRemember &&
          rememberedLogin != null &&
          rememberedLogin.isNotEmpty) {
        _loginController.text = rememberedLogin;
      }
    });
  }

  Future<void> _setRememberMe(bool value) async {
    setState(() {
      _rememberPreferenceChanged = true;
      remember = value;
    });
    await ApiService.saveRememberMe(value);
    final identifier = _loginController.text.trim();
    if (value && identifier.isNotEmpty) {
      await ApiService.saveRememberedLogin(identifier);
    } else if (!value) {
      await ApiService.clearRememberedLogin();
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loginController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      await _showAuthPopup(
        context,
        title: 'Data belum lengkap',
        message: 'Masukkan nomor telepon atau email dan password untuk masuk.',
        icon: Icons.edit_note_rounded,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.login(
        teleponAtauEmail: _normalizeLoginIdentifier(_loginController.text),
        password: _passwordController.text,
        rememberMe: remember,
      );
      if (mounted) _goHome(context);
    } catch (error) {
      if (!mounted) return;
      await _showAuthPopup(
        context,
        title: 'Login belum berhasil',
        message: _authErrorMessage('Login', error),
        icon: Icons.lock_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12,
          color: AppColors.muted.withValues(alpha: .6),
        ),
        prefixIcon: Icon(icon, size: 16, color: AppColors.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const AuthLogo(),
              const SizedBox(height: 22),
              Text(
                'Selamat Datang',
                style: display(size: 28, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masuk untuk lanjut setor sampah dan\nkumpulkan saldomu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.dark, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: AppColors.dark, offset: Offset(0, 5)),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _loginController,
                      style: const TextStyle(fontSize: 13),
                      onChanged: (value) {
                        _loginEdited = true;
                        if (remember && value.trim().isNotEmpty) {
                          ApiService.saveRememberedLogin(value.trim());
                        }
                      },
                      decoration: _dec(
                        'WhatsApp atau Email',
                        Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: hide,
                      style: const TextStyle(fontSize: 13),
                      decoration: _dec(
                        'Password',
                        Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            hide
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.dark,
                          ),
                          onPressed: () => setState(() => hide = !hide),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: Checkbox(
                            value: remember,
                            side: const BorderSide(color: AppColors.dark),
                            onChanged: (value) =>
                                _setRememberMe(value ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Pressable(
                          onTap: _loading
                              ? null
                              : () => _setRememberMe(!remember),
                          child: const Text(
                            'Ingat saya',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _Pressable(
                          onTap: _loading
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PasswordResetScreen(),
                                  ),
                                ),
                          child: const Text(
                            'Lupa Password?',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    HardButton(
                      label: _loading ? 'Memproses...' : 'Masuk',
                      trailing: Icons.arrow_forward,
                      onTap: _loading ? () {} : _login,
                    ),
                    const SizedBox(height: 14),
                    const OrDivider(),
                    const SizedBox(height: 14),
                    GoogleButton(
                      onTap: () => _showAuthPopup(
                        context,
                        title: 'Segera hadir',
                        message: 'Login dengan Google belum tersedia. Silakan masuk menggunakan nomor telepon atau email.',
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              BottomLink(
                text: 'Belum punya akun?',
                action: 'Daftar',
                actionColor: AppColors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterStep1()),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '© 2026 RESIK ECOSYSTEM',
                style: TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('Masukkan alamat email yang valid.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ApiService.requestPasswordReset(email: email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _showMessage(
        result['message']?.toString() ??
            'Jika email terdaftar, kode verifikasi akan dikirim.',
      );
    } catch (error) {
      if (mounted) _showMessage(_authErrorMessage('Permintaan kode', error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showMessage('Masukkan kode verifikasi 6 digit.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Password baru minimal 8 karakter.');
      return;
    }
    if (password != _confirmPasswordController.text) {
      _showMessage('Konfirmasi password tidak sama.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ApiService.completePasswordReset(
        email: _emailController.text,
        otp: otp,
        password: password,
      );
      if (!mounted) return;
      final message =
          result['message']?.toString() ??
          'Password berhasil diubah. Silakan masuk kembali.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (mounted) _showMessage(_authErrorMessage('Reset password', error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Kembali',
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: AppColors.dark),
                  ),
                  const Spacer(),
                  const AuthLogo(size: 36),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _codeSent ? 'Verifikasi Email' : 'Lupa Password?',
                style: display(size: 26, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Masukkan kode yang dikirim ke email, lalu buat password baru.'
                    : 'Masukkan email yang terhubung dengan akun RESIK untuk menerima kode verifikasi.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.dark, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: AppColors.dark, offset: Offset(0, 5)),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      enabled: !_codeSent && !_loading,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'nama@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _otpController,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Kode verifikasi',
                          hintText: '6 digit',
                          prefixIcon: Icon(Icons.password_outlined),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        enabled: !_loading,
                        obscureText: _hidePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Password baru',
                          hintText: 'Minimal 8 karakter',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Tampilkan password'
                                : 'Sembunyikan password',
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmPasswordController,
                        enabled: !_loading,
                        obscureText: _hidePassword,
                        decoration: const InputDecoration(
                          labelText: 'Konfirmasi password baru',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    HardButton(
                      label: _loading
                          ? 'Memproses...'
                          : _codeSent
                          ? 'Ubah Password'
                          : 'Kirim Kode',
                      onTap: _loading
                          ? () {}
                          : _codeSent
                          ? _resetPassword
                          : _requestCode,
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                _codeSent = false;
                                _otpController.clear();
                                _passwordController.clear();
                                _confirmPasswordController.clear();
                              }),
                        child: const Text('Ganti email'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------
// 2. REGISTRASI STEP 1 - DATA DIRI
// ---------------------------------------------------------------
class RegisterStep1 extends StatefulWidget {
  const RegisterStep1({super.key});

  @override
  State<RegisterStep1> createState() => _RegisterStep1State();
}

class _RegisterStep1State extends State<RegisterStep1> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            const AuthTopBar(step: 1),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.recycling_rounded,
                        color: AppColors.green,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Yuk, mulai setor\nsampah!',
                      textAlign: TextAlign.center,
                      style: display(size: 22),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Daftar dulu untuk mulai kumpulkan saldo\ndari sampahmu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LabeledField(
                    label: 'Nama Lengkap',
                    hint: 'Contoh: Andi Wijaya',
                    controller: _nameController,
                  ),
                  LabeledField(
                    label: 'Nomor WhatsApp',
                    hint: '0812xxxx',
                    keyboard: TextInputType.phone,
                    controller: _phoneController,
                  ),
                  LabeledField(
                    label: 'Email',
                    hint: 'nama@email.com',
                    keyboard: TextInputType.emailAddress,
                    controller: _emailController,
                  ),
                  LabeledField(
                    label: 'Alamat / Kelurahan',
                    hint: 'Cari kelurahan Anda',
                    controller: _addressController,
                    trailingLabel: Text(
                      'Pakai lokasi saya',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            HardButton(
              label: 'Lanjut',
              onTap: () {
                final nama = _nameController.text.trim();
                final telepon = _normalizePhone(_phoneController.text);
                final email = _emailController.text.trim();
                if (nama.isEmpty) {
                  _showAuthPopup(
                    context,
                    title: 'Nama belum diisi',
                    message:
                        'Masukkan nama lengkap agar kami dapat mengenalimu.',
                    icon: Icons.person_outline_rounded,
                  );
                  return;
                }
                if (telepon.length < 8 || telepon.length > 15) {
                  _showAuthPopup(
                    context,
                    title: 'Nomor belum valid',
                    message:
                        'Masukkan nomor WhatsApp yang terdiri dari 8–15 digit.',
                    icon: Icons.phone_rounded,
                  );
                  return;
                }
                if (email.isNotEmpty &&
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  _showAuthPopup(
                    context,
                    title: 'Email belum valid',
                    message: 'Periksa kembali format alamat email yang kamu masukkan.',
                    icon: Icons.alternate_email_rounded,
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterStep2(
                      nama: nama,
                      telepon: telepon,
                      email: email,
                      alamat: _addressController.text.trim(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            const OrDivider(),
            const SizedBox(height: 14),
            GoogleButton(
              background: _card,
              onTap: () => _showAuthPopup(
                context,
                title: 'Segera hadir',
                message: 'Pendaftaran dengan Google belum tersedia. Kamu dapat melanjutkan dengan mengisi data diri.',
                icon: Icons.auto_awesome_rounded,
              ),
            ),
            const SizedBox(height: 16),
            BottomLink(
              text: 'Sudah punya akun?',
              action: 'Masuk',
              onTap: () => _goLogin(context),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------
// 3. REGISTRASI STEP 2 - BUAT PASSWORD
// ---------------------------------------------------------------
class RegisterStep2 extends StatefulWidget {
  final String nama;
  final String telepon;
  final String email;
  final String alamat;
  const RegisterStep2({
    super.key,
    required this.nama,
    required this.telepon,
    required this.email,
    required this.alamat,
  });

  @override
  State<RegisterStep2> createState() => _RegisterStep2State();
}

class _RegisterStep2State extends State<RegisterStep2> {
  bool agree = false;
  bool loading = false;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  TextSpan _link(String t) => TextSpan(
    text: t,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      color: AppColors.dark,
      decoration: TextDecoration.underline,
    ),
  );

  Future<void> _submit() async {
    if (!agree) {
      await _showAuthPopup(
        context,
        title: 'Persetujuan diperlukan',
        message:
            'Setujui Syarat & Ketentuan dan Kebijakan Privasi terlebih dahulu.',
        icon: Icons.fact_check_outlined,
      );
      return;
    }
    if (_passwordController.text.length < 6 ||
        _passwordController.text != _confirmPasswordController.text) {
      await _showAuthPopup(
        context,
        title: 'Password perlu diperiksa',
        message: 'Gunakan password minimal 6 karakter dan pastikan konfirmasinya sama.',
        icon: Icons.password_rounded,
      );
      return;
    }
    setState(() => loading = true);
    try {
      await ApiService.register(
        nama: widget.nama,
        telepon: widget.telepon,
        password: _passwordController.text,
        email: widget.email.isEmpty ? null : widget.email,
        alamat: widget.alamat.isEmpty ? null : widget.alamat,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SuccessScreen(name: widget.nama)),
      );
    } catch (error) {
      if (!mounted) return;
      await _showAuthPopup(
        context,
        title: 'Pendaftaran belum berhasil',
        message: _authErrorMessage('Registrasi', error),
        icon: Icons.person_add_alt_1_rounded,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            const AuthTopBar(step: 2),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 22),
                  Center(
                    child: Text('Satu langkah lagi!', style: display(size: 22)),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Buat password yang kuat untuk\nkeamanan akunmu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 24),
                  LabeledField(
                    label: 'Password',
                    hint: '••••••••',
                    obscure: true,
                    controller: _passwordController,
                  ),
                  LabeledField(
                    label: 'Konfirmasi Password',
                    hint: '••••••••',
                    obscure: true,
                    controller: _confirmPasswordController,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: agree,
                          side: const BorderSide(
                            color: AppColors.dark,
                            width: 1.5,
                          ),
                          onChanged: (v) => setState(() => agree = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'Saya setuju dengan ',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.muted,
                            ),
                            children: [
                              _link('Syarat & Ketentuan'),
                              const TextSpan(text: ' dan '),
                              _link('Kebijakan Privasi'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            const SizedBox(height: 36),
            HardButton(
              label: loading ? 'Memproses...' : 'Daftar Sekarang',
              onTap: loading ? () {} : _submit,
            ),
            const SizedBox(height: 14),
            BottomLink(
              text: 'Sudah punya akun?',
              action: 'Masuk',
              onTap: () => _goLogin(context),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------
// 4. REGISTRASI BERHASIL
// ---------------------------------------------------------------
class SuccessScreen extends StatelessWidget {
  final String name;
  const SuccessScreen({super.key, this.name = 'Budi Santoso'});

  Widget _dot() => Container(
    width: 6,
    height: 6,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.muted,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        // dekorasi daun
        Positioned(
          top: -10,
          right: 10,
          child: Transform.rotate(
            angle: .5,
            child: Container(
              width: 130,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(90),
                  bottomRight: Radius.circular(90),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.bg,
                                  border: Border.all(color: _line),
                                ),
                              ),
                              Container(
                                width: 84,
                                height: 84,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.dark,
                                ),
                              ),
                              const Positioned(
                                right: 6,
                                top: 4,
                                child: AuthLogo(size: 24),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Akun Berhasil\nDibuat!',
                          textAlign: TextAlign.center,
                          style: display(size: 26),
                        ),
                        const SizedBox(height: 14),
                        Text.rich(
                          TextSpan(
                            text: 'Selamat datang di ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                text: 'RESIK',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.dark,
                                ),
                              ),
                              const TextSpan(text: ', '),
                              TextSpan(
                                text: name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.dark,
                                ),
                              ),
                              const TextSpan(
                                text: '. Kamu sekarang bisa mulai menyetor sampah dan mengumpulkan saldo.',
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 26),
                        HardButton(
                          label: 'Mulai Sekarang',
                          onTap: () => _goHome(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dot(),
                      const SizedBox(width: 6),
                      Container(
                        width: 26,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _dot(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
