import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/data/auth_service.dart';
import '../../features/data/email_verification_service.dart';

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

  Future<bool?> _getEmailVerifiedFallback() async {
    final v = await AuthService.getEmailVerified();
    if (v != null) return v;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("email_verified");
  }

  Future<String?> _getEmailFallback() async {
    final user = await AuthService.getUser();
    final fromUser = user?['email']?.toString();
    if (fromUser != null && fromUser.trim().isNotEmpty) return fromUser.trim();

    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString("email");
    if (fromPrefs != null && fromPrefs.trim().isNotEmpty)
      return fromPrefs.trim();

    return null;
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
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([
        _getRoleFallback(),
        _getEmailVerifiedFallback(),
        _getEmailFallback(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snapshot.data != null
            ? snapshot.data![0] as String?
            : null;
        final emailVerified = snapshot.data != null
            ? snapshot.data![1] as bool?
            : null;
        final email = snapshot.data != null
            ? snapshot.data![2] as String?
            : null;

        if (role == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          });
          return const SizedBox.shrink();
        }

        if (emailVerified == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Email belum terverifikasi. Silakan verifikasi terlebih dahulu.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );

            final e = (email ?? '').trim().toLowerCase();
            if (e.isNotEmpty) {
              try {
                await EmailVerificationService().sendCode(email: e);
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/verify-email/code',
                  (_) => false,
                  arguments: {'email': e},
                );
                return;
              } catch (_) {
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/verify-email',
                  (_) => false,
                  arguments: {'email': e},
                );
                return;
              }
            }

            Navigator.pushNamedAndRemoveUntil(
              context,
              '/verify-email',
              (_) => false,
            );
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
