import 'dart:io';

import '../../models/product_model.dart';
import '../../services/admin_http.dart';

class ProductAdminService {
  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['products'], res['items']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<ProductModel>> fetchProducts() async {
    final res = await AdminHttp.getJson('products/listProduct?status=all');
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <ProductModel>[];
  }

  // ============================================================
  // ✅ NEW: CREATE RESULT (agar frontend bisa pakai message backend)
  // ============================================================
  static Future<Map<String, dynamic>> createProductResult({
    required int tokoId,
    required int categoryId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
  }) async {
    final body = <String, dynamic>{
      'toko_id': tokoId,
      'category_id': categoryId,
      'nama_produk': namaProduk,
      'deskripsi': deskripsi,
      'harga': harga,
      'stok': stok,
      'status': status,
    };

    final candidates = <String>[
      'products/createProducts',
      'products/createProduct',
      'products/create',
    ];

    Map<String, dynamic>? last;
    for (final ep in candidates) {
      final res = await AdminHttp.postJson(ep, body);
      last = res;
      if (res['ok'] == true) return res;
    }

    return last ??
        <String, dynamic>{'ok': false, 'message': 'Gagal membuat produk'};
  }

  // ============================================================
  // ✅ NEW: CREATE + IMAGE RESULT (return ok + message + product_id)
  // ============================================================
  static Future<Map<String, dynamic>> createProductWithImageResult({
    required int tokoId,
    required int categoryId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
    File? image,
  }) async {
    final res = await createProductResult(
      tokoId: tokoId,
      categoryId: categoryId,
      namaProduk: namaProduk,
      deskripsi: deskripsi,
      harga: harga,
      stok: stok,
      status: status,
    );

    if (res['ok'] != true) return res;

    final pid = res['product_id'] ?? res['id'] ?? res['productId'];
    final productId = int.tryParse(pid?.toString() ?? '') ?? 0;

    if (productId <= 0) {
      return <String, dynamic>{
        'ok': false,
        'message': 'Produk dibuat, tapi product_id tidak valid',
      };
    }

    if (image != null) {
      final up = await uploadProductImage(
        productId: productId,
        image: image,
        isPrimary: true,
      );
      if (!up) {
        return <String, dynamic>{
          'ok': true,
          'product_id': productId,
          'message': 'Produk dibuat, tapi upload gambar gagal',
        };
      }
    }

    return <String, dynamic>{
      'ok': true,
      'product_id': productId,
      'message': (res['message'] ?? 'Produk berhasil dibuat').toString(),
    };
  }

  // =============================
  // CREATE PRODUCT -> return id (kompat lama)
  // =============================
  static Future<int> createProductReturnId({
    required int tokoId,
    required int categoryId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
  }) async {
    final res = await createProductResult(
      tokoId: tokoId,
      categoryId: categoryId,
      namaProduk: namaProduk,
      deskripsi: deskripsi,
      harga: harga,
      stok: stok,
      status: status,
    );

    if (res['ok'] == true) {
      final pid = res['product_id'] ?? res['id'] ?? res['productId'];
      return int.tryParse(pid?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  static Future<bool> createProduct({
    required int tokoId,
    required int categoryId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
  }) async {
    final id = await createProductReturnId(
      tokoId: tokoId,
      categoryId: categoryId,
      namaProduk: namaProduk,
      deskripsi: deskripsi,
      harga: harga,
      stok: stok,
      status: status,
    );
    return id > 0;
  }

  static Future<bool> createProductUniversal({
    required int tokoId,
    required int categoryId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
  }) async {
    return createProduct(
      tokoId: tokoId,
      categoryId: categoryId,
      namaProduk: namaProduk,
      deskripsi: deskripsi,
      harga: harga,
      stok: stok,
      status: status,
    );
  }

  // =============================
  // UPLOAD IMAGE (multipart)
  // =============================
  static Future<bool> uploadProductImage({
    required int productId,
    required File image,
    bool isPrimary = true,
  }) async {
    final res = await AdminHttp.postMultipart(
      'products/upload-image',
      file: image,
      fileField: 'file',
      fields: {
        'product_id': productId.toString(),
        'is_primary': isPrimary ? '1' : '0',
      },
    );
    return res['ok'] == true;
  }

  // =============================
  // CREATE + IMAGE (kompat lama)
  // =============================
  static Future<bool> createProductWithImage({
    required int tokoId,
    required int categoryId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
    File? image,
  }) async {
    final res = await createProductWithImageResult(
      tokoId: tokoId,
      categoryId: categoryId,
      namaProduk: namaProduk,
      deskripsi: deskripsi,
      harga: harga,
      stok: stok,
      status: status,
      image: image,
    );
    return res['ok'] == true;
  }

  // =============================
  // UPDATE STATUS
  // =============================
  static Future<bool> updateStatus({
    required int productId,
    required String status,
  }) async {
    final res = await AdminHttp.postJson('products/updateStatus', {
      'product_id': productId,
      'status': status,
    });
    return res['ok'] == true;
  }

  // ============================================================
  // ✅ NEW: UPDATE RESULT (message backend)
  // ============================================================
  static Future<Map<String, dynamic>> updateProductResult({
    required int productId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
    required int categoryId,
  }) async {
    final res = await AdminHttp.postJson('products/updateProducts', {
      'product_id': productId,
      'category_id': categoryId,
      'nama_produk': namaProduk,
      'deskripsi': deskripsi,
      'harga': harga,
      'stok': stok,
      'status': status,
    });

    return res;
  }

  // ============================================================
  // ✅ NEW: UPDATE + IMAGE RESULT (message backend)
  // ============================================================
  static Future<Map<String, dynamic>> updateProductWithImageResult({
    required int productId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
    required int categoryId,
    File? image,
  }) async {
    final res = await updateProductResult(
      productId: productId,
      namaProduk: namaProduk,
      deskripsi: deskripsi,
      harga: harga,
      stok: stok,
      status: status,
      categoryId: categoryId,
    );

    if (res['ok'] != true) return res;

    if (image != null) {
      final upOk = await uploadProductImage(
        productId: productId,
        image: image,
        isPrimary: true,
      );

      if (!upOk) {
        return <String, dynamic>{
          'ok': true,
          'message': 'Produk diupdate, tapi upload gambar gagal',
        };
      }
    }

    return <String, dynamic>{
      'ok': true,
      'message': (res['message'] ?? 'Produk diupdate').toString(),
    };
  }

  // =============================
  // UPDATE PRODUCT (kompat lama)
  // =============================
  static Future<bool> updateProduct({
    required int productId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
    required int categoryId,
  }) async {
    final res = await updateProductResult(
      productId: productId,
      namaProduk: namaProduk,
      deskripsi: deskripsi,
      harga: harga,
      stok: stok,
      status: status,
      categoryId: categoryId,
    );
    return res['ok'] == true;
  }

  static Future<bool> updateProductWithImage({
    required int productId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
    required int categoryId,
    File? image,
  }) async {
    final res = await updateProductWithImageResult(
      productId: productId,
      namaProduk: namaProduk,
      deskripsi: deskripsi,
      harga: harga,
      stok: stok,
      status: status,
      categoryId: categoryId,
      image: image,
    );
    return res['ok'] == true;
  }

  // =============================
  // DELETE PRODUCT
  // =============================
  static Future<bool> deleteProduct(int productId) async {
    final res = await AdminHttp.postJson('products/deleteProducts', {
      'product_id': productId,
    });
    return res['ok'] == true;
  }
}
