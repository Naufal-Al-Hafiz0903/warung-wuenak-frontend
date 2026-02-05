import 'dart:async';
import 'package:flutter/material.dart';

import '../../../services/category_repository.dart';
import '../layout/seller_layout.dart';

class SellerCategoriesPage extends StatefulWidget {
  const SellerCategoriesPage({super.key});

  @override
  State<SellerCategoriesPage> createState() => _SellerCategoriesPageState();
}

class _SellerCategoriesPageState extends State<SellerCategoriesPage> {
  bool _loading = true;
  String? _error;

  final _searchC = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _all = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _filtered = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();

    final cached = CategoryRepository.getCached();
    if (cached.isNotEmpty) {
      _all = cached;
      _filtered = List<Map<String, dynamic>>.from(cached);
      _loading = false;
    }

    _load(force: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  int _toInt(dynamic v, [int def = 0]) {
    if (v == null) return def;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? def;
  }

  String _str(dynamic v) => (v == null) ? '' : '$v';

  void _applyFilter(String q) {
    final qq = q.trim().toLowerCase();
    if (qq.isEmpty) {
      setState(() => _filtered = List<Map<String, dynamic>>.from(_all));
      return;
    }

    final out = _all.where((x) {
      final name = _str(x['category_name']).toLowerCase();
      final desc = _str(x['description']).toLowerCase();
      final id = _str(x['category_id']).toLowerCase();
      return name.contains(qq) || desc.contains(qq) || id.contains(qq);
    }).toList();

    setState(() => _filtered = out);
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _applyFilter(v);
    });
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await CategoryRepository.list(force: force);

      if (!mounted) return;
      setState(() {
        _all = list;
        _filtered = List<Map<String, dynamic>>.from(list);
        _loading = false;
        _error = null;
      });

      final q = _searchC.text;
      if (q.trim().isNotEmpty) _applyFilter(q);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat kategori: $e';
      });
    }
  }

  bool _isDuplicateRes(Map<String, dynamic> res) {
    final detail = (res['detail'] ?? '').toString();
    final status = (res['status'] ?? res['statusCode'] ?? 0);
    return detail == 'CATEGORY_EXISTS' || status == 409;
  }

  Future<void> _openAddDialog() async {
    final nameC = TextEditingController();
    final descC = TextEditingController();

    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> submit() async {
              if (saving) return;

              final name = nameC.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama kategori wajib diisi')),
                );
                return;
              }

              setStateDialog(() => saving = true);

              try {
                final res = await CategoryRepository.create(
                  categoryName: name,
                  description: descC.text.trim(),
                );

                if (!mounted) return;

                final ok = res['ok'] == true;

                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kategori ditambahkan')),
                  );
                  Navigator.pop(ctx);
                  await _load(force: true);
                  return;
                }

                if (_isDuplicateRes(res)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Kategori sudah ada. Huruf besar/kecil dianggap sama.',
                      ),
                    ),
                  );
                  return;
                }

                final msg = (res['message'] ?? 'Gagal menambah kategori')
                    .toString();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(msg)));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal tambah kategori: $e')),
                );
              } finally {
                if (ctx.mounted) setStateDialog(() => saving = false);
              }
            }

            return AlertDialog(
              title: const Text('Tambah Kategori'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'Nama Kategori',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descC,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi (opsional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: Text(saving ? 'Menyimpan...' : 'Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchC,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Cari kategori (nama / id)...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(.78),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : () => _load(force: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Tambah kategori',
          onPressed: _openAddDialog,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Column(
        children: const [
          Icon(Icons.category_outlined, size: 46, color: Colors.black38),
          SizedBox(height: 10),
          Text(
            'Belum ada kategori',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Tekan tombol + untuk menambah kategori.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_filtered.isEmpty) return _emptyState();

    return ListView.separated(
      itemCount: _filtered.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = _filtered[i];
        final id = _toInt(c['category_id']);
        final name = _str(c['category_name']).trim();
        final desc = _str(c['description']).trim();

        return Container(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: Color(0xFF6D28D9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Kategori #$id' : name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Pill(text: 'ID: $id'),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(desc, style: const TextStyle(color: Colors.black54)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SellerLayout(
      title: 'Kategori',
      child: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _toolbar(),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(26),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFEDE9FE)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _load(force: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
            else
              _list(),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEDE9FE)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}
