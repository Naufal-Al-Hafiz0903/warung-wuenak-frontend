import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late Future<List<UserModel>> _future;

  final TextEditingController _searchC = TextEditingController();

  // filter status ala tombol bulat merah: semua / aktif / nonaktif
  String _statusFilter = 'semua';

  static const statuses = ['aktif', 'nonaktif'];

  @override
  void initState() {
    super.initState();
    _future = UserService.fetchUsers();

    _searchC.addListener(() {
      // supaya realtime search
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = UserService.fetchUsers());
  }

  /// REVISI:
  /// - Admin tidak ditampilkan (hanya penjual & user)
  /// - Status filter tetap bekerja (semua menampilkan aktif+nonaktif)
  /// - Nonaktif tidak dihilangkan dari list "Semua", agar bisa diaktifkan lagi
  List<UserModel> _applyFilter(List<UserModel> users) {
    final q = _searchC.text.trim().toLowerCase();

    Iterable<UserModel> list = users;

    // 1) HANYA tampilkan PENJUAL & USER (admin tidak tampil)
    list = list.where((u) => u.level.toLowerCase() != 'admin');

    // 2) filter status (semua = tidak filter, tampilkan aktif+nonaktif)
    if (_statusFilter != 'semua') {
      list = list.where((u) => u.status.toLowerCase() == _statusFilter);
    }

    // 3) search name/email/id
    if (q.isNotEmpty) {
      list = list.where((u) {
        final id = u.userId.toString();
        final name = u.name.toLowerCase();
        final email = u.email.toLowerCase();
        return id.contains(q) || name.contains(q) || email.contains(q);
      });
    }

    return list.toList();
  }

  void _openStatusMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Semua'),
                trailing: _statusFilter == 'semua'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, 'semua'),
              ),
              ListTile(
                title: const Text('Aktif'),
                trailing: _statusFilter == 'aktif'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, 'aktif'),
              ),
              ListTile(
                title: const Text('Nonaktif'),
                trailing: _statusFilter == 'nonaktif'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, 'nonaktif'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() => _statusFilter = selected);
    }
  }

  // =========================
  // WIDGET TABEL CUSTOM (agar kolom Status selalu terlihat)
  // =========================

  Widget _headerCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _bodyCell(
    Widget child, {
    int flex = 1,
    Alignment align = Alignment.centerLeft,
  }) {
    return Expanded(
      flex: flex,
      child: Align(alignment: align, child: child),
    );
  }

  Widget _table(List<UserModel> list) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _headerCell('Id', flex: 1),
                  const SizedBox(width: 8),
                  _headerCell('Nama', flex: 2),
                  const SizedBox(width: 8),
                  _headerCell('Email', flex: 3),
                  const SizedBox(width: 8),
                  _headerCell('Status', flex: 2),
                ],
              ),
            ),
            const Divider(height: 1),

            // ROWS
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tidak ada data yang cocok dengan filter/search.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              ...list.map((u) {
                final statusVal = statuses.contains(u.status.toLowerCase())
                    ? u.status.toLowerCase()
                    : 'aktif';

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          _bodyCell(Text(u.userId.toString()), flex: 1),
                          const SizedBox(width: 8),

                          _bodyCell(
                            Text(u.name, overflow: TextOverflow.ellipsis),
                            flex: 2,
                          ),
                          const SizedBox(width: 8),

                          _bodyCell(
                            Text(u.email, overflow: TextOverflow.ellipsis),
                            flex: 3,
                          ),
                          const SizedBox(width: 8),

                          // STATUS DROPDOWN (selalu tampil & bisa diubah)
                          _bodyCell(
                            SizedBox(
                              height: 40,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: statusVal,
                                  isExpanded: true,
                                  items: statuses
                                      .map(
                                        (x) => DropdownMenuItem(
                                          value: x,
                                          child: Text(x),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) async {
                                    if (v == null) return;

                                    final ok = await UserService.updateStatus(
                                      userId: u.userId,
                                      status: v,
                                    );

                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok
                                              ? 'Status diubah'
                                              : 'Gagal ubah status',
                                        ),
                                      ),
                                    );

                                    if (ok) _refresh();
                                  },
                                ),
                              ),
                            ),
                            flex: 2,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snap.data ?? [];
        final filtered = _applyFilter(users);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // =========================
              // SEARCH + TOMBOL BULAT MERAH (FILTER STATUS)
              // =========================
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchC,
                        decoration: InputDecoration(
                          hintText: "Search",
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _openStatusMenu(context),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_statusFilter == 'semua')
                            ? Colors.redAccent
                            : Colors.red,
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // INFO kecil
              Text(
                "Filter: ${_statusFilter.toUpperCase()} • Data: ${filtered.length}",
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),

              // =========================
              // TABEL USERS (Id | Nama | Email | Status)
              // Admin TIDAK ditampilkan (sudah difilter di _applyFilter)
              // =========================
              _table(filtered),
            ],
          ),
        );
      },
    );
  }
}
