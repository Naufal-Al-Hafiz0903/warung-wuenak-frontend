import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api.dart';
import '../../models/image_model.dart';

class UploadService {
  // ====== SESUAIKAN DENGAN BACKEND KAMU ======
  static const String listImagesEndpoint = 'products/images';
  static const String uploadImageEndpoint = 'products/uploadImage';
  static const String deleteImageEndpoint = 'products/deleteImage';
  // ==========================================

  static const _tokenKeyLegacy = 'token';
  static const _tokenKeyNew = 'jwt_token';

  static Future<String?> _getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKeyNew) ?? sp.getString(_tokenKeyLegacy);
  }

  static Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${Api.baseUrl}$p');
  }

  static List<dynamic> _extractList(Map<String, dynamic> res) {
    final candidates = <dynamic>[res['data'], res['images'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return <dynamic>[];
  }

  static Future<List<ImageModel>> fetchProductImages(int productId) async {
    final token = await _getToken();
    final uri = _uri('$listImagesEndpoint?product_id=$productId');

    try {
      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        debugPrint('[IMG GET] $uri -> ${res.statusCode}');
        debugPrint(res.body);
      }

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        final ok = decoded['ok'] == true || res.statusCode < 400;
        if (!ok) return [];
        final list = _extractList(decoded);
        return list
            .whereType<Map>()
            .map((e) => ImageModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => ImageModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('[IMG GET] error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> uploadProductImageFile({
    required int productId,
    required File file,
    String fieldName = 'file',
  }) async {
    final token = await _getToken();
    final uri = _uri(uploadImageEndpoint);

    try {
      final req = http.MultipartRequest('POST', uri);
      req.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }

      req.fields['product_id'] = productId.toString();
      req.files.add(await http.MultipartFile.fromPath(fieldName, file.path));

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      if (kDebugMode) {
        debugPrint('[IMG UPLOAD] $uri -> ${streamed.statusCode}');
        debugPrint(body);
      }

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        decoded['ok'] ??= streamed.statusCode < 400;
        return decoded;
      }

      return {
        'ok': streamed.statusCode < 400,
        'message': 'Upload selesai',
        'raw': body,
        'status': streamed.statusCode,
      };
    } catch (e) {
      return {'ok': false, 'message': 'Upload error: $e'};
    }
  }

  static Future<bool> deleteImage({required int imageId}) async {
    final token = await _getToken();
    final uri = _uri(deleteImageEndpoint);

    try {
      final res = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: {'image_id': imageId.toString()},
      );

      if (kDebugMode) {
        debugPrint('[IMG DELETE] $uri -> ${res.statusCode}');
        debugPrint(res.body);
      }

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['ok'] == true || res.statusCode < 400;
      }

      return res.statusCode < 400;
    } catch (e) {
      if (kDebugMode) debugPrint('[IMG DELETE] error: $e');
      return false;
    }
  }
}
