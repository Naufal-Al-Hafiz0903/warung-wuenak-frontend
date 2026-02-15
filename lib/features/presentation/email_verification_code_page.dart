import 'package:flutter/material.dart';
import '../data/email_verification_service.dart';
import '../data/auth_service.dart';

class EmailVerificationCodePage extends StatefulWidget {
  const EmailVerificationCodePage({super.key});

  @override
  State<EmailVerificationCodePage> createState() =>
      _EmailVerificationCodePageState();
}

class _EmailVerificationCodePageState extends State<EmailVerificationCodePage> {
  final _codeC = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _svc = EmailVerificationService();
  bool _loading = false;

  @override
  void dispose() {
    _codeC.dispose();
    super.dispose();
  }

  String _getEmailArg() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['email'] is String) {
      return (args['email'] as String).trim();
    }
    return '';
  }

  String? _validateCode(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Kode wajib diisi';
    if (s.length != 6) return 'Kode harus 6 karakter';
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

  Future<void> _afterVerifiedNavigate() async {
    await AuthService.setEmailVerified(true);

    final token = await AuthService.getToken();
    final role = await AuthService.getRole();

    if (!mounted) return;

    if (token != null && token.trim().isNotEmpty && role != null) {
      if (role == 'penjual') {
        Navigator.pushNamedAndRemoveUntil(context, '/seller', (_) => false);
      } else if (role == 'admin') {
        Navigator.pushNamedAndRemoveUntil(context, '/admin', (_) => false);
      } else if (role == 'kurir') {
        Navigator.pushNamedAndRemoveUntil(context, '/courier', (_) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/user', (_) => false);
      }
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _getEmailArg();
    if (email.isEmpty) {
      _snack('Email tidak ditemukan dari halaman sebelumnya', bg: Colors.red);
      return;
    }

    final code = _codeC.text.trim();

    setState(() => _loading = true);
    try {
      await _svc.verifyCode(email: email, code: code);

      if (!mounted) return;
      _snack('Email berhasil diverifikasi', bg: Colors.green);

      await _afterVerifiedNavigate();
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

  Future<void> _resend() async {
    final email = _getEmailArg();
    if (email.isEmpty) return;

    setState(() => _loading = true);
    try {
      await _svc.sendCode(email: email);
      if (!mounted) return;
      _snack('Kode baru sudah dikirim', bg: Colors.orange);
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
    final email = _getEmailArg();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Masukkan Kode')),
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
                          'Verifikasi email',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          email.isEmpty
                              ? 'Email tidak terbaca.'
                              : 'Kode dikirim ke: $email',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            controller: _codeC,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Kode Verifikasi (6 karakter)',
                              hintText: 'Masukkan kode',
                              counterText: '',
                            ),
                            enabled: !_loading,
                            validator: _validateCode,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _verify,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Verifikasi'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: _loading ? null : _resend,
                            child: const Text('Kirim ulang kode'),
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
