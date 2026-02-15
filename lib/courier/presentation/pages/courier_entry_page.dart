import 'package:flutter/material.dart';

import '../../../user/data/me_service.dart';
import '../../../models/user_model.dart';
import 'courier_shell_page.dart';

class CourierEntryPage extends StatefulWidget {
  const CourierEntryPage({super.key});

  @override
  State<CourierEntryPage> createState() => _CourierEntryPageState();
}

class _CourierEntryPageState extends State<CourierEntryPage> {
  bool _loading = true;
  String? _error;
  UserModel? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = await MeService.fetchMe();
      if (me == null) {
        setState(() => _error = 'Session tidak valid. Silakan login ulang.');
      } else {
        final level = (me.toJson()['level'] ?? 'user').toString().toLowerCase();
        if (level != 'kurir') {
          // safety: kalau token bukan kurir, lempar ke route yang tepat
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              level == 'admin'
                  ? '/admin'
                  : (level == 'penjual' || level == 'seller')
                  ? '/seller'
                  : '/user',
              (_) => false,
            );
          });
        } else {
          setState(() => _me = me);
        }
      }
    } catch (e) {
      setState(() => _error = 'Gagal memuat kurir: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Wrapper UI seragam untuk kurir (gradient + card)
    Widget wrap(Widget child) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D5EF6), Color(0xFFB66AF7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return wrap(
        const _GlassCard(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
                SizedBox(width: 12),
                Text(
                  'Menyiapkan dashboard kurir...',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return wrap(
        _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 44, color: Colors.black87),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Coba lagi"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (_) => false,
                          );
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text("Ke Login"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ Masuk ke dashboard kurir
    return CourierShellPage(user: _me!.toJson());
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }
}
