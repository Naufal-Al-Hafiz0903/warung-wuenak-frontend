import 'dart:async';
import 'package:flutter/material.dart';
import '../data/email_verification_service.dart';

class EmailVerificationRequestPage extends StatefulWidget {
  const EmailVerificationRequestPage({super.key});

  @override
  State<EmailVerificationRequestPage> createState() =>
      _EmailVerificationRequestPageState();
}

class _EmailVerificationRequestPageState
    extends State<EmailVerificationRequestPage> {
  final _emailC = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _svc = EmailVerificationService();

  bool _loading = false;
  int _cooldownSec = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailC.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['email'] is String) {
      final email = (args['email'] as String).trim();
      if (_emailC.text.trim().isEmpty && email.isNotEmpty) {
        _emailC.text = email;
      }
    }
    super.didChangeDependencies();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSec = seconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldownSec <= 1) {
        t.cancel();
        setState(() => _cooldownSec = 0);
      } else {
        setState(() => _cooldownSec -= 1);
      }
    });
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email wajib diisi';
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
    if (!ok) return 'Format email tidak valid';
    return null;
  }

  void _snack(String msg, {Color? bg}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailC.text.trim();

    setState(() => _loading = true);
    try {
      await _svc.sendCode(email: email);
      if (!mounted) return;

      _startCooldown(60);
      _snack('Kode verifikasi berhasil dikirim', bg: Colors.green);

      Navigator.pushNamed(
        context,
        '/verify-email/code',
        arguments: {'email': email},
      );
    } on EmailVerificationException catch (e) {
      if (!mounted) return;
      _snack(e.message, bg: Colors.red);
    } catch (e) {
      if (!mounted) return;
      _snack('Terjadi kesalahan: $e', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Email')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6F0FF), Color(0xFFFFF1F7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.82),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(.35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.08),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Kirim kode verifikasi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Masukkan email yang terdaftar. Sistem akan mengirim kode 6 karakter.',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            controller: _emailC,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'contoh@email.com',
                            ),
                            validator: _validateEmail,
                            enabled: !_loading,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_loading || _cooldownSec > 0)
                                ? null
                                : _send,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _cooldownSec > 0
                                        ? 'Tunggu $_cooldownSec dtk'
                                        : 'Kirim Kode',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
