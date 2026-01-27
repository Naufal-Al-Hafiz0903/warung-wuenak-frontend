import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api.dart';
import '../../models/toko_model.dart';
import '../../models/toko_product_item_model.dart';
import '../../services/user_http.dart';

class SellerTokoService {
  static const _tokenKeyLegacy = 'token';
  static const _tokenKeyNew = 'jwt_token';

  static Future<String?> _getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKeyNew) ?? sp.getString(_tokenKeyLegacy);
  }

  static Future<Map<String, dynamic>?> fetchMyTokoLocation() async {
    final res = await UserHttp.getJson('toko/my-location');
    if (res['ok'] == true) {
      final d = res['data'];
      if (d == null) return null;
      if (d is Map) return Map<String, dynamic>.from(d as Map);
    }
    return null;
  }

  static Future<TokoModel?> fetchMyToko() async {
    final res = await UserHttp.getJson('toko/my');
    if (res['ok'] == true && res['data'] is Map) {
      return TokoModel.fromJson(Map<String, dynamic>.from(res['data']));
    }
    return null;
  }

  static Future<Map<String, dynamic>> updateMyTokoLocation({
    required double lat,
    required double lng,
    int? accuracyM,
  }) async {
    return UserHttp.postJson('toko/update-location', {
      'lat': lat,
      'lng': lng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
    });
  }

  static Future<bool> updateMyToko({
    required String namaToko,
    String deskripsi = '',
    String alamat = '',
  }) async {
    final res = await UserHttp.postForm('toko/update-my', {
      'nama_toko': namaToko,
      'deskripsi_toko': deskripsi,
      'alamat_toko': alamat,
    });
    return res['ok'] == true;
  }

  static Future<List<TokoProductItemModel>> fetchMyProducts({
    String status = 'all', // all|aktif|nonaktif
    String sort = 'sold_desc', // sold_desc|sold_asc
  }) async {
    final res = await UserHttp.getJson(
      'toko/my/products?status=$status&sort=$sort',
    );
    if (res['ok'] == true && res['data'] is List) {
      return (res['data'] as List)
          .whereType<Map>()
          .map(
            (e) => TokoProductItemModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }
    return <TokoProductItemModel>[];
  }

  static Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${Api.baseUrl}$p');
  }

  static Future<TokoModel?> uploadBanner(File file) async {
    final token = await _getToken();
    final uri = _uri('toko/upload-banner');

    final req = http.MultipartRequest('POST', uri);
    req.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    req.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (kDebugMode) {
      debugPrint('[UPLOAD BANNER] $uri -> ${streamed.statusCode}');
      debugPrint(body);
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if ((decoded['ok'] == true || streamed.statusCode < 400) &&
            decoded['data'] is Map) {
          return TokoModel.fromJson(Map<String, dynamic>.from(decoded['data']));
        }
      }
    } catch (_) {}

    return null;
  }
}
