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

  static const levels = ['admin', 'penjual', 'user'];
  static const statuses = ['aktif', 'nonaktif'];

  @override
  void initState() {
    super.initState();
    _future = UserService.fetchUsers();
  }

  Future<void> _refresh() async {
    setState(() => _future = UserService.fetchUsers());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final users = snap.data!;
        if (users.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: const [
                SizedBox(height: 140),
                Center(
                  child: Text('Data users kosong / endpoint belum sesuai'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Nama')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Level')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Saldo')),
                    ],
                    rows: users.map((u) {
                      final levelVal = levels.contains(u.level)
                          ? u.level
                          : 'user';
                      final statusVal = statuses.contains(u.status)
                          ? u.status
                          : 'aktif';

                      return DataRow(
                        cells: [
                          DataCell(Text(u.userId.toString())),
                          DataCell(Text(u.name)),
                          DataCell(Text(u.email)),
                          DataCell(
                            DropdownButton<String>(
                              value: levelVal,
                              items: levels
                                  .map(
                                    (x) => DropdownMenuItem(
                                      value: x,
                                      child: Text(x),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) async {
                                if (v == null) return;
                                final ok = await UserService.changeLevel(
                                  userId: u.userId,
                                  level: v,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok ? 'Level diubah' : 'Gagal ubah level',
                                    ),
                                  ),
                                );
                                if (ok) _refresh();
                              },
                            ),
                          ),
                          DataCell(
                            DropdownButton<String>(
                              value: statusVal,
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
                          DataCell(Text(u.saldo.toString())),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
