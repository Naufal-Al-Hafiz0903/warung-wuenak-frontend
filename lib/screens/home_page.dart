import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final Map<String, dynamic> user;

  const HomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final String role = user["level"] ?? "user";
    final String name = user["name"] ?? "-";
    final String email = user["email"] ?? "-";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: _roleColor(role),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Login Berhasil",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),

            Text("Nama   : $name"),
            Text("Email  : $email"),
            Text("Role   : $role"),

            const SizedBox(height: 32),

            _roleWidget(role),
          ],
        ),
      ),
    );
  }

  // ===============================
  // WIDGET BERDASARKAN ROLE
  // ===============================
  Widget _roleWidget(String role) {
    switch (role) {
      case "admin":
        return _adminView();
      case "penjual":
        return _penjualView();
      default:
        return _userView();
    }
  }

  Widget _adminView() {
    return Card(
      color: Colors.red.shade50,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "🔴 LOGIN SEBAGAI ADMIN\n\n"
          "• Kelola semua user\n"
          "• Kelola toko\n"
          "• Kelola produk\n"
          "• Monitoring transaksi",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _penjualView() {
    return Card(
      color: Colors.orange.shade50,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "🟠 LOGIN SEBAGAI PENJUAL\n\n"
          "• Kelola produk sendiri\n"
          "• Lihat pesanan\n"
          "• Proses pengiriman",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _userView() {
    return Card(
      color: Colors.green.shade50,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "🟢 LOGIN SEBAGAI USER\n\n"
          "• Lihat produk\n"
          "• Belanja\n"
          "• Lihat status pesanan",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case "admin":
        return Colors.red;
      case "penjual":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}
