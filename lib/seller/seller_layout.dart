import 'package:flutter/material.dart';

class SellerLayout extends StatelessWidget {
  final Widget child;
  const SellerLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Panel Penjual")),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(child: Text("Menu Penjual")),
            ListTile(
              title: const Text("Dashboard"),
              onTap: () => Navigator.pushNamed(context, '/seller'),
            ),
            ListTile(
              title: const Text("Toko Saya"),
              onTap: () => Navigator.pushNamed(context, '/seller/toko'),
            ),
            ListTile(
              title: const Text("Produk"),
              onTap: () => Navigator.pushNamed(context, '/seller/products'),
            ),
            ListTile(
              title: const Text("Pesanan"),
              onTap: () => Navigator.pushNamed(context, '/seller/orders'),
            ),
            ListTile(
              title: const Text("Logout"),
              onTap: () {
                // AuthService.logout()
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: child,
    );
  }
}
