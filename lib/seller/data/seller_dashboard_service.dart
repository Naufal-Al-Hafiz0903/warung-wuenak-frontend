import '../../models/sales_point_model.dart';
import '../../models/seller_product_sales_model.dart';
import '../../services/user_http.dart';

class SellerDashboardService {
  static const String _salesEp = 'seller/dashboard/sales';
  static const String _productsEp = 'seller/dashboard/products';

  static List _extractList(Map<String, dynamic> res) {
    final candidates = [res['data'], res['items'], res['list']];
    for (final c in candidates) {
      if (c is List) return c;
    }
    return [];
  }

  static Future<List<SalesPointModel>> fetchMonthlySales({
    required String mode, // daily | weekly
    int days = 30,
  }) async {
    final ep = '$_salesEp?mode=$mode&days=$days';
    final res = await UserHttp.getJson(ep);

    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map((e) => SalesPointModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return <SalesPointModel>[];
  }

  static Future<List<SellerProductSalesModel>> fetchProductsSold({
    int days = 30,
    int limit = 20,
  }) async {
    final ep = '$_productsEp?days=$days&limit=$limit';
    final res = await UserHttp.getJson(ep);

    if (res['ok'] == true) {
      final list = _extractList(res);
      return list
          .map(
            (e) =>
                SellerProductSalesModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }

    return <SellerProductSalesModel>[];
  }
}
