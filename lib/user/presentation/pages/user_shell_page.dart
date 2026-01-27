import 'package:flutter/material.dart';

import 'user_home_page.dart';
import 'user_orders_page.dart';
import 'user_cart_page.dart';
import 'user_profile_page.dart';

class UserShellPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final int initialIndex;

  const UserShellPage({super.key, required this.user, this.initialIndex = 0});

  @override
  State<UserShellPage> createState() => _UserShellPageState();
}

class _UserShellPageState extends State<UserShellPage> {
  late int _index;

  // ✅ untuk memaksa Cart reload saat tab dipilih
  final GlobalKey<UserCartPageState> _cartKey = GlobalKey<UserCartPageState>();

  // ✅ untuk memaksa Home “recreate” agar stok ter-refresh setelah checkout sukses
  int _homeSeed = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;

    // kalau start langsung di cart, paksa reload setelah frame pertama
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_index == 2) {
        _cartKey.currentState?.reload(silent: false);
      }
    });
  }

  void _onTabTap(int i) {
    if (_index == i) {
      // kalau user tap tab yang sama, kita bisa paksa refresh juga
      if (i == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _cartKey.currentState?.reload(silent: false);
        });
      }
      return;
    }

    setState(() => _index = i);

    // ✅ setiap kali masuk tab Cart, paksa reload
    if (i == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cartKey.currentState?.reload(silent: false);
      });
    }
  }

  void _onCheckoutSuccessFromCart() {
    // ✅ checkout sukses -> refresh home agar stok berubah
    setState(() {
      _homeSeed++;
      // optional: bisa auto pindah ke tab Pesanan
      // _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      // ✅ Home di-wrap agar bisa dipaksa recreate (trigger initState ulang di Home)
      KeyedSubtree(
        key: ValueKey('home_$_homeSeed'),
        child: UserHomePage(user: widget.user),
      ),
      UserOrdersPage(user: widget.user),
      UserCartPage(
        key: _cartKey,
        user: widget.user,
        onCheckoutSuccess: _onCheckoutSuccessFromCart,
      ),
      UserProfilePage(user: widget.user),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          type: BottomNavigationBarType.fixed,
          onTap: _onTabTap,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_rounded),
              label: 'Produk',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Pesanan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_rounded),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
