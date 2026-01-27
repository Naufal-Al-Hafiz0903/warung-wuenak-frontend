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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 44),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Coba lagi"),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (_) => false,
                    );
                  },
                  child: const Text("Ke Login"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CourierShellPage(user: _me!.toJson());
  }
}
