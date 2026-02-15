import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../features/data/auth_service.dart';
import '../../features/data/email_verification_service.dart';
import 'register_page.dart';

import 'package:warung_wuenak/services/me_location_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailC = TextEditingController();
  final TextEditingController passC = TextEditingController();

  bool loading = false;
  bool _obscure = true;

  String _prettyErr(Map<String, dynamic> res) {
    final msg = (res["message"] ?? "Login gagal").toString();
    final sc = res["statusCode"];
    final url = res["url"];
    final ct = res["contentType"];
    final preview = res["rawPreview"];

    if (msg.contains("HTML")) {
      return [
        msg,
        if (sc != null) "HTTP: $sc",
        if (url != null) "URL: $url",
        if (ct != null) "CT: $ct",
        if (preview != null) "Preview: $preview",
      ].where((e) => e.toString().trim().isNotEmpty).join("\n");
    }

    if (sc != null || url != null) {
      return [
        msg,
        if (sc != null) "HTTP: $sc",
        if (url != null) "URL: $url",
      ].where((e) => e.toString().trim().isNotEmpty).join("\n");
    }

    return msg;
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

  bool _toBool(dynamic v, {bool defaultValue = true}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
    return defaultValue;
  }

  Future<void> _captureLocationAfterLogin() async {
    try {
      final r = await MeLocationService.captureAndSend();
      if (!mounted) return;

      if (r.ok) {
        final c = (r.city ?? '').trim();
        final area = r.areaKm2;
        final radius = r.radiusMMax;

        if (c.isNotEmpty && area != null && radius != null) {
          final km = (radius / 1000).toStringAsFixed(1);
          _snack(
            'Lokasi: $c | Luas± ${area.toStringAsFixed(2)} km² | Radius max: $km km',
            bg: Colors.green,
          );
        } else if (c.isNotEmpty) {
          _snack('Lokasi terdeteksi: $c', bg: Colors.green);
        } else {
          _snack(
            'Koordinat tersimpan, kota tidak terdeteksi',
            bg: Colors.orange,
          );
        }
      } else {
        _snack('Gagal simpan lokasi: ${r.message}', bg: Colors.orange);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Lokasi tidak bisa diambil: $e', bg: Colors.orange);
    }
  }

  Future<void> _redirectByRole(String level) async {
    if (level == "penjual") {
      Navigator.pushNamedAndRemoveUntil(context, '/seller', (_) => false);
    } else if (level == "admin") {
      Navigator.pushNamedAndRemoveUntil(context, '/admin', (_) => false);
    } else if (level == "kurir") {
      Navigator.pushNamedAndRemoveUntil(context, '/courier', (_) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/user', (_) => false);
    }
  }

  Future<void> _handleUnverifiedEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) {
      _snack(
        'Email belum terverifikasi. Silakan verifikasi email.',
        bg: Colors.orange,
      );
      Navigator.pushNamed(context, '/verify-email');
      return;
    }

    _snack(
      'Email belum terverifikasi. Mengirim kode verifikasi...',
      bg: Colors.orange,
    );

    try {
      final svc = EmailVerificationService();
      await svc.sendCode(email: e);

      if (!mounted) return;
      _snack(
        'Kode verifikasi sudah dikirim. Masukkan kode.',
        bg: Colors.orange,
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/verify-email/code',
        (_) => false,
        arguments: {'email': e},
      );
    } on EmailVerificationException catch (ex) {
      if (!mounted) return;
      _snack('Gagal kirim kode verifikasi: ${ex.message}', bg: Colors.red);

      Navigator.pushNamed(context, '/verify-email', arguments: {'email': e});
    } catch (ex) {
      if (!mounted) return;
      _snack('Gagal kirim kode verifikasi: $ex', bg: Colors.red);

      Navigator.pushNamed(context, '/verify-email', arguments: {'email': e});
    }
  }

  Future<void> doLogin() async {
    if (loading) return;

    final emailInputRaw = emailC.text.trim();
    final emailInput = emailInputRaw.toLowerCase();
    final pass = passC.text;

    if (emailInput.isEmpty || pass.isEmpty) {
      _snack("Email dan password wajib diisi");
      return;
    }

    setState(() => loading = true);

    final res = await AuthService.login(emailInput, pass);

    if (!mounted) return;
    setState(() => loading = false);

    if (res["ok"] == true && res["token"] != null) {
      final String token = res["token"].toString();
      final bool isJwt = token.split('.').length == 3;

      final check = await Api.checkToken(token);
      if (!mounted) return;

      if (check["ok"] != true) {
        final msg = (check["message"] ?? "").toString().toLowerCase();
        if (msg.contains("email belum diverifikasi")) {
          await _handleUnverifiedEmail(emailInput);
          return;
        }

        _snack(
          "Login berhasil, tapi JWT tidak valid:\n${_prettyErr(check)}",
          bg: Colors.red,
        );
        return;
      }

      final data = (res["data"] is Map<String, dynamic>)
          ? (res["data"] as Map<String, dynamic>)
          : <String, dynamic>{};

      final String level = (data["level"] ?? "user").toString();
      final String email = (data["email"] ?? emailInput)
          .toString()
          .trim()
          .toLowerCase();

      final bool emailVerified = _toBool(
        data["email_verified"] ?? data["emailVerified"],
        defaultValue: true,
      );

      _snack(
        isJwt
            ? "Login berhasil & token valid"
            : "Login berhasil tapi token bukan JWT",
        bg: isJwt ? Colors.green : Colors.orange,
      );

      if (!emailVerified) {
        await _handleUnverifiedEmail(email);
        return;
      }

      await _captureLocationAfterLogin();
      if (!mounted) return;

      await _redirectByRole(level);
      return;
    }

    final msg = (res["message"] ?? "").toString().toLowerCase();
    if (msg.contains("email belum diverifikasi")) {
      await _handleUnverifiedEmail(emailInput);
      return;
    }

    _snack(_prettyErr(res));
  }

  @override
  void dispose() {
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }

  InputDecoration _dec({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
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
              constraints: const BoxConstraints(maxWidth: 440),
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
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.lock_rounded,
                                color: cs.primary,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "Warung Wuenak",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Masuk untuk melanjutkan",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: emailC,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: _dec(
                              label: "Email",
                              icon: Icons.mail_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passC,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => doLogin(),
                            decoration: _dec(
                              label: "Password",
                              icon: Icons.lock_outline_rounded,
                              suffix: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: loading ? null : doLogin,
                              child: loading
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: cs.onPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text("Memproses..."),
                                      ],
                                    )
                                  : const Text(
                                      "Login",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Belum punya akun? Register",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/change-password',
                            ),
                            child: const Text('Ganti Password'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/verify-email'),
                            child: const Text('Verifikasi Email'),
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
      ),
    );
  }
}
