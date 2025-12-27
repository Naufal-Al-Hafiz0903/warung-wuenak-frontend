class UserModel {
  final int userId;
  final String name;
  final String email;
  final String level; // admin|penjual|user
  final String status; // aktif|nonaktif
  final double saldo;

  final String? nomorUser;
  final String? alamatUser;
  final String? createdAt;

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
  });

  static int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory UserModel.fromJson(Map<String, dynamic> j) {
    return UserModel(
      userId: _toInt(j['user_id']),
      name: (j['name'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      level: (j['level'] ?? 'user').toString(),
      status: (j['status'] ?? 'aktif').toString(),
      saldo: _toDouble(j['saldo']),
      nomorUser: j['nomor_user']?.toString(),
      alamatUser: j['alamat_user']?.toString(),
      createdAt: j['created_at']?.toString(),
    );
  }
}
