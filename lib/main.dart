import 'package:flutter/material.dart';

import 'features/presentation/login_page.dart';
import 'features/presentation/change_password_page.dart';
import 'features/presentation/email_verification_request_page.dart';
import 'features/presentation/email_verification_code_page.dart';

import 'core/guards/role_guard.dart';
import 'core/theme/app_theme.dart';

import 'seller/presentation/pages/seller_dashboard.dart';
import 'seller/presentation/pages/seller_products_page.dart';
import 'seller/presentation/pages/seller_product_add_page.dart';
import 'seller/presentation/pages/seller_orders_page.dart';
import 'seller/presentation/pages/seller_toko_page.dart';
import 'seller/presentation/pages/seller_profile_page.dart';
import 'seller/presentation/pages/seller_categories_page.dart';

import 'admin/presentation/layout/admin_layout.dart';
import 'user/presentation/pages/user_entry_page.dart';
import 'courier/presentation/pages/courier_entry_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routes: {
        '/': (_) => const LoginPage(),
        '/login': (_) => const LoginPage(),

        '/change-password': (_) => const ChangePasswordPage(),

        '/verify-email': (_) => const EmailVerificationRequestPage(),
        '/verify-email/code': (_) => const EmailVerificationCodePage(),

        '/user': (_) =>
            const RoleGuard(requiredRole: 'user', child: UserEntryPage()),

        '/courier': (_) =>
            const RoleGuard(requiredRole: 'kurir', child: CourierEntryPage()),

        '/seller': (_) =>
            const RoleGuard(requiredRole: 'penjual', child: SellerDashboard()),
        '/seller/products': (_) => const RoleGuard(
          requiredRole: 'penjual',
          child: SellerProductsPage(),
        ),
        '/seller/products/add': (_) => const RoleGuard(
          requiredRole: 'penjual',
          child: SellerProductAddPage(),
        ),
        '/seller/orders': (_) =>
            const RoleGuard(requiredRole: 'penjual', child: SellerOrdersPage()),
        '/seller/toko': (_) =>
            const RoleGuard(requiredRole: 'penjual', child: SellerTokoPage()),
        '/seller/profile': (_) => const RoleGuard(
          requiredRole: 'penjual',
          child: SellerProfilePage(),
        ),

        '/admin': (_) =>
            const RoleGuard(requiredRole: 'admin', child: AdminLayout()),

        '/seller/categories': (_) => const RoleGuard(
          requiredRole: 'penjual',
          child: SellerCategoriesPage(),
        ),
      },
      initialRoute: '/',
    );
  }
}
