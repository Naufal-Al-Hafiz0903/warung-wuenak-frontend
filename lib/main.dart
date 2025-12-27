import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'seller/seller_dashboard.dart';
import 'admin/admin_layout.dart';
import 'utils/role_guard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/': (context) => LoginPage(),
        '/seller': (context) => const SellerDashboard(),
        '/admin': (context) =>
            const RoleGuard(requiredRole: 'admin', child: AdminLayout()),
      },
      initialRoute: '/',
    );
  }
}
