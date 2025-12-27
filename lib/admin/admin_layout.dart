import 'package:flutter/material.dart';
import 'widgets/admin_menu_item.dart';
import 'widgets/admin_sidebar.dart';
import 'widgets/admin_header.dart';

import 'pages/admin_dashboard.dart';
import 'pages/admin_users_page.dart';
import 'pages/admin_products_page.dart';
import 'pages/admin_orders_page.dart';
import 'pages/admin_payments_page.dart';
import 'pages/admin_categories_page.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _index = 0;

  late final List<AdminMenuItemData> _menus = const [
    AdminMenuItemData(title: 'Dashboard', icon: Icons.dashboard),
    AdminMenuItemData(title: 'Users', icon: Icons.people),
    AdminMenuItemData(title: 'Products', icon: Icons.inventory_2),
    AdminMenuItemData(title: 'Orders', icon: Icons.receipt_long),
    AdminMenuItemData(title: 'Payments', icon: Icons.payments),
    AdminMenuItemData(title: 'Categories', icon: Icons.category),
  ];

  // HINDARI const list literal biar tidak kena "must be constants"
  late final List<Widget> _pages = [
    const AdminDashboardPage(),
    const AdminUsersPage(),
    const AdminProductsPage(),
    const AdminOrdersPage(),
    const AdminPaymentsPage(),
    const AdminCategoriesPage(),
  ];

  void _select(int i) {
    setState(() => _index = i);
    // fungsi tetap ada (tidak dihapus)
  }

  // fungsi tambahan khusus drawer (tidak menghapus fungsi lama)
  void _selectFromDrawer(int i, BuildContext drawerContext) {
    _select(i);
    if (Navigator.canPop(drawerContext))
      Navigator.pop(drawerContext); // tutup drawer
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AdminHeader(title: _menus[_index].title),
      drawer: isWide
          ? null
          : Drawer(
              child: Builder(
                builder: (drawerContext) {
                  return AdminSidebar(
                    selectedIndex: _index,
                    items: _menus,
                    onSelect: (i) => _selectFromDrawer(i, drawerContext),
                  );
                },
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            SizedBox(
              width: 260,
              child: Material(
                elevation: 1,
                child: AdminSidebar(
                  selectedIndex: _index,
                  items: _menus,
                  onSelect: _select,
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),
    );
  }
}
