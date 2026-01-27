import 'package:flutter/material.dart';
import '../../../features/data/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameC = TextEditingController();
  final nomorC = TextEditingController();
  final alamatC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();

  bool loading = false;
  bool _obscure = true;

  // ✅ ROLE: tampil "Pembeli", tapi kirim "user"
  String _role = 'user'; // user|penjual

  bool _isEmailValid(String email) {
    final e = email.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(e);
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

  Future<void> doRegister() async {
    if (loading) return;

    final name = nameC.text.trim();
    final nomor = nomorC.text.trim();
    final alamat = alamatC.text.trim();
    final email = emailC.text.trim();
    final pass = passC.text; // password jangan di-trim

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      _snack("Nama, email, dan password wajib diisi");
      return;
    }

    if (!_isEmailValid(email)) {
      _snack("Email tidak valid");
      return;
    }

    setState(() => loading = true);

    try {
      final res = await AuthService.register(
        name: name,
        nomorUser: nomor,
        alamatUser: alamat,
        email: email,
        password: pass,
        level: _role, // ✅ kirim role pilihan user
      );

      if (!mounted) return;

      _snack(
        res["message"]?.toString() ?? "Register selesai",
        bg: res["ok"] == true ? Colors.green : null,
      );

      if (res["ok"] == true) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      _snack("Terjadi error: $e", bg: Colors.red);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    nomorC.dispose();
    alamatC.dispose();
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
      appBar: AppBar(title: const Text("Register")),
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
                          "Buat akun baru",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Lengkapi data di bawah untuk mendaftar.",
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ PILIH ROLE (Tampilan: Pembeli/Penjual)
                        DropdownButtonFormField<String>(
                          value: _role,
                          decoration: _dec(
                            label: "Daftar sebagai",
                            icon: Icons.badge_outlined,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text("Pembeli"),
                            ),
                            DropdownMenuItem(
                              value: 'penjual',
                              child: Text("Penjual"),
                            ),
                          ],
                          onChanged: loading
                              ? null
                              : (v) => setState(() => _role = v ?? 'user'),
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: nameC,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            label: "Nama",
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nomorC,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.phone,
                          decoration: _dec(
                            label: "Nomor User",
                            icon: Icons.phone_iphone_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: alamatC,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            label: "Alamat",
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          controller: passC,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => doRegister(),
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
                            onPressed: loading ? null : doRegister,
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
                                      const Text("Mendaftarkan..."),
                                    ],
                                  )
                                : const Text(
                                    "Register",
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
                          child: const Text("Sudah punya akun? Login"),
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
