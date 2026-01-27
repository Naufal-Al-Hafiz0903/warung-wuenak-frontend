class ProductModel {
  final int productId;
  final int tokoId;
  final int categoryId;
  final String namaProduk;
  final String? deskripsi;
  final double harga;
  final int stok;
  final String status; // aktif|nonaktif
  final String? createdAt;

  final String? categoryName;
  final String? imageUrl; // optional

  ProductModel({
    required this.productId,
    required this.tokoId,
    required this.categoryId,
    required this.namaProduk,
    required this.deskripsi,
    required this.harga,
    required this.stok,
    required this.status,
    required this.createdAt,
    required this.categoryName,
    required this.imageUrl,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory ProductModel.fromJson(Map<String, dynamic> j) {
    return ProductModel(
      productId: _toInt(j['product_id'] ?? j['productId'] ?? j['id']),
      tokoId: _toInt(j['toko_id'] ?? j['tokoId']),
      categoryId: _toInt(j['category_id'] ?? j['categoryId']),
      namaProduk: (j['nama_produk'] ?? j['namaProduk'] ?? j['name'] ?? '')
          .toString(),
      deskripsi: (j['deskripsi'] ?? j['deskripsi_produk'] ?? j['description'])
          ?.toString(),
      harga: _toDouble(j['harga'] ?? j['price']),
      stok: _toInt(j['stok'] ?? j['stock']),
      status: (j['status'] ?? 'aktif').toString(),
      createdAt: (j['created_at'] ?? j['createdAt'])?.toString(),
      categoryName: (j['category_name'] ?? j['categoryName'])?.toString(),
      imageUrl: (j['image_url'] ?? j['imageUrl'] ?? j['gambar'])?.toString(),
    );
  }
}
