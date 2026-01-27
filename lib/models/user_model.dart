class UserModel {
  final int userId;
  final String name;
  final String email;
  final String level; // admin|penjual|user|kurir
  final String status; // aktif|nonaktif
  final double saldo;

  final String? nomorUser;
  final String? alamatUser;
  final String? createdAt;

  final String? photoUrl;

  // ✅ Tambahan lokasi terbaru (opsional)
  final double? lat;
  final double? lng;
  final int? accuracyM;
  final String? locationUpdatedAt;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.level,
    required this.status,
    required this.saldo,
    required this.nomorUser,
    required this.alamatUser,
    required this.createdAt,
    this.photoUrl,
    this.lat,
    this.lng,
    this.accuracyM,
    this.locationUpdatedAt,
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;
  static double? _toDoubleN(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static int? _toIntN(dynamic v) {
    if (v == null) return null;
    return int.tryParse(v.toString());
  }

  static String _toLowerStr(dynamic v, String def) {
    final s = (v ?? def).toString().trim();
    return s.isEmpty ? def : s.toLowerCase();
  }

  static String? _pick(dynamic a, dynamic b) {
    final v = a ?? b;
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory UserModel.fromJson(Map<String, dynamic> j) {
    return UserModel(
      userId: _toInt(j['user_id'] ?? j['userId']),
      name: (j['name'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      level: _toLowerStr(j['level'], 'user'),
      status: _toLowerStr(j['status'], 'aktif'),
      saldo: _toDouble(j['saldo']),
      nomorUser: _pick(j['nomor_user'], j['nomorUser']),
      alamatUser: _pick(j['alamat_user'], j['alamatUser']),
      createdAt: (j['created_at'] ?? j['createdAt'])?.toString(),
      photoUrl: _pick(j['photo_url'], j['photoUrl']),

      // lokasi (kalau kamu nanti gabung ke /me, tetap aman)
      lat: _toDoubleN(j['lat']),
      lng: _toDoubleN(j['lng']),
      accuracyM: _toIntN(j['accuracy_m'] ?? j['accuracyM']),
      locationUpdatedAt: (j['location_updated_at'] ?? j['locationUpdatedAt'])
          ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'level': level,
      'status': status,
      'saldo': saldo,
      'nomor_user': nomorUser,
      'alamat_user': alamatUser,
      'created_at': createdAt,
      'photo_url': photoUrl,

      // lokasi opsional
      'lat': lat,
      'lng': lng,
      'accuracy_m': accuracyM,
      'location_updated_at': locationUpdatedAt,
    };
  }
}
