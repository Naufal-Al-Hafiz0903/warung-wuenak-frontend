import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/data/auth_service.dart';

class RoleGuard extends StatelessWidget {
  final String requiredRole;
  final Widget child;

  const RoleGuard({super.key, required this.requiredRole, required this.child});

  Future<String?> _getRoleFallback() async {
    final role = await AuthService.getRole();
    if (role != null) return role;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("level");
  }

  String _routeForRole(String role) {
    final r = role.toLowerCase();
    if (r == 'admin') return '/admin';
    if (r == 'penjual' || r == 'seller') return '/seller';
    if (r == 'kurir' || r == 'courier') return '/courier';
    if (r == 'user') return '/user';
    return '/login';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getRoleFallback(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snapshot.data;
        if (role == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          });
          return const SizedBox.shrink();
        }

        final have = role.toLowerCase();
        final need = requiredRole.toLowerCase();

        if (have != need) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              _routeForRole(have),
              (_) => false,
            );
          });
          return const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}
