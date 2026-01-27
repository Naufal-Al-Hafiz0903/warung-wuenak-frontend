import 'package:flutter/material.dart';
import '../../../features/data/auth_service.dart';

class AdminHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const AdminHeader({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _logout(BuildContext context) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Logout'),
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
        ) ??
        false;

    if (!ok) return;

    await AuthService.logout();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,

      // ✅ ini bikin icon "menu" (hamburger) tetap muncul kalau ada drawer
      automaticallyImplyLeading: true,

      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.store_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Logout',
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout_rounded),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}
