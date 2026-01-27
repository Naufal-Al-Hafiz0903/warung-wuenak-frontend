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
    // admin list product
    final res = await AdminHttp.getJson('products/listProduct?status=all');
    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <ProductModel>[];
  }

  // =============================
  // CREATE PRODUCT -> return id
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

    for (final ep in candidates) {
      final res = await AdminHttp.postJson(ep, body);
      if (res['ok'] == true) {
        final pid = res['product_id'] ?? res['id'] ?? res['productId'];
        final id = int.tryParse(pid?.toString() ?? '') ?? 0;
        return id;
      }
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

  // fallback (jaga kompat)
  static Future<bool> createProductUniversal({
    required int tokoId,
    required int categoryId,
    required String namaProduk,
    required String deskripsi,
    required double harga,
    required int stok,
    required String status,
  }) async {
    // saat ini sama saja, tapi tetap disediakan supaya code lama tidak rusak
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
  // ✅ UPLOAD IMAGE (multipart)
  // =============================
  static Future<bool> uploadProductImage({
    required int productId,
    required File image,
    bool isPrimary = true,
  }) async {
    // ✅ hanya endpoint yang benar-benar ada di backend kamu
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
  // ✅ CREATE + IMAGE (dipakai UI)
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
    final id = await createProductReturnId(
      tokoId: tokoId,
      categoryId: categoryId,
      namaProduk: namaProduk,
      deskripsi: deskripsi,
      harga: harga,
      stok: stok,
      status: status,
    );

    if (id <= 0) return false;

    if (image != null) {
      // upload gambar, kalau gagal tidak membatalkan pembuatan produk
      await uploadProductImage(productId: id, image: image, isPrimary: true);
    }

    return true;
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

  // UPDATE PRODUCT
  static Future<bool> updateProduct({
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
    return res['ok'] == true;
  }

  // DELETE PRODUCT
  static Future<bool> deleteProduct(int productId) async {
    final res = await AdminHttp.postJson('products/deleteProducts', {
      'product_id': productId,
    });
    return res['ok'] == true;
  }
}
