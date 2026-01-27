import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../services/user_http.dart';
import '../../core/config/app_config.dart';

class MeService {
  static const _userKey = 'user_data';
  static const int maxPhotoBytes = 2 * 1024 * 1024; // 2MB

  static Future<void> _saveUser(UserModel me) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_userKey, jsonEncode(me.toJson()));
  }

  static Future<UserModel?> fetchMe() async {
    final paths = <String>['me', 'users/me'];

    for (final p in paths) {
      final res = await UserHttp.getJson(p);
      if (res['ok'] == true) {
        final data = (res['data'] is Map)
            ? Map<String, dynamic>.from(res['data'] as Map)
            : Map<String, dynamic>.from(res);

        final me = UserModel.fromJson(data);
        await _saveUser(me);
        return me;
      }
    }
    return null;
  }

  static Future<UserModel?> updateProfile({
    required String name,
    required String nomorUser,
    required String alamatUser,
  }) async {
    final res = await UserHttp.postJson('me/update', {
      'name': name.trim(),
      'nomor_user': nomorUser.trim(),
      'alamat_user': alamatUser.trim(),
    });

    if (res['ok'] == true) {
      final data = (res['data'] is Map)
          ? Map<String, dynamic>.from(res['data'] as Map)
          : null;

      if (data != null) {
        final me = UserModel.fromJson(data);
        await _saveUser(me);
        return me;
      }
      return fetchMe();
    }

    return null;
  }

  // ==========================================================
  // ✅ LOCATION API
  // ==========================================================

  /// GET /me/location
  /// return row {user_id, lat, lng, accuracy_m, updated_at} atau null
  static Future<Map<String, dynamic>?> fetchMyLocation() async {
    final res = await UserHttp.getJson('me/location');

    if (res['ok'] == true) {
      final d = res['data'];
      if (d == null) return null;
      if (d is Map) return Map<String, dynamic>.from(d as Map);
    }

    return null;
  }

  /// POST /me/location
  /// body: {lat, lng, accuracy_m?}
  static Future<Map<String, dynamic>> updateMyLocation({
    required double lat,
    required double lng,
    int? accuracyM,
  }) async {
    final body = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
    };

    final res = await UserHttp.postJson('me/location', body);
    return res;
  }

  // ==========================================================
  // PHOTO
  // ==========================================================

  static Future<Map<String, dynamic>> uploadPhotoResult(File file) async {
    try {
      final bytes = await file.length();
      if (bytes > maxPhotoBytes) {
        return {
          'ok': false,
          'message':
              'Ukuran foto terlalu besar (${(bytes / 1024 / 1024).toStringAsFixed(2)} MB). Maks 2MB.',
        };
      }
    } catch (e) {
      return {'ok': false, 'message': 'Gagal cek ukuran file: $e'};
    }

    final token = await UserHttp.getTokenForMultipart();
    if (token == null || token.isEmpty) {
      return {'ok': false, 'message': 'Token kosong. Silakan login ulang.'};
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/me/photo');

    try {
      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['Accept'] = 'application/json';

      req.files.add(await http.MultipartFile.fromPath('photo', file.path));

      if (kDebugMode) {
        debugPrint('[ME PHOTO] POST $uri');
        debugPrint('[ME PHOTO] file=${file.path}');
      }

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      if (kDebugMode) {
        debugPrint('[ME PHOTO] status=${streamed.statusCode}');
        debugPrint('[ME PHOTO] body=$body');
      }

      final decoded = UserHttp.safeJsonDecode(body, streamed.statusCode);
      decoded['ok'] ??= streamed.statusCode < 400;
      decoded['statusCode'] ??= streamed.statusCode;

      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      return {'ok': false, 'message': 'Upload error: $e'};
    }
  }

  static Future<String?> uploadPhoto(File file) async {
    final res = await uploadPhotoResult(file);
    if (res['ok'] == true) return res['photo_url']?.toString();
    return null;
  }
}
