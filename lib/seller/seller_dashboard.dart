import 'package:flutter/material.dart';
import 'seller_layout.dart';

class SellerDashboard extends StatelessWidget {
  const SellerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerLayout(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text("Selamat Datang, Penjual"),
            SizedBox(height: 12),
            Text("Kelola toko, produk, dan pesanan Anda"),
          ],
        ),
      ),
    );
  }
}
