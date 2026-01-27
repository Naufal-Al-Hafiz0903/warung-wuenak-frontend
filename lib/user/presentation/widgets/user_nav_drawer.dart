import 'package:flutter/material.dart';

import '../pages/user_cart_page.dart';
import '../pages/user_orders_page.dart';
import '../pages/user_profile_page.dart';
import '../../../features/data/auth_service.dart';

enum UserNavItem { home, cart, orders, profile }

class UserNavDrawer extends StatelessWidget {
  final Map<String, dynamic> user;
  final UserNavItem current;

  const UserNavDrawer({super.key, required this.user, required this.current});

  String _name() => (user['name'] ?? 'User').toString();
  String _email() => (user['email'] ?? '-').toString();

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  ListTile _item({
    required BuildContext context,
    required UserNavItem id,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final active = current == id;

    return ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: active ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
      selected: active,
      onTap: () {
        // kalau menu yang dipilih sama dengan halaman aktif,
        // cukup tutup drawer tanpa push halaman baru
        Navigator.pop(context);
        if (active) return;
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6D28D9),
                    Color(0xFF9333EA),
                    Color(0xFFA855F7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_rounded, color: Color(0xFF6D28D9)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _email(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE9D5FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Menu
            _item(
              context: context,
              id: UserNavItem.home,
              icon: Icons.home_rounded,
              label: 'Beranda',
              onTap: () {
                // kalau tidak sedang di home, cukup kembali ke halaman sebelumnya
                // (umumnya shell/home berada di bawah stack)
                Navigator.popUntil(context, (r) => r.isFirst);
              },
            ),

            _item(
              context: context,
              id: UserNavItem.cart,
              icon: Icons.shopping_cart_rounded,
              label: 'Keranjang',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserCartPage(user: user)),
                );
              },
            ),

            _item(
              context: context,
              id: UserNavItem.orders,
              icon: Icons.receipt_long_rounded,
              label: 'Pesanan Saya',
              onTap: () {
                // ✅ FIX: UserOrdersPage membutuhkan parameter user
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserOrdersPage(user: user)),
                );
              },
            ),

            _item(
              context: context,
              id: UserNavItem.profile,
              icon: Icons.person_rounded,
              label: 'Profil',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfilePage(user: user),
                  ),
                );
              },
            ),

            const Spacer(),

            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
