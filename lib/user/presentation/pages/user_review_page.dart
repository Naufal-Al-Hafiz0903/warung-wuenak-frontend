// pages/user_review_page.dart
import 'dart:convert';
import '../../../core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserReviewPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final int productId;
  final String? productName;

  const UserReviewPage({
    super.key,
    required this.user,
    required this.productId,
    this.productName,
  });

  @override
  State<UserReviewPage> createState() => _UserReviewPageState();
}

class _UserReviewPageState extends State<UserReviewPage> {
  static const String _baseUrl = AppConfig.baseUrl;

  bool _loading = true;
  bool _busy = false;

  int _rating = 5;
  final _komentar = TextEditingController();

  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _my;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _komentar.dispose();
    super.dispose();
  }

  Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('token');
  }

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tok = await _token();
      if (tok == null || tok.isEmpty) {
        _snack('Token tidak ditemukan, silakan login ulang');
        return;
      }

      // list review produk
      final r = await http.get(
        Uri.parse('$_baseUrl/reviews/product/${widget.productId}'),
        headers: _headers(tok),
      );
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final j = jsonDecode(r.body);
        final data = (j is Map && j['data'] is List)
            ? (j['data'] as List)
            : <dynamic>[];
        _reviews = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      // my review
      final m = await http.get(
        Uri.parse('$_baseUrl/reviews/my?product_id=${widget.productId}'),
        headers: _headers(tok),
      );
      if (m.statusCode >= 200 && m.statusCode < 300) {
        final j = jsonDecode(m.body);
        final data = (j is Map && j['data'] is Map) ? (j['data'] as Map) : null;
        if (data != null) {
          _my = Map<String, dynamic>.from(data);
          _rating = int.tryParse('${_my?['rating'] ?? 5}') ?? 5;
          _komentar.text = (_my?['komentar'] ?? '').toString();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final tok = await _token();
    if (tok == null || tok.isEmpty) {
      _snack('Token tidak ditemukan, silakan login ulang');
      return;
    }

    if (_rating < 1 || _rating > 5) {
      _snack('Rating harus 1..5');
      return;
    }

    setState(() => _busy = true);
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/reviews/create'),
        headers: _headers(tok),
        body: jsonEncode({
          'product_id': widget.productId,
          'rating': _rating,
          'komentar': _komentar.text.trim(),
        }),
      );

      if (r.statusCode >= 200 && r.statusCode < 300) {
        _snack('Ulasan tersimpan');
        await _load();
        return;
      }

      String msg = 'Gagal menyimpan ulasan';
      try {
        final j = jsonDecode(r.body);
        if (j is Map && j['message'] != null) msg = '${j['message']}';
      } catch (_) {}
      _snack(msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: const Text('Ulasan'),
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D28D9), Color(0xFF9333EA), Color(0xFFA855F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.productName ?? 'Produk',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Rating',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: List.generate(5, (i) {
                          final v = i + 1;
                          final active = _rating == v;
                          return InkWell(
                            onTap: _busy
                                ? null
                                : () => setState(() => _rating = v),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFF6D28D9)
                                    : const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: active
                                      ? const Color(0xFF6D28D9)
                                      : const Color(0xFFE9D5FF),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 18,
                                    color: active
                                        ? Colors.white
                                        : const Color(0xFF6D28D9),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$v',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: active
                                          ? Colors.white
                                          : const Color(0xFF6D28D9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Komentar',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _komentar,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tulis ulasan kamu...',
                          filled: true,
                          fillColor: const Color(0xFFF5F3FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE9D5FF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D28D9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            _my == null ? 'Kirim Ulasan' : 'Update Ulasan',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ulasan Lainnya',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      if (_reviews.isEmpty)
                        const Text('Belum ada ulasan.')
                      else
                        Column(
                          children: _reviews.map((e) {
                            final name = (e['name'] ?? e['pembeli'] ?? 'User')
                                .toString();
                            final rt = int.tryParse('${e['rating'] ?? 0}') ?? 0;
                            final km = (e['komentar'] ?? '').toString();
                            final ct = (e['created_at'] ?? '').toString();

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFEDE9FE)),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ct,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: List.generate(5, (i) {
                                      final filled = (i + 1) <= rt;
                                      return Icon(
                                        Icons.star,
                                        size: 16,
                                        color: filled
                                            ? const Color(0xFF6D28D9)
                                            : const Color(0xFFD1D5DB),
                                      );
                                    }),
                                  ),
                                  if (km.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      km,
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDE9FE)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: child,
    );
  }
}
