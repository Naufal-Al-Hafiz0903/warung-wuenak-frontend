class CartItemModel {
  final int cartItemId;
  final int cartId;
  final int productId;
  final int quantity;

  final String namaProduk;
  final double harga;
  final int stok;
  final String status;
  final String categoryName;
  final String? imageUrl;

  CartItemModel({
    required this.cartItemId,
    required this.cartId,
    required this.productId,
    required this.quantity,
    required this.namaProduk,
    required this.harga,
    required this.stok,
    required this.status,
    required this.categoryName,
    required this.imageUrl,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory CartItemModel.fromJson(Map<String, dynamic> j) {
    return CartItemModel(
      cartItemId: _toInt(j['cart_item_id']),
      cartId: _toInt(j['cart_id']),
      productId: _toInt(j['product_id']),
      quantity: _toInt(j['quantity']),
      namaProduk: (j['nama_produk'] ?? '').toString(),
      harga: _toDouble(j['harga']),
      stok: _toInt(j['stok']),
      status: (j['status'] ?? 'aktif').toString(),
      categoryName: (j['category_name'] ?? '').toString(),
      imageUrl: j['image_url']?.toString(),
    );
  }
}
