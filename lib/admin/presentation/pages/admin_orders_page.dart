import 'dart:math';

import 'package:flutter/material.dart';

import '/models/order_model.dart';
import '/models/product_model.dart';
import '/models/toko_model.dart';
import '/models/user_model.dart';

import '../../data/order_service_admin.dart';
import '../../data/user_service_admin.dart';
import '/services/admin_http.dart';
import '/core/config/app_config.dart';

// ✅ tabel reusable
import '../widgets/admin_db_table.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  late Future<List<OrderModel>> _future;

  final TextEditingController _searchC = TextEditingController();
  String _statusFilter = 'semua';

  static const orderStatuses = ['menunggu', 'dibayar', 'dikirim', 'selesai'];

  // ✅ selaraskan & kompatibel dengan backend (transfer|ewallet|cod + legacy cash/qris)
  static const metodeList = ['transfer', 'ewallet', 'cod', 'cash', 'qris'];

  @override
  void initState() {
    super.initState();
    _future = OrderServiceAdmin.fetchOrders();

    _searchC.addListener(() {
      setState(() {}); // realtime search
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = OrderServiceAdmin.fetchOrders();
    });
  }

  List<OrderModel> _applyFilter(List<OrderModel> items) {
    final q = _searchC.text.trim().toLowerCase();

    Iterable<OrderModel> list = items;

    if (_statusFilter != 'semua') {
      list = list.where((o) => o.status.toLowerCase() == _statusFilter);
    }

    if (q.isNotEmpty) {
      list = list.where((o) {
        final id = o.orderId.toString();
        final uid = o.userId.toString();
        final pembeli = (o.pembeli ?? '').toLowerCase();
        return id.contains(q) || uid.contains(q) || pembeli.contains(q);
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
              ...orderStatuses.map((s) {
                final active = _statusFilter == s;
                return ListTile(
                  title: Text(s),
                  trailing: active ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, s),
                );
              }),
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

  // =========================================================
  // ✅ Helper: ambil toko aktif (admin)
  // =========================================================
  Future<List<TokoModel>> _fetchActiveTokos() async {
    final res = await AdminHttp.getJson('toko/list?status=aktif');

    if (res['ok'] == true && res['data'] is List) {
      final raw = res['data'] as List;

      final tokos = raw
          .whereType<Map>()
          .map((e) {
            final mm = Map<String, dynamic>.from(e);
            // fallback key
            if (mm['toko_id'] == null &&
                mm['tokoId'] == null &&
                mm['id'] != null) {
              mm['toko_id'] = mm['id'];
            }
            return TokoModel.fromJson(mm);
          })
          .where((t) => t.tokoId > 0)
          .toList();

      tokos.sort((a, b) => a.tokoId.compareTo(b.tokoId));
      return tokos;
    }

    return <TokoModel>[];
  }

  // =========================================================
  // ✅ Helper: cek toko mana yang punya produk yang bisa diorder
  // (status aktif + stok > 0) via 1x fetch global (lite)
  // =========================================================
  Future<Set<int>> _fetchTokoIdsWithProducts() async {
    final res = await AdminHttp.getJson(
      'products/listProduct?status=aktif&lite=1&limit=500',
    );

    final set = <int>{};

    if (res['ok'] == true && res['data'] is List) {
      final raw = res['data'] as List;
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);

        final t = int.tryParse('${m['toko_id'] ?? m['tokoId'] ?? 0}') ?? 0;
        final stok = int.tryParse('${m['stok'] ?? m['stock'] ?? 0}') ?? 0;
        final st = (m['status'] ?? 'aktif').toString().toLowerCase();

        if (t > 0 && stok > 0 && st == 'aktif') set.add(t);
      }
    }

    return set;
  }

  // =========================================================
  // ✅ Fetch produk per toko (aktif + lite)
  // =========================================================
  Future<List<ProductModel>> _fetchProductsByToko(int tokoId) async {
    final res = await AdminHttp.getJson(
      'products/listProduct?status=aktif&lite=1&toko_id=$tokoId&limit=500',
    );

    if (res['ok'] == true && res['data'] is List) {
      final raw = res['data'] as List;
      final products = raw
          .whereType<Map>()
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.productId > 0)
          .toList();

      // optional sort: terbaru dulu
      products.sort((a, b) => b.productId.compareTo(a.productId));
      return products;
    }

    return <ProductModel>[];
  }

  // =========================================================
  // ✅ ADD ORDER (revisi sesuai permintaan)
  // 1) hanya boleh jika ada toko & ada produk
  // 2) pilih toko -> tampil produk pada toko
  // 3) items manual dihapus, diganti produk list
  // =========================================================
  Future<void> _openAddDialog() async {
    // fetch eligible users
    final List<UserModel> eligibleUsers =
        await UserServiceAdmin.fetchEligibleOrderUsers();

    if (!mounted) return;

    if (eligibleUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada user aktif level "user" untuk dibuatkan order.',
          ),
        ),
      );
      return;
    }

    // fetch tokos aktif
    final tokos = await _fetchActiveTokos();
    if (!mounted) return;

    if (tokos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada toko aktif. Tidak bisa membuat order.'),
        ),
      );
      return;
    }

    // cek ada produk yang bisa diorder (aktif + stok>0)
    final tokoIdsWithProducts = await _fetchTokoIdsWithProducts();
    if (!mounted) return;

    final tokosWithProducts = tokos
        .where((t) => tokoIdsWithProducts.contains(t.tokoId))
        .toList();

    if (tokosWithProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada produk aktif (stok > 0) pada toko aktif. Tidak bisa membuat order.',
          ),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddOrderDialog(
        users: eligibleUsers,
        tokos: tokosWithProducts,
        fetchProductsByToko: _fetchProductsByToko,
      ),
    );

    if (!mounted) return;

    if (ok == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order berhasil dibuat')));
      _refresh();
    }
  }

  Widget _table(List<OrderModel> list) {
    const double wId = 110;
    const double wPembeli = 260;
    const double wTotal = 140;
    const double wMetode = 140;
    const double wStatus = 170;
    const double wAksi = 110;

    return AdminDbTable<OrderModel>(
      tableName: 'orders',
      columns: const [
        AdminDbColumn(title: 'order_id', width: wId),
        AdminDbColumn(title: 'pembeli', width: wPembeli),
        AdminDbColumn(title: 'total_amount', width: wTotal),
        AdminDbColumn(title: 'metode_pembayaran', width: wMetode),
        AdminDbColumn(title: 'status', width: wStatus),
        AdminDbColumn(
          title: 'aksi',
          width: wAksi,
          headerAlign: Alignment.center,
          cellAlign: Alignment.center,
        ),
      ],
      items: list,
      rowsHeight: 360,
      emptyMessage: 'Tidak ada order yang cocok dengan filter/search.',
      cellsBuilder: (context, o) {
        final statusVal = orderStatuses.contains(o.status.toLowerCase())
            ? o.status.toLowerCase()
            : 'menunggu';

        final metodeVal = metodeList.contains(o.metodePembayaran.toLowerCase())
            ? o.metodePembayaran.toLowerCase()
            : 'transfer';

        final pembeliText = (o.pembeli != null && o.pembeli!.trim().isNotEmpty)
            ? '${o.pembeli} (uid:${o.userId})'
            : 'uid:${o.userId}';

        return [
          Text(
            o.orderId.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(pembeliText, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            o.totalAmount.toStringAsFixed(0),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(metodeVal, maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(
            height: 40,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: statusVal,
                isExpanded: true,
                items: orderStatuses
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;

                  final ok = await OrderServiceAdmin.updateStatus(
                    orderId: o.orderId,
                    status: v,
                  );

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Status order diubah' : 'Gagal ubah status',
                      ),
                    ),
                  );

                  if (ok) _refresh();
                },
              ),
            ),
          ),
          const Icon(Icons.receipt_long, size: 18),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrderModel>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? [];
        final filtered = _applyFilter(items);

        return RefreshIndicator(
          onRefresh: () async {
            _refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchC,
                        decoration: InputDecoration(
                          hintText: "Search (id/user/nama)",
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
                    onTap: _openAddDialog,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
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
              Text(
                "Filter: ${_statusFilter.toUpperCase()} • Data: ${filtered.length}",
                style: const TextStyle(color: Colors.black54),
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

// =========================================================
// ✅ Dialog tambah order baru:
// - pilih user, metode, status
// - pilih toko
// - tampil produk di toko tsb + qty stepper
// - submit hanya jika ada produk qty>0
// =========================================================
class _AddOrderDialog extends StatefulWidget {
  final List<UserModel> users;
  final List<TokoModel> tokos;

  final Future<List<ProductModel>> Function(int tokoId) fetchProductsByToko;

  const _AddOrderDialog({
    required this.users,
    required this.tokos,
    required this.fetchProductsByToko,
  });

  @override
  State<_AddOrderDialog> createState() => _AddOrderDialogState();
}

class _AddOrderDialogState extends State<_AddOrderDialog> {
  late int _userId;
  String _metode = 'transfer';
  String _status = 'menunggu';
  late int _tokoId;

  bool _loadingProducts = true;
  bool _submitting = false;

  List<ProductModel> _products = [];
  final Map<int, int> _qty = {}; // productId -> qty

  @override
  void initState() {
    super.initState();
    _userId = widget.users.first.userId;
    _tokoId = widget.tokos.first.tokoId;
    _loadProducts();
  }

  String _tokoName(int tokoId) {
    final t = widget.tokos.firstWhere((x) => x.tokoId == tokoId);
    final name = t.namaToko.trim().isNotEmpty
        ? t.namaToko.trim()
        : 'Toko ${t.tokoId}';
    return '${t.tokoId} - $name';
  }

  String _userLabel(int userId) {
    final u = widget.users.firstWhere((x) => x.userId == userId);
    return '${u.userId} - ${u.name}';
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _products = [];
      _qty.clear();
    });

    final items = await widget.fetchProductsByToko(_tokoId);

    if (!mounted) return;
    setState(() {
      _products = items;
      _loadingProducts = false;
    });
  }

  bool get _canSubmit => _qty.values.any((v) => v > 0);

  int _stockSafe(ProductModel p) => max(0, p.stok);

  String _fullImageUrl(String? u) {
    if (u == null) return '';
    final s = u.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return '${AppConfig.baseUrl}$s';
    return '${AppConfig.baseUrl}/$s';
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk pada toko ini kosong. Pilih toko lain.'),
        ),
      );
      return;
    }

    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 produk (qty > 0).')),
      );
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final p in _products) {
      final q = _qty[p.productId] ?? 0;
      if (q <= 0) continue;

      items.add({'product_id': p.productId, 'quantity': q, 'toko_id': _tokoId});
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada item yang dipilih.')),
      );
      return;
    }

    setState(() => _submitting = true);

    final ok = await OrderServiceAdmin.createOrder(
      userId: _userId,
      metodePembayaran: _metode,
      status: _status,
      items: items,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuat order (cek stok / produk valid).'),
        ),
      );
    }
  }

  Widget _productRow(ProductModel p) {
    final stock = _stockSafe(p);
    final disabled = stock <= 0 || p.status.toLowerCase() != 'aktif';

    final q = _qty[p.productId] ?? 0;

    final img = _fullImageUrl(p.imageUrl);
    final hasImg = img.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x11000000)),
        color: disabled ? const Color(0xFFF5F5F7) : Colors.white,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 52,
              height: 52,
              color: const Color(0xFFEFEFF6),
              child: hasImg
                  ? Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported_rounded),
                    )
                  : const Icon(Icons.image_rounded),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.namaProduk,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp ${p.harga.toStringAsFixed(0)} • Stok: $stock',
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
                if (disabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Tidak tersedia',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // qty stepper
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x22000000)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  iconSize: 18,
                  onPressed: disabled || q <= 0
                      ? null
                      : () {
                          setState(() {
                            _qty[p.productId] = max(0, q - 1);
                          });
                        },
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 26,
                  child: Text(
                    '$q',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  onPressed: disabled || q >= stock
                      ? null
                      : () {
                          setState(() {
                            _qty[p.productId] = min(stock, q + 1);
                          });
                        },
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Order'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // user
              DropdownButtonFormField<int>(
                value: _userId,
                decoration: const InputDecoration(
                  labelText: 'user_id (user aktif)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.users
                    .map(
                      (u) => DropdownMenuItem(
                        value: u.userId,
                        child: Text('${u.userId} - ${u.name}'),
                      ),
                    )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _userId = v);
                      },
              ),
              const SizedBox(height: 10),

              // metode
              DropdownButtonFormField<String>(
                value: _metode,
                decoration: const InputDecoration(
                  labelText: 'metode_pembayaran',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _AdminOrdersPageState.metodeList
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _metode = v ?? 'transfer'),
              ),
              const SizedBox(height: 10),

              // status
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'status',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _AdminOrdersPageState.orderStatuses
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _status = v ?? 'menunggu'),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // toko dropdown
              DropdownButtonFormField<int>(
                value: _tokoId,
                decoration: const InputDecoration(
                  labelText: 'Toko',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.tokos
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.tokoId,
                        child: Text(_tokoName(t.tokoId)),
                      ),
                    )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (v) async {
                        if (v == null) return;
                        setState(() => _tokoId = v);
                        await _loadProducts();
                      },
              ),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Produk di ${_tokoName(_tokoId)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 8),

              if (_loadingProducts)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_products.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Produk pada toko ini kosong.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                Column(
                  children: [
                    for (final p in _products) ...[
                      _productRow(p),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),

              const SizedBox(height: 6),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'User: ${_userLabel(_userId)}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: (_submitting || !_canSubmit) ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: Text(_submitting ? 'Menyimpan...' : 'Tambah'),
        ),
      ],
    );
  }
}
