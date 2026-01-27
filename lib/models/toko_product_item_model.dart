class TokoProductItemModel {
  final int productId;
  final String namaProduk;
  final double harga;
  final String status; // aktif|nonaktif
  final int stok;

  final int soldQty;
  final String? imageUrl;

  TokoProductItemModel({
    required this.productId,
    required this.namaProduk,
    required this.harga,
    required this.status,
    required this.stok,
    required this.soldQty,
    required this.imageUrl,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory TokoProductItemModel.fromJson(Map<String, dynamic> j) {
    return TokoProductItemModel(
      productId: _toInt(j['product_id']),
      namaProduk: (j['nama_produk'] ?? '').toString(),
      harga: _toDouble(j['harga']),
      status: (j['status'] ?? 'aktif').toString(),
      stok: _toInt(j['stok']),
      soldQty: _toInt(j['sold_qty'] ?? j['soldQty']),
      imageUrl: (j['image_url'] ?? j['imageUrl'])?.toString(),
    );
  }
}
