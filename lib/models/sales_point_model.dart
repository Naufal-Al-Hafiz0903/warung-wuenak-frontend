class SalesPointModel {
  final String label; // "01" atau "01/02-07/02"
  final double total;

  SalesPointModel({required this.label, required this.total});

  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory SalesPointModel.fromJson(Map<String, dynamic> j) {
    return SalesPointModel(
      label: (j['label'] ?? '').toString(),
      total: _toDouble(j['total']),
    );
  }
}
