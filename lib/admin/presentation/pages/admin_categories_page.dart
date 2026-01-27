import 'package:flutter/material.dart';
import '/models/category_model.dart';
import '/services/category_service.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  late Future<List<CategoryModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = CategoryService.fetchCategoriesAdmin();
  }

  Future<void> _refresh({bool forceRefresh = false}) async {
    setState(() {
      _future = CategoryService.fetchCategoriesAdmin(
        forceRefresh: forceRefresh,
      );
    });
    // biar RefreshIndicator (kalau dipakai) nunggu selesai
    await _future;
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Kategori'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Deskripsi'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await CategoryService.create(
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
              );
              if (context.mounted) Navigator.pop(context, ok);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kategori ditambah')));
      await _refresh(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: ListTile(
                  title: const Text('Gagal memuat kategori'),
                  subtitle: Text('${snap.error}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _refresh(forceRefresh: true),
                  ),
                ),
              ),
            ),
          );
        }

        final items = snap.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _refresh(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('Kategori kosong / endpoint belum sesuai'),
                  subtitle: Text('Endpoint: GET /categories'),
                ),
              )
            else
              ...items.map(
                (c) => Card(
                  child: ListTile(
                    title: Text(c.categoryName),
                    subtitle: Text(
                      'ID: ${c.categoryId} | Parent: ${c.parentId ?? "-"}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        final ok = await CategoryService.delete(c.categoryId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Dihapus' : 'Gagal hapus'),
                          ),
                        );
                        if (ok) await _refresh(forceRefresh: true);
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
