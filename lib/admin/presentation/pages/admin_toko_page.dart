import 'package:flutter/material.dart';

import '/models/user_model.dart';
import '../../../seller/data/user_service.dart';
import '../../../seller/data/toko_service.dart';

import '../widgets/admin_add_dialog.dart';
import '../widgets/admin_db_table.dart';
import '../widgets/admin_ui.dart';

class AdminTokoPage extends StatefulWidget {
  const AdminTokoPage({super.key});

  @override
  State<AdminTokoPage> createState() => _AdminTokoPageState();
}

class _AdminTokoPageState extends State<AdminTokoPage> {
  late Future<List<UserModel>> _futureUsers;
  late Future<Map<int, String>> _futureTokoStatusMap;

  final TextEditingController _searchC = TextEditingController();

  /// filter status TOKO: semua / aktif / nonaktif
  /// backend punya 3 state: aktif / nonaktif / belum
  /// UI filter "nonaktif" mencakup nonaktif + belum
  String _tokoStatusFilter = 'semua';

  static const statuses = ['aktif', 'nonaktif'];

  String _norm(String s) => s.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _reloadFutures();
    _searchC.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _reloadFutures() {
    _futureUsers = UserService.fetchUsers();
    _futureTokoStatusMap = _futureUsers.then((users) async {
      final sellerIds = users
          .where((u) => _norm(u.level) == 'penjual')
          .map((u) => u.userId)
          .toList();

      return TokoService.fetchTokoStatusMap(
        userIds: sellerIds,
        fillMissing: true,
      );
    });
  }

  Future<void> _refresh() async {
    setState(() => _reloadFutures());
  }

  // =========================
  // FILTER + SEARCH (berdasarkan TOKO)
  // =========================
  List<UserModel> _applyFilter(
    List<UserModel> users,
    Map<int, String> tokoMap,
  ) {
    final q = _searchC.text.trim().toLowerCase();
    Iterable<UserModel> list = users;

    // hanya PENJUAL
    list = list.where((u) => _norm(u.level) == 'penjual');

    // filter toko status
    if (_tokoStatusFilter != 'semua') {
      list = list.where((u) {
        final st = _norm(tokoMap[u.userId] ?? 'belum');

        if (_tokoStatusFilter == 'aktif') return st == 'aktif';

        // "nonaktif" mencakup nonaktif + belum
        return st == 'nonaktif' || st == 'belum';
      });
    }

    // search
    if (q.isNotEmpty) {
      list = list.where((u) {
        final id = u.userId.toString().toLowerCase();
        final name = u.name.toLowerCase();
        final email = u.email.toLowerCase();
        final level = u.level.toLowerCase();
        final nomor = (u.nomorUser ?? '').toLowerCase();
        final alamat = (u.alamatUser ?? '').toLowerCase();

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
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Semua'),
                trailing: _tokoStatusFilter == 'semua'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, 'semua'),
              ),
              ListTile(
                title: const Text('Aktif'),
                trailing: _tokoStatusFilter == 'aktif'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, 'aktif'),
              ),
              ListTile(
                title: const Text('Nonaktif'),
                subtitle: const Text('Termasuk status "belum"'),
                trailing: _tokoStatusFilter == 'nonaktif'
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

    if (selected != null) setState(() => _tokoStatusFilter = selected);
  }

  // =========================
  // DIALOG BUAT TOKO (HANYA jika status=BELUM)
  // =========================
  Future<void> _openCreateTokoDialog(UserModel u) async {
    if (!mounted) return;

    final res = await showDialog<AdminDialogResult>(
      context: context,
      builder: (_) => AdminEntityAddDialog(
        schema: AdminDialogSchema(
          title: 'Buat Toko • ${u.name}',
          submitLabel: 'Simpan',
          fields: [
            AdminFieldSpec.text(
              'nama_toko',
              label: 'Nama Toko',
              required: true,
            ),
            AdminFieldSpec.multiline(
              'deskripsi_toko',
              label: 'Deskripsi (opsional)',
              required: false,
              maxLines: 3,
            ),
            AdminFieldSpec.text(
              'alamat_toko',
              label: 'Alamat (opsional)',
              required: false,
            ),
          ],
          onSubmit: (values, _) async {
            final namaToko = (values['nama_toko'] ?? '').toString().trim();
            final deskripsi = (values['deskripsi_toko'] ?? '')
                .toString()
                .trim();
            final alamat = (values['alamat_toko'] ?? '').toString().trim();

            if (namaToko.isEmpty) {
              return const AdminDialogResult(
                ok: false,
                message: 'Nama toko wajib diisi',
              );
            }

            final apiRes = await TokoService.createToko(
              userId: u.userId,
              namaToko: namaToko,
              deskripsiToko: deskripsi,
              alamatToko: alamat,
            );

            final ok = apiRes['ok'] == true;
            final msg =
                (apiRes['message'] ??
                        (ok ? 'Toko berhasil dibuat' : 'Gagal membuat toko'))
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

  // =========================
  // AKTIFKAN KEMBALI TOKO (tanpa dialog) jika status=NONAKTIF
  // =========================
  Future<void> _reactivateExistingToko(UserModel u) async {
    final apiRes = await TokoService.reactivateToko(userId: u.userId);

    if (!mounted) return;

    final ok = apiRes['ok'] == true;
    final msg =
        (apiRes['message'] ??
                (ok ? 'Toko diaktifkan kembali' : 'Gagal aktifkan toko'))
            .toString();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (ok) _refresh();
  }

  // =========================
  // DIALOG BUAT TOKO (via tombol +) -> hanya untuk status "belum"
  // =========================
  String _sellerOptionLabel(UserModel u) =>
      'ID:${u.userId} • ${u.name} (${u.email})';

  int? _parseSellerId(String raw) {
    final s = raw.trim();
    final idx = s.indexOf('ID:');
    if (idx == -1) return null;

    final after = s.substring(idx + 3);
    final numStr = after
        .split(RegExp(r'[^0-9]'))
        .firstWhere((x) => x.trim().isNotEmpty, orElse: () => '');
    return int.tryParse(numStr);
  }

  Future<void> _openAddTokoDialog() async {
    // ✅ FIX: harus fetchUsers()
    final allUsers = await UserService.fetchUsers();
    final sellers = allUsers.where((u) => _norm(u.level) == 'penjual').toList();

    if (!mounted) return;

    if (sellers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada user level penjual.')),
      );
      return;
    }

    final sellerIds = sellers.map((e) => e.userId).toList();
    final tokoMap = await TokoService.fetchTokoStatusMap(
      userIds: sellerIds,
      fillMissing: true,
    );

    final sellerOptions = sellers.map(_sellerOptionLabel).toList();

    final res = await showDialog<AdminDialogResult>(
      context: context,
      builder: (_) => AdminEntityAddDialog(
        schema: AdminDialogSchema(
          title: 'Buat Toko Penjual',
          submitLabel: 'Simpan',
          fields: [
            AdminFieldSpec.dropdown(
              'seller',
              label: 'Pilih Penjual',
              options: sellerOptions,
              required: true,
            ),
            AdminFieldSpec.text(
              'nama_toko',
              label: 'Nama Toko',
              required: true,
            ),
            AdminFieldSpec.multiline(
              'deskripsi_toko',
              label: 'Deskripsi (opsional)',
              required: false,
              maxLines: 3,
            ),
            AdminFieldSpec.text(
              'alamat_toko',
              label: 'Alamat (opsional)',
              required: false,
            ),
          ],
          onSubmit: (values, _) async {
            final sellerRaw = (values['seller'] ?? '').toString().trim();
            final sellerId = _parseSellerId(sellerRaw);

            if (sellerId == null) {
              return const AdminDialogResult(
                ok: false,
                message: 'Pilih penjual dulu.',
              );
            }

            final current = _norm(tokoMap[sellerId] ?? 'belum');

            if (current == 'aktif') {
              return const AdminDialogResult(
                ok: false,
                message:
                    'Toko penjual ini sudah AKTIF. Jika ingin ubah, nonaktifkan dulu dari kolom "Toko".',
              );
            }

            if (current == 'nonaktif') {
              return const AdminDialogResult(
                ok: false,
                message:
                    'Penjual ini sudah pernah membuat toko (NONAKTIF). Aktifkan kembali dari kolom "toko" pada tabel.',
              );
            }

            final namaToko = (values['nama_toko'] ?? '').toString().trim();
            final deskripsi = (values['deskripsi_toko'] ?? '')
                .toString()
                .trim();
            final alamat = (values['alamat_toko'] ?? '').toString().trim();

            if (namaToko.isEmpty) {
              return const AdminDialogResult(
                ok: false,
                message: 'Nama toko wajib diisi',
              );
            }

            final apiRes = await TokoService.createToko(
              userId: sellerId,
              namaToko: namaToko,
              deskripsiToko: deskripsi,
              alamatToko: alamat,
            );

            final ok = apiRes['ok'] == true;
            final msg =
                (apiRes['message'] ??
                        (ok ? 'Toko berhasil dibuat' : 'Gagal membuat toko'))
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

  // =========================
  // TABEL
  // =========================
  Widget _table(List<UserModel> list, Map<int, String> tokoMap) {
    const double wId = 110;
    const double wName = 200;
    const double wNomor = 160;
    const double wAlamat = 260;
    const double wEmail = 240;
    const double wSaldo = 120;
    const double wLevel = 140;
    const double wStatus = 170;
    const double wToko = 210;

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
        AdminDbColumn(title: 'toko', columnName: 'toko', width: wToko),
      ],
      items: list,
      rowsHeight: 360,
      emptyMessage: 'Tidak ada data yang cocok dengan filter/search.',
      cellsBuilder: (context, u) {
        final userStatusVal = statuses.contains(_norm(u.status))
            ? _norm(u.status)
            : 'aktif';

        final rawTokoState = _norm(tokoMap[u.userId] ?? 'belum');
        final tokoStatusVal = statuses.contains(rawTokoState)
            ? rawTokoState
            : 'nonaktif';

        final saldoText = (u.saldo).toStringAsFixed(0);
        final nomor = (u.nomorUser ?? '-').trim().isEmpty ? '-' : u.nomorUser!;
        final alamat = (u.alamatUser ?? '-').trim().isEmpty
            ? '-'
            : u.alamatUser!;

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

          // STATUS USER
          SizedBox(
            height: 40,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: userStatusVal,
                isExpanded: true,
                items: statuses
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  final ok = await UserService.updateStatus(
                    userId: u.userId,
                    status: v,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Status user diubah' : 'Gagal ubah status user',
                      ),
                    ),
                  );
                  if (ok) _refresh();
                },
              ),
            ),
          ),

          // STATUS TOKO
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: tokoStatusVal,
                      isExpanded: true,
                      items: statuses
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        if (v == tokoStatusVal) return;

                        if (v == 'aktif') {
                          if (rawTokoState == 'belum') {
                            await _openCreateTokoDialog(u);
                            return;
                          }
                          if (rawTokoState == 'nonaktif') {
                            await _reactivateExistingToko(u);
                            return;
                          }
                          return;
                        }

                        if (rawTokoState == 'belum') return;

                        final ok = await TokoService.updateStatusByUserId(
                          userId: u.userId,
                          status: 'nonaktif',
                        );

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Toko dinonaktifkan'
                                  : 'Gagal nonaktifkan toko',
                            ),
                          ),
                        );
                        if (ok) _refresh();
                      },
                    ),
                  ),
                ),
                if (rawTokoState == 'belum') ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Penjual belum punya toko. Klik untuk buat.',
                    child: InkWell(
                      onTap: () => _openCreateTokoDialog(u),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_business_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
      future: _futureUsers,
      builder: (context, snapUsers) {
        if (snapUsers.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapUsers.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: ListTile(
                  title: const Text('Gagal memuat data users'),
                  subtitle: Text('${snapUsers.error}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refresh,
                  ),
                ),
              ),
            ),
          );
        }

        final users = snapUsers.data ?? [];

        return FutureBuilder<Map<int, String>>(
          future: _futureTokoStatusMap,
          builder: (context, snapToko) {
            if (snapToko.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapToko.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: ListTile(
                      title: const Text('Gagal memuat status toko'),
                      subtitle: Text('${snapToko.error}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _refresh,
                      ),
                    ),
                  ),
                ),
              );
            }

            final tokoMap = snapToko.data ?? {};
            final filtered = _applyFilter(users, tokoMap);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AdminTopBar(
                    controller: _searchC,
                    hintText: 'Cari penjual / email / nomor / alamat',
                    onAdd: _openAddTokoDialog,
                    addTooltip: 'Buat Toko',
                    addIcon: Icons.store_mall_directory_rounded,
                    onFilter: () => _openStatusMenu(context),
                    filterTooltip: 'Filter Status Toko',
                    filterActive: _tokoStatusFilter != 'semua',
                    // ❌ HAPUS filterColor karena AdminTopBar kamu tidak punya param itu
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Filter TOKO: ${_tokoStatusFilter.toUpperCase()} • Penjual: ${filtered.length}",
                    style: TextStyle(color: cs.onSurface.withAlpha(140)),
                  ),
                  const SizedBox(height: 10),
                  _table(filtered, tokoMap),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
