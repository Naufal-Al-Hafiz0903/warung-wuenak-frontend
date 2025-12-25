import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';
import 'register_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailC = TextEditingController();
  final TextEditingController passC = TextEditingController();

  bool loading = false;

  Future<void> doLogin() async {
    if (emailC.text.isEmpty || passC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan password wajib diisi")),
      );
      return;
    }

    setState(() => loading = true);

    // =============================
    // LOGIN
    // =============================
    final res = await Api.login(
      email: emailC.text.trim(),
      password: passC.text,
    );

    setState(() => loading = false);

    if (!mounted) return;

    if (res["ok"] == true && res["token"] != null) {
      final String token = res["token"].toString();

      // =============================
      // DEBUG: CETAK JWT
      // =============================
      debugPrint("========== JWT TOKEN ==========");
      debugPrint(token);
      debugPrint("================================");

      // =============================
      // CEK APAKAH TOKEN JWT (ADA . .)
      // =============================
      final bool isJwt = token.split('.').length == 3;

      // =============================
      // VALIDASI JWT KE BACKEND
      // =============================
      final check = await Api.checkToken(token);

      debugPrint("====== JWT CHECK RESULT ======");
      debugPrint(check.toString());
      debugPrint("==============================");

      if (check["ok"] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Login berhasil, tapi JWT TIDAK VALID: ${check["message"]}",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // =============================
      // SIMPAN KE SHARED PREFERENCES
      // =============================
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", token);
      await prefs.setString("email", res["data"]["email"] ?? "");
      await prefs.setString("name", res["data"]["name"] ?? "");
      await prefs.setString("level", res["data"]["level"] ?? "user");

      // =============================
      // INFO KE USER
      // =============================
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isJwt
                ? "Login berhasil & JWT VALID ✅"
                : "Login berhasil tapi token BUKAN JWT ❌",
          ),
          backgroundColor: isJwt ? Colors.green : Colors.orange,
        ),
      );

      // =============================
      // MASUK KE HOME
      // =============================
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(user: res["data"])),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res["message"] ?? "Login gagal")));
    }
  }

  @override
  void dispose() {
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock, size: 80),
                const SizedBox(height: 20),
                const Text(
                  "Login",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: emailC,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passC,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading ? null : doLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    loading ? "Loading..." : "Login",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
                  child: const Text("Belum punya akun? Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
