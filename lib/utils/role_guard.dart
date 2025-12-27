import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class RoleGuard extends StatelessWidget {
  final String requiredRole;
  final Widget child;

  const RoleGuard({super.key, required this.requiredRole, required this.child});

  Future<String?> _getRoleFallback() async {
    // prioritas: AuthService (user_data)
    final role = await AuthService.getRole();
    if (role != null) return role;

    // fallback: key lama "level"
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("level");
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
          // Belum login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
          });
          return const SizedBox.shrink();
        }

        if (role != requiredRole) {
          // Role tidak sesuai
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // kalau penjual → ke seller, selain itu → login
            if (role == 'penjual' || role == 'seller') {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/seller',
                (_) => false,
              );
            } else {
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            }
          });
          return const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}
