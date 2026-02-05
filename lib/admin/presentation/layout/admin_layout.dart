import 'package:flutter/material.dart';

import '../widgets/admin_menu_item.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/admin_header.dart';
import '../widgets/admin_ui.dart';

// ✅ pakai alias biar tidak bentrok nama class
import '../pages/admin_dashboard.dart' as page_dashboard;
import '../pages/admin_users_page.dart' as page_users;
import '../pages/admin_toko_page.dart' as page_toko;
import '../pages/admin_products_page.dart' as page_products;
import '../pages/admin_orders_page.dart' as page_orders;
import '../pages/admin_payments_page.dart' as page_payments;
import '../pages/admin_categories_page.dart' as page_categories;

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _index = 0;

  final List<AdminMenuItemData> _menus = const [
    AdminMenuItemData(title: 'Dashboard', icon: Icons.dashboard_rounded),
    AdminMenuItemData(title: 'Users', icon: Icons.people_alt_rounded),
    AdminMenuItemData(title: 'Toko', icon: Icons.store_rounded),
    AdminMenuItemData(title: 'Products', icon: Icons.inventory_2_rounded),
    AdminMenuItemData(title: 'Orders', icon: Icons.receipt_long_rounded),
    AdminMenuItemData(title: 'Payments', icon: Icons.payments_rounded),
    AdminMenuItemData(title: 'Categories', icon: Icons.category_rounded),
  ];

  late final List<Widget> _pages = [
    const page_dashboard.AdminDashboardPage(),
    const page_users.AdminUsersPage(),
    const page_toko.AdminTokoPage(),
    const page_products.AdminProductsPage(),
    const page_orders.AdminOrdersPage(),
    const page_payments.AdminPaymentsPage(),
    const page_categories.AdminCategoriesPage(),
  ];

  void _select(int i) => setState(() => _index = i);

  void _selectFromDrawer(int i, BuildContext drawerContext) {
    _select(i);
    if (Navigator.canPop(drawerContext)) Navigator.pop(drawerContext);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return AdminPageBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AdminHeader(title: _menus[_index].title),
        drawer: isWide
            ? null
            : Drawer(
                child: Builder(
                  builder: (drawerContext) => AdminSidebar(
                    selectedIndex: _index,
                    items: _menus,
                    onSelect: (i) => _selectFromDrawer(i, drawerContext),
                  ),
                ),
              ),
        body: Row(
          children: [
            if (isWide)
              SizedBox(
                width: 280,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  child: AdminSidebar(
                    selectedIndex: _index,
                    items: _menus,
                    onSelect: _select,
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Material(
                    color: const Color(0xCCFFFFFF),
                    child: IndexedStack(index: _index, children: _pages),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
