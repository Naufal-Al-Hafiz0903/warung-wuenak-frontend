import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/data/auth_service.dart';

import '../../../core/config/app_config.dart';
import '../../../user/data/me_service.dart';

class SellerLayout extends StatelessWidget {
  final Widget child;
  final String title;

  const SellerLayout({
    super.key,
    required this.child,
    this.title = "Panel Penjual",
  });

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    // 1) coba refresh dari server (lebih akurat: userId, photoUrl, dll)
    try {
      final me = await MeService.fetchMe();
      if (me != null) {
        final j = me.toJson();
        return {
          "user_id": j['user_id'] ?? j['userId'],
          "name": (j['name'] ?? 'Penjual').toString().trim(),
          "email": (j['email'] ?? '').toString().trim(),
          "photo_url": (j['photo_url'] ?? j['photoUrl'])?.toString(),
        };
      }
    } catch (_) {}

    // 2) fallback SharedPreferences (tetap jalan walau server error)
    final sp = await SharedPreferences.getInstance();
    return {
      "user_id": sp.getInt("user_id") ?? 0,
      "name": (sp.getString("name") ?? "Penjual").trim(),
      "email": (sp.getString("email") ?? "").trim(),
      "photo_url": sp.getString("photo_url"),
    };
  }

  int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _resolvePhotoUrl(Map<String, dynamic> p) {
    final raw = (p['photo_url'] ?? p['photoUrl'])?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      if (raw.startsWith('http')) return raw;
      if (raw.startsWith('/')) return '${AppConfig.baseUrl}$raw';
      return '${AppConfig.baseUrl}/$raw';
    }
    final uid = _toInt(p['user_id'] ?? p['userId']);
    if (uid > 0) return '${AppConfig.baseUrl}/me/photo/$uid';
    return '';
  }

  void _goProfile(BuildContext context) {
    Navigator.pop(context); // tutup drawer
    Future.microtask(() {
      if (!context.mounted) return;
      Navigator.pushNamed(context, '/seller/profile');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _loadProfile(),
              builder: (context, snap) {
                final data = snap.data ?? {};
                final name = (data["name"] ?? "Penjual").toString();
                final email = (data["email"] ?? "").toString();
                final photo = _resolvePhotoUrl(data);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _goProfile(context),
                    child: DrawerHeader(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ClipOval(
                              child: Container(
                                width: 44,
                                height: 44,
                                color: Colors.white.withOpacity(.9),
                                child: photo.isNotEmpty
                                    ? Image.network(
                                        photo,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.storefront),
                                      )
                                    : const Icon(Icons.storefront),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            const SizedBox(height: 2),
                            const Text(
                              "Ketuk untuk buka Profil",
                              style: TextStyle(
                                color: Color(0xFFEDE9FE),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.dashboard),
                    title: const Text("Dashboard"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/seller',
                        (_) => false,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.store),
                    title: const Text("Toko Saya"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/seller/toko');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: const Text("Produk"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/seller/products');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text("Pesanan"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/seller/orders');
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text("Logout"),
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: child,
    );
  }
}
