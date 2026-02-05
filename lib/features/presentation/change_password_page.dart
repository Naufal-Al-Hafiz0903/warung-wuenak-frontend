import 'package:flutter/material.dart';
import '../data/auth_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final emailC = TextEditingController();
  final oldC = TextEditingController();
  final newC = TextEditingController();
  final confirmC = TextEditingController();

  bool loading = false;
  bool obOld = true;
  bool obNew = true;
  bool obConfirm = true;

  void _snack(String msg, {Color? bg}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _prettyErr(Map<String, dynamic> res) {
    final msg = (res["message"] ?? "Gagal").toString();
    final sc = res["statusCode"];
    final url = res["url"];
    return [
      msg,
      if (sc != null) "HTTP: $sc",
      if (url != null) "URL: $url",
    ].where((e) => e.toString().trim().isNotEmpty).join("\n");
  }

  Future<void> submit() async {
    if (loading) return;

    final email = emailC.text.trim();
    final oldPass = oldC.text;
    final newPass = newC.text;
    final confirm = confirmC.text;

    if (email.isEmpty ||
        oldPass.isEmpty ||
        newPass.isEmpty ||
        confirm.isEmpty) {
      _snack("Semua field wajib diisi");
      return;
    }
    if (newPass.length < 6) {
      _snack("Password baru minimal 6 karakter");
      return;
    }
    if (newPass != confirm) {
      _snack("Konfirmasi password tidak sama");
      return;
    }
    if (newPass == oldPass) {
      _snack("Password baru tidak boleh sama dengan password lama");
      return;
    }

    setState(() => loading = true);

    final res = await AuthService.changePassword(
      email: email,
      oldPassword: oldPass,
      newPassword: newPass,
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (res["ok"] == true) {
      _snack("Password berhasil diubah ✅ Silakan login.", bg: Colors.green);
      Navigator.pop(context);
      return;
    }

    _snack(_prettyErr(res), bg: Colors.red);
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
  void dispose() {
    emailC.dispose();
    oldC.dispose();
    newC.dispose();
    confirmC.dispose();
    super.dispose();
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
                              Icons.password_rounded,
                              color: cs.primary,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          "Ganti Password",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Masukkan email, password lama, dan password baru",
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
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            label: "Email",
                            icon: Icons.mail_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: oldC,
                          obscureText: obOld,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            label: "Password Lama",
                            icon: Icons.lock_outline_rounded,
                            suffix: IconButton(
                              onPressed: () => setState(() => obOld = !obOld),
                              icon: Icon(
                                obOld
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: newC,
                          obscureText: obNew,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            label: "Password Baru",
                            icon: Icons.lock_reset_rounded,
                            suffix: IconButton(
                              onPressed: () => setState(() => obNew = !obNew),
                              icon: Icon(
                                obNew
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: confirmC,
                          obscureText: obConfirm,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => submit(),
                          decoration: _dec(
                            label: "Konfirmasi Password Baru",
                            icon: Icons.verified_user_outlined,
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => obConfirm = !obConfirm),
                              icon: Icon(
                                obConfirm
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
                            onPressed: loading ? null : submit,
                            child: loading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                    "Simpan Password Baru",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Kembali ke Login"),
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
