// lib/services/api_service.dart
// Service untuk komunikasi dengan RESIK Backend API

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) return configuredUrl;
    return kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api';
  }

  // ────────────────────────────────────────────────────────────
  // TOKEN MANAGEMENT
  // ────────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('resik_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('resik_token', token);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('resik_user', jsonEncode(user));
  }

  static Future<void> saveRememberMe(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('resik_remember_me', remember);
  }

  static Future<void> saveRememberedLogin(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('resik_remembered_login', identifier);
  }

  static Future<void> clearRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('resik_remembered_login');
  }

  static Future<String?> getRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('resik_remembered_login');
  }

  static Future<bool?> getRememberMePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('resik_remember_me');
  }

  static Future<bool> shouldRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('resik_remember_me') ?? true;
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('resik_user');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static Future<String> _profilePhotoStorageKey() async {
    final user = await getUser();
    final userId = user?['id']?.toString();
    return 'resik_profile_photo_${userId ?? 'guest'}';
  }

  static Future<Uint8List?> getProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(await _profilePhotoStorageKey());
    if (encoded == null) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      throw const FormatException('Foto profil tersimpan tidak valid.');
    }
  }

  static Future<void> saveProfilePhoto(Uint8List photo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await _profilePhotoStorageKey(), base64Encode(photo));
  }

  static Future<void> clearProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _profilePhotoStorageKey());
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('resik_token');
    await prefs.remove('resik_user');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ────────────────────────────────────────────────────────────
  // BASE REQUEST
  // ────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Map<String, dynamic> _parseResponse(http.Response res) {
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } on FormatException {
      throw ApiException('Respons server tidak dapat dibaca', res.statusCode);
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Format respons server tidak valid', res.statusCode);
    }
    final body = decoded;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(
      body['message']?.toString() ?? 'Terjadi kesalahan',
      res.statusCode,
    );
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    bool auth = true,
  }) async {
    final res = await http
        .get(Uri.parse('$baseUrl$path'), headers: await _headers(auth: auth))
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final res = await http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _parseResponse(res);
  }

  // ────────────────────────────────────────────────────────────
  // AUTH
  // ────────────────────────────────────────────────────────────

  /// Login nasabah dengan telepon/email + password
  static Future<Map<String, dynamic>> login({
    required String teleponAtauEmail,
    required String password,
    bool rememberMe = true,
  }) async {
    final result = await post('/auth/nasabah/login', {
      'telepon_atau_email': teleponAtauEmail,
      'password': password,
    }, auth: false);
    await _saveAuthResult(result, rememberMe: rememberMe);
    if (rememberMe) {
      await saveRememberedLogin(teleponAtauEmail.trim());
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('resik_remembered_login');
    }
    return result;
  }

  /// Registrasi nasabah baru
  static Future<Map<String, dynamic>> register({
    required String nama,
    required String telepon,
    required String password,
    String? email,
    String? alamat,
  }) async {
    final result = await post('/auth/nasabah/register', {
      'nama': nama,
      'telepon': telepon,
      'password': password,
      if (email != null) 'email': email,
      if (alamat != null) 'alamat': alamat,
    }, auth: false);
    await _saveAuthResult(result, rememberMe: true);
    return result;
  }

  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    return post('/auth/nasabah/password-reset/request', {
      'email': email.trim().toLowerCase(),
    }, auth: false);
  }

  static Future<Map<String, dynamic>> completePasswordReset({
    required String email,
    required String otp,
    required String password,
  }) async {
    return post('/auth/nasabah/password-reset/complete', {
      'email': email.trim().toLowerCase(),
      'otp': otp.trim(),
      'password': password,
    }, auth: false);
  }

  static Future<void> _saveAuthResult(
    Map<String, dynamic> result, {
    required bool rememberMe,
  }) async {
    final token = result['token'];
    final user = result['data'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw ApiException('Respons autentikasi server tidak lengkap', 500);
    }
    await saveToken(token);
    await saveUser(user);
    await saveRememberMe(rememberMe);
  }

  // ────────────────────────────────────────────────────────────
  // PROFIL NASABAH
  // ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfilSaya() async {
    return get('/nasabah/profil/saya');
  }

  static Future<Map<String, dynamic>> getDashboardSaya() async {
    return get('/nasabah/dashboard/saya');
  }

  static Future<Map<String, dynamic>> updateProfil({
    String? nama,
    String? alamat,
    String? email,
    String? nik,
    String? jenisTempat,
    String? alamatLengkap,
    String? rt,
    String? rw,
    String? kelurahan,
    String? kecamatan,
    String? kota,
    double? latitude,
    double? longitude,
  }) async {
    return put('/nasabah/profil/update', {
      if (nama != null) 'nama': nama,
      if (alamat != null) 'alamat': alamat,
      if (email != null) 'email': email,
      if (nik != null) 'nik': nik,
      if (jenisTempat != null) 'jenis_tempat': jenisTempat,
      if (alamatLengkap != null) 'alamat_lengkap': alamatLengkap,
      if (rt != null) 'rt': rt,
      if (rw != null) 'rw': rw,
      if (kelurahan != null) 'kelurahan': kelurahan,
      if (kecamatan != null) 'kecamatan': kecamatan,
      if (kota != null) 'kota': kota,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }

  static Future<Map<String, dynamic>> getMetodePencairanSaya() async {
    return get('/nasabah/rekening/saya');
  }

  static Future<Map<String, dynamic>> tambahMetodePencairan({
    required String metode,
    required String namaPemilik,
    required String nomorRekening,
  }) async {
    return post('/nasabah/rekening', {
      'metode': metode,
      'nama_pemilik': namaPemilik,
      'nomor_rekening': nomorRekening,
    });
  }

  static Future<Map<String, dynamic>> jadikanMetodePencairanUtama(
    int id,
  ) async {
    return put('/nasabah/rekening/$id/utama', {});
  }

  static Future<void> logoutNasabah() async {
    Object? requestError;
    try {
      await post('/auth/nasabah/logout', {});
    } catch (error) {
      requestError = error;
    } finally {
      await logout();
    }
    if (requestError != null) {
      throw ApiException(
        'Sesi di perangkat sudah dihapus, tetapi server gagal mengakhiri sesi: $requestError',
        0,
      );
    }
  }

  // ────────────────────────────────────────────────────────────
  // SETORAN
  // ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSetoranSaya({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    return get('/setoran/saya$query');
  }

  static Future<Map<String, dynamic>> kirimSetoran({
    required int jenisId,
    required double beratKg,
    String? catatan,
  }) async {
    return post('/setoran', {
      'jenis_id': jenisId,
      'berat_kg': beratKg,
      if (catatan != null) 'catatan': catatan,
    });
  }

  // ────────────────────────────────────────────────────────────
  // TRANSAKSI / SALDO
  // ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> tarikSaldo({
    required int jumlah,
    required String metode,
    required String nomorTujuan,
  }) async {
    return post('/transaksi/tarik', {
      'jumlah': jumlah,
      'metode': metode,
      'nomor_tujuan': nomorTujuan,
    });
  }

  static Future<Map<String, dynamic>> getRiwayatTransaksi({
    String? tipe,
  }) async {
    final query = tipe != null ? '?tipe=$tipe' : '';
    return get('/transaksi/saya$query');
  }

  // ────────────────────────────────────────────────────────────
  // JENIS SAMPAH & HARGA
  // ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getJenisSampah() async {
    return get('/jenis-sampah', auth: false);
  }

  // ────────────────────────────────────────────────────────────
  // NOTIFIKASI
  // ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNotifikasi() async {
    return get('/notifikasi/saya');
  }

  static Future<Map<String, dynamic>> tandaiNotifikasiBaca(int id) async {
    return put('/notifikasi/$id/baca', {});
  }

  // ────────────────────────────────────────────────────────────
  // TITIK SETOR
  // ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getTitikSetor() async {
    return get('/titik-setor', auth: false);
  }
}

// Custom exception
class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => 'ApiException($statusCode): $message';
}
