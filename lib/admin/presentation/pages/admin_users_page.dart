import 'package:flutter/material.dart';
import '/models/user_model.dart';
import '../../../seller/data/user_service.dart';
import '../widgets/admin_add_dialog.dart';
import '../widgets/admin_db_table.dart';
import '../widgets/admin_ui.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late Future<List<UserModel>> _future;

  final TextEditingController _searchC = TextEditingController();
  String _statusFilter = 'semua';

  static const statuses = ['aktif', 'nonaktif'];
  static const addLevels = ['user', 'penjual'];

  @override
  void initState() {
    super.initState();
    _future = UserService.fetchUsers();
    _searchC.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = UserService.fetchUsers());
  }

  Map<String, dynamic> _userToMap(UserModel u) {
    try {
      final v = (u as dynamic).toJson();
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _pickStr(
    Map<String, dynamic> m,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  String _pickSaldoText(Map<String, dynamic> m) {
    final v = m['saldo'];
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(0);
    final s = v.toString().trim();
    if (s.isEmpty) return '0';
    final n = num.tryParse(s);
    if (n != null) return n.toStringAsFixed(0);
    return s;
  }

  String _norm(String s) => s.trim().toLowerCase();

  String _getNomor(UserModel u) {
    final s = (u.nomorUser ?? '').trim();
    if (s.isNotEmpty) return s;
    final m = _userToMap(u);
    return _pickStr(m, const ['nomor_user', 'nomorUser']);
  }

  String _getAlamat(UserModel u) {
    final s = (u.alamatUser ?? '').trim();
    if (s.isNotEmpty) return s;
    final m = _userToMap(u);
    return _pickStr(m, const ['alamat_user', 'alamatUser']);
  }

  List<UserModel> _applyFilter(List<UserModel> users) {
    final q = _searchC.text.trim().toLowerCase();
    Iterable<UserModel> list = users;

    list = list.where((u) => _norm(u.level) != 'admin');

    if (_statusFilter != 'semua') {
      list = list.where((u) => _norm(u.status) == _statusFilter);
    }

    if (q.isNotEmpty) {
      list = list.where((u) {
        final id = u.userId.toString().toLowerCase();
        final name = u.name.toLowerCase();
        final email = u.email.toLowerCase();
        final level = u.level.toLowerCase();
        final nomor = _getNomor(u).toLowerCase();
        final alamat = _getAlamat(u).toLowerCase();

        return id.contains(q) ||
            name.contains(q) ||
            email.contains(q) ||
            nomor.contains(q) ||
            alamat.contains(q) ||
            level.contains(q);
      });
    }

    return list.toList();
  }

  void _openStatusMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
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
      ),
    );

    if (selected != null) setState(() => _statusFilter = selected);
  }

  Future<void> _openAddDialog() async {
    final res = await showDialog<AdminDialogResult>(
      context: context,
      builder: (_) => AdminEntityAddDialog(
        schema: AdminDialogSchema(
          title: 'Tambah User / Penjual',
          submitLabel: 'Tambah',
          fields: [
            AdminFieldSpec.text('name', label: 'Nama', required: true),
            AdminFieldSpec.text(
              'email',
              label: 'Email',
              required: true,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                if (!s.contains('@')) return 'Format email tidak valid';
                return null;
              },
            ),
            AdminFieldSpec.password(
              'password',
              label: 'Password',
              required: true,
            ),
            AdminFieldSpec.text('nomor_user', label: 'Nomor (opsional)'),
            AdminFieldSpec.text('alamat_user', label: 'Alamat (opsional)'),
            AdminFieldSpec.dropdown(
              'level',
              label: 'Level',
              options: addLevels,
              required: true,
              initialValue: 'user',
            ),
            AdminFieldSpec.dropdown(
              'status',
              label: 'Status',
              options: statuses,
              required: true,
              initialValue: 'aktif',
            ),
          ],
          onSubmit: (values, _) async {
            final name = (values['name'] as String).trim();
            final email = (values['email'] as String).trim().toLowerCase();
            final pass = values['password'] as String;

            final level = values['level'] as String;
            final status = values['status'] as String;

            if (!addLevels.contains(level)) {
              return const AdminDialogResult(
                ok: false,
                message: 'Level hanya boleh user / penjual',
              );
            }
            if (!statuses.contains(status)) {
              return const AdminDialogResult(
                ok: false,
                message: 'Status harus aktif / nonaktif',
              );
            }

            final nomor = (values['nomor_user'] as String).trim();
            final alamat = (values['alamat_user'] as String).trim();

            final apiRes = await UserService.createUser(
              name: name,
              email: email,
              password: pass,
              level: level,
              status: status,
              nomorUser: nomor,
              alamatUser: alamat,
            );

            final ok = apiRes['ok'] == true;
            final msg =
                (apiRes['message'] ??
                        (ok ? 'User berhasil ditambah' : 'Gagal menambah user'))
                    .toString();
            return AdminDialogResult(ok: ok, message: msg);
          },
        ),
      ),
    );

    if (!mounted) return;
    if (res?.ok == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res!.message)));
      _refresh();
    }
  }

  Future<bool> _confirmChangeToNonaktif(UserModel u) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Konfirmasi'),
            content: Text(
              'Nonaktifkan akun "${u.name}"?\n\n'
              'User tidak bisa login/bertransaksi sampai diaktifkan kembali.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Nonaktifkan'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _changeStatus(UserModel u, String nextStatus) async {
    final current = _norm(u.status);
    final target = _norm(nextStatus);
    if (current == target) return;

    final lvl = _norm(u.level);
    if (lvl == 'admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status admin tidak boleh diubah.')),
      );
      return;
    }

    if (target == 'nonaktif') {
      final okConfirm = await _confirmChangeToNonaktif(u);
      if (!okConfirm) return;
    }

    final ok = await UserService.updateStatus(userId: u.userId, status: target);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Status diubah' : 'Gagal ubah status')),
    );
    if (ok) _refresh();
  }

  Widget _table(List<UserModel> list) {
    const double wId = 110;
    const double wName = 200;
    const double wNomor = 160;
    const double wAlamat = 260;
    const double wEmail = 240;
    const double wSaldo = 120;
    const double wLevel = 140;
    const double wStatus = 170;

    return AdminDbTable<UserModel>(
      tableName: 'users',
      columns: const [
        AdminDbColumn(title: 'user_id', columnName: 'user_id', width: wId),
        AdminDbColumn(title: 'name', columnName: 'name', width: wName),
        AdminDbColumn(
          title: 'nomor_user',
          columnName: 'nomor_user',
          width: wNomor,
        ),
        AdminDbColumn(
          title: 'alamat_user',
          columnName: 'alamat_user',
          width: wAlamat,
        ),
        AdminDbColumn(title: 'email', columnName: 'email', width: wEmail),
        AdminDbColumn(
          title: 'saldo',
          columnName: 'saldo',
          width: wSaldo,
          headerAlign: Alignment.centerRight,
          cellAlign: Alignment.centerRight,
        ),
        AdminDbColumn(title: 'level', columnName: 'level', width: wLevel),
        AdminDbColumn(title: 'status', columnName: 'status', width: wStatus),
      ],
      items: list,
      rowsHeight: 360,
      emptyMessage: 'Tidak ada data yang cocok dengan filter/search.',
      cellsBuilder: (context, u) {
        final statusVal = statuses.contains(_norm(u.status))
            ? _norm(u.status)
            : 'aktif';
        final m = _userToMap(u);
        final nomor = _getNomor(u);
        final alamat = _getAlamat(u);
        final saldoText = _pickSaldoText(m);

        return [
          Text(
            u.userId.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(nomor, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(alamat, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            saldoText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
          Text(u.level, maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(
            height: 40,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: statusVal,
                isExpanded: true,
                items: statuses
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  await _changeStatus(u, v);
                },
              ),
            ),
          ),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<List<UserModel>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final users = snap.data ?? [];
        final filtered = _applyFilter(users);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Toolbar seragam
              Row(
                children: [
                  Expanded(
                    child: AdminTopBar(
                      controller: _searchC,
                      hintText: 'Cari user (nama/email/nomor/alamat)',
                      onAdd: _openAddDialog,
                      addTooltip: 'Tambah User',
                      onFilter: () => _openStatusMenu(context),
                      filterTooltip: 'Filter Status',
                      filterActive: _statusFilter != 'semua',
                    ),
                  ),
                  // icon putih overlay (biar tombol bulat ada icon)
                  const SizedBox(width: 0),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Filter: ${_statusFilter.toUpperCase()} • Data: ${filtered.length}",
                style: TextStyle(color: cs.onSurface.withAlpha(140)),
              ),
              const SizedBox(height: 10),
              _table(filtered),
            ],
          ),
        );
      },
    );
  }
}
