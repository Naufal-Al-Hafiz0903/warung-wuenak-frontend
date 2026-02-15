// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../features/data/auth_service.dart';

// class RoleGuard extends StatelessWidget {
//   final String requiredRole;
//   final Widget child;

//   const RoleGuard({super.key, required this.requiredRole, required this.child});

//   String _normalize(String? r) {
//     final s = (r ?? '').trim().toLowerCase();
//     if (s == 'seller') return 'penjual';
//     return s;
//   }

//   Future<String?> _getRoleFallback() async {
//     final role = await AuthService.getRole();
//     if (role != null) return _normalize(role);

//     final prefs = await SharedPreferences.getInstance();
//     return _normalize(prefs.getString("level"));
//   }

//   bool _roleMatches(String? role, String required) {
//     final r = _normalize(role);
//     final req = _normalize(required);
//     return r == req;
//   }

//   void _safeRedirect(BuildContext context, String route) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!context.mounted) return;
//       Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<String?>(
//       future: _getRoleFallback(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState != ConnectionState.done) {
//           return const _RoleGuardLoading();
//         }

//         final role = snapshot.data;

//         if (role == null || role.trim().isEmpty) {
//           _safeRedirect(context, '/');
//           return const SizedBox.shrink();
//         }

//         if (!_roleMatches(role, requiredRole)) {
//           final r = _normalize(role);
//           if (r == 'penjual') {
//             _safeRedirect(context, '/seller');
//           } else if (r == 'admin') {
//             _safeRedirect(context, '/admin');
//           } else {
//             _safeRedirect(context, '/');
//           }
//           return const SizedBox.shrink();
//         }

//         return child;
//       },
//     );
//   }
// }

// class _RoleGuardLoading extends StatelessWidget {
//   const _RoleGuardLoading();

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;

//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [Color(0xFFF6F0FF), Color(0xFFFFF1F7)],
//           ),
//         ),
//         child: Center(
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(.78),
//               borderRadius: BorderRadius.circular(18),
//               border: Border.all(color: Colors.white.withOpacity(.35)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.06),
//                   blurRadius: 24,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 SizedBox(
//                   width: 22,
//                   height: 22,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2.6,
//                     color: cs.primary,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 const Text(
//                   'Memeriksa akses...',
//                   style: TextStyle(fontWeight: FontWeight.w700),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
