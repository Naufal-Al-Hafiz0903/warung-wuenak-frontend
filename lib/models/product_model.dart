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
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory ProductModel.fromJson(Map<String, dynamic> j) {
    return ProductModel(
      productId: _toInt(j['product_id']),
      tokoId: _toInt(j['toko_id']),
      categoryId: _toInt(j['category_id']),
      namaProduk: (j['nama_produk'] ?? '').toString(),
      deskripsi: j['deskripsi']?.toString(),
      harga: _toDouble(j['harga']),
      stok: _toInt(j['stok']),
      status: (j['status'] ?? 'aktif').toString(),
      createdAt: j['created_at']?.toString(),
      categoryName: j['category_name']?.toString(),
    );
  }
}
