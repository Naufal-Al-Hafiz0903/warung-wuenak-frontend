class ShipmentEventModel {
  // diproses|dikemas|dikirim|dalam_perjalanan|sampai|selesai|dibatalkan
  final String status;
  final String? description;
  final String? location;
  final String createdAt;

  ShipmentEventModel({
    required this.status,
    required this.createdAt,
    this.description,
    this.location,
  });

  factory ShipmentEventModel.fromJson(Map<String, dynamic> j) {
    return ShipmentEventModel(
      status: (j['status'] ?? 'diproses').toString(),
      description: j['description']?.toString(),
      location: j['location']?.toString(),
      createdAt: (j['created_at'] ?? j['createdAt'] ?? '').toString(),
    );
  }
}
