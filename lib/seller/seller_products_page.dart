import 'package:flutter/material.dart';
import '../services/product_service.dart';
import 'seller_layout.dart';

class SellerProductsPage extends StatelessWidget {
  const SellerProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerLayout(
      child: FutureBuilder(
        future: ProductService.getSellerProducts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data as List;

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(products[i]['nama_produk']),
              subtitle: Text("Rp ${products[i]['harga']}"),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/seller/products/edit',
                    arguments: products[i],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
