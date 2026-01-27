class SellerProductSalesModel {
  final int productId;
  final String namaProduk;
  final double harga;
  final int jumlahTerjual;
  final String? imageUrl;

  SellerProductSalesModel({
    required this.productId,
    required this.namaProduk,
    required this.harga,
    required this.jumlahTerjual,
    required this.imageUrl,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory SellerProductSalesModel.fromJson(Map<String, dynamic> j) {
    return SellerProductSalesModel(
      productId: _toInt(j['product_id']),
      namaProduk: (j['nama_produk'] ?? '').toString(),
      harga: _toDouble(j['harga']),
      jumlahTerjual: _toInt(j['jumlah_terjual']),
      imageUrl: (j['image_url'] ?? '').toString().trim().isEmpty
          ? null
          : (j['image_url'] ?? '').toString(),
    );
  }
}
