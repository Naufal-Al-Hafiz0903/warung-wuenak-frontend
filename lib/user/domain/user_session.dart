class UserSession {
  final String role; // admin|penjual|user
  final String name;
  final String email;
  final double saldo;

  const UserSession({
    required this.role,
    required this.name,
    required this.email,
    required this.saldo,
  });

  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory UserSession.fromMap(Map<String, dynamic>? j) {
    final m = j ?? {};
    return UserSession(
      role: (m['level'] ?? 'user').toString().toLowerCase(),
      name: (m['name'] ?? '-').toString(),
      email: (m['email'] ?? '-').toString(),
      saldo: _toDouble(m['saldo']),
    );
  }
}
