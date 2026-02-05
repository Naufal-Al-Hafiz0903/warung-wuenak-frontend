import 'package:flutter/material.dart';

import '../../../models/category_model.dart';
import '../../../services/category_service.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  bool _loading = true;
  String? _error;
  List<CategoryModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _load(force: true);
  }

  bool _isDuplicateRes(Map<String, dynamic> res) {
    final detail = (res['detail'] ?? '').toString();
    final status = (res['status'] ?? res['statusCode'] ?? 0);
    return detail == 'CATEGORY_EXISTS' || status == 409;
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await CategoryService.fetchCategoriesAdmin(
        forceRefresh: force,
      );

      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat kategori: $e';
      });
    }
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
                // ✅ admin create (ambil response lengkap)
                final res = await CategoryService.createResult(
                  name: name,
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

  Future<void> _delete(int categoryId) async {
    final ok = await CategoryService.delete(categoryId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Kategori dihapus' : 'Gagal hapus kategori')),
    );

    if (ok) await _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: ini tampil di dalam AdminLayout (sudah ada Scaffold),
    // jadi di sini cukup return widget konten saja (tanpa Scaffold baru).
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: _openAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _load(force: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 44),
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
          else if (_items.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Kategori kosong'),
                subtitle: Text('Endpoint: GET /categories'),
              ),
            )
          else
            ..._items.map((c) {
              final desc = (c.description ?? '').trim();
              return Card(
                child: ListTile(
                  title: Text(
                    c.categoryName.isEmpty
                        ? 'Kategori #${c.categoryId}'
                        : c.categoryName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    desc.isEmpty
                        ? 'ID: ${c.categoryId}'
                        : 'ID: ${c.categoryId}\n$desc',
                  ),
                  isThreeLine: desc.isNotEmpty,
                  trailing: IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(c.categoryId),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
