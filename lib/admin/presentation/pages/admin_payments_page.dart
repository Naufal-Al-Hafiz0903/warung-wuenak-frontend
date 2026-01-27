import 'package:flutter/material.dart';

import '/models/payment_model.dart';
import '/services/admin_http.dart';

import '../../data/payment_service_admin.dart';
import '../widgets/admin_add_dialog.dart';
import '../widgets/admin_db_table.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  late Future<List<PaymentModel>> _future;

  final TextEditingController _searchC = TextEditingController();

  // ✅ filter berdasarkan METODE (sesuai DB)
  String _metodeFilter = 'semua';

  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  static const List<String> statuses = ['menunggu', 'dibayar', 'gagal'];

  // ✅ sesuai ENUM DB payments.metode: 'cash','transfer','qris'
  static const List<String> metodeDb = ['cash', 'transfer', 'qris'];

  static const String _orderOptionsPath = 'payments/order-options';

  static const double _wPaymentId = 110;
  static const double _wOrderId = 120;
  static const double _wPembeli = 180;
  static const double _wMetode = 110;
  static const double _wProvider = 140;
  static const double _wRef = 210;
  static const double _wAmount = 120;
  static const double _wPaidAt = 170;
  static const double _wStatus = 130;
  static const double _wAksi = 130;

  // cache data terakhir (biar filter metode tidak perlu await _future)
  List<PaymentModel> _lastItems = <PaymentModel>[];

  @override
  void initState() {
    super.initState();
    _future = PaymentServiceAdmin.fetchPayments();

    _searchC.addListener(() {
      setState(() {}); // realtime search
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = PaymentServiceAdmin.fetchPayments());
  }

  void _showColumnWindow(String columnName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Info Kolom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tabel: payments'),
            const SizedBox(height: 8),
            Text(
              'Kolom: $columnName',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tips: long-press/hover header untuk lihat nama kolom lengkap.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  List<PaymentModel> _applyFilter(List<PaymentModel> items) {
    final q = _searchC.text.trim().toLowerCase();
    Iterable<PaymentModel> list = items;

    // ✅ filter metode
    if (_metodeFilter != 'semua') {
      list = list.where((p) => p.metode.toLowerCase().trim() == _metodeFilter);
    }

    // ✅ search: fokus nama pembeli + metode (tambahkan id biar tetap berguna)
    if (q.isNotEmpty) {
      list = list.where((p) {
        final pid = p.paymentId.toString();
        final oid = p.orderId.toString();
        final metode = p.metode.toLowerCase();
        final pembeli = (p.pembeli ?? '').toLowerCase();
        return pembeli.contains(q) ||
            metode.contains(q) ||
            pid.contains(q) ||
            oid.contains(q);
      });
    }

    return list.toList();
  }

  // ✅ BottomSheet filter METODE (sesuai DB + dynamic kalau ada yang baru)
  void _openMetodeMenu(BuildContext context) async {
    final dynamicMetodes = _lastItems
        .map((e) => e.metode.toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    final options = <String>{...metodeDb, ...dynamicMetodes}.toList()..sort();

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
                trailing: _metodeFilter == 'semua'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, 'semua'),
              ),
              ...options.map((m) {
                final active = _metodeFilter == m;
                return ListTile(
                  title: Text(m),
                  trailing: active ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, m),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() => _metodeFilter = selected);
    }
  }

  // ==========================================================
  // ✅ order_id options dari backend
  // ==========================================================
  Future<List<String>> _fetchOrderIdOptions() async {
    final res = await AdminHttp.getJson(_orderOptionsPath);

    if (res['ok'] == true) {
      final data = res['data'];
      if (data is List) {
        final ids = <String>[];
        for (final e in data) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            final id = (m['order_id'] ?? m['orderId'] ?? m['id'])?.toString();
            if (id != null && id.trim().isNotEmpty) ids.add(id.trim());
          }
        }
        return ids;
      }
    }
    return <String>[];
  }

  // ==========================================================
  // ✅ ADD PAYMENT (Dialog)
  // ==========================================================
  Future<void> _openAddDialog() async {
    final options = await _fetchOrderIdOptions();

    if (!mounted) return;

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada order yang tersedia untuk dibuat payment.'),
        ),
      );
      return;
    }

    final res = await showDialog<AdminDialogResult>(
      context: context,
      builder: (_) => AdminEntityAddDialog(
        schema: AdminDialogSchema(
          title: 'Tambah Payment',
          submitLabel: 'Tambah',
          fields: [
            AdminFieldSpec.dropdown(
              'order_id',
              label: 'order_id',
              options: options,
              required: true,
              initialValue: options.first,
            ),
            AdminFieldSpec.dropdown(
              'metode',
              label: 'metode',
              options: metodeDb, // ✅ sesuai DB
              required: true,
              initialValue: metodeDb.isNotEmpty ? metodeDb.first : null,
            ),
            AdminFieldSpec.text('provider', label: 'provider (opsional)'),
            AdminFieldSpec.text(
              'reference_code',
              label: 'reference_code (opsional)',
            ),
            AdminFieldSpec.dropdown(
              'status',
              label: 'status',
              options: statuses,
              required: true,
              initialValue: statuses.isNotEmpty ? statuses.first : null,
            ),
            AdminFieldSpec.text('paid_at', label: 'paid_at (opsional)'),
          ],
          onSubmit: (values, _) async {
            final orderIdStr = (values['order_id'] as String?) ?? '';
            final orderId = int.tryParse(orderIdStr) ?? 0;

            final metode = (values['metode'] as String?) ?? 'transfer';
            final status = (values['status'] as String?) ?? 'menunggu';

            final provider = (values['provider'] ?? '').toString();
            final referenceCode = (values['reference_code'] ?? '').toString();
            final paidAt = (values['paid_at'] ?? '').toString();

            if (orderId <= 0) {
              return const AdminDialogResult(
                ok: false,
                message: 'order_id tidak valid',
              );
            }

            final ok = await PaymentServiceAdmin.createPayment(
              orderId: orderId,
              metode: metode,
              status: status,
              provider: provider,
              referenceCode: referenceCode,
              paidAt: paidAt,
            );

            return AdminDialogResult(
              ok: ok,
              message: ok ? 'Payment berhasil dibuat' : 'Gagal membuat payment',
            );
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

  Widget _table({required List<PaymentModel> list, required int allCount}) {
    final bool hasActiveFilter =
        _metodeFilter != 'semua' || _searchC.text.trim().isNotEmpty;

    return AdminDbTable<PaymentModel>(
      tableName: 'payments',
      horizontalController: _hCtrl,
      verticalController: _vCtrl,
      columns: const [
        AdminDbColumn(title: 'payment_id', width: _wPaymentId),
        AdminDbColumn(title: 'order_id', width: _wOrderId),
        AdminDbColumn(title: 'pembeli', width: _wPembeli),
        AdminDbColumn(title: 'metode', width: _wMetode),
        AdminDbColumn(title: 'provider', width: _wProvider),
        AdminDbColumn(title: 'reference_code', width: _wRef),
        AdminDbColumn(title: 'amount', width: _wAmount),
        AdminDbColumn(title: 'paid_at', width: _wPaidAt),
        AdminDbColumn(title: 'status', width: _wStatus),
        AdminDbColumn(
          title: 'aksi',
          width: _wAksi,
          headerAlign: Alignment.center,
          cellAlign: Alignment.center,
        ),
      ],
      items: list,
      rowsHeight: 360,
      emptyWidget: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            allCount == 0
                ? 'Belum ada data di tabel payments. Jika sudah ada order, buat payment lewat tombol +.'
                : (hasActiveFilter
                      ? 'Tidak ada payment yang cocok dengan filter/search.'
                      : 'Tidak ada payment.'),
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ),
      onHeaderTap: (ctx, col) => _showColumnWindow(col.title),
      cellsBuilder: (context, p) {
        final statusVal = statuses.contains(p.status.toLowerCase())
            ? p.status.toLowerCase()
            : 'menunggu';

        final metodeVal = p.metode.toString().trim().isEmpty
            ? 'transfer'
            : p.metode.toLowerCase();

        final canConfirm = statusVal == 'menunggu';

        final pembeliText = (p.pembeli == null || p.pembeli!.trim().isEmpty)
            ? '-'
            : p.pembeli!.trim();

        final providerText = (p.provider == null || p.provider!.trim().isEmpty)
            ? '-'
            : p.provider!.trim();

        final refText =
            (p.referenceCode == null || p.referenceCode!.trim().isEmpty)
            ? '-'
            : p.referenceCode!.trim();

        final amountText = (p.amount == null)
            ? '-'
            : p.amount!.toStringAsFixed(0);

        return [
          Text(
            p.paymentId.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            p.orderId.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(pembeliText, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(metodeVal, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(providerText, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(refText, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(amountText, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(p.paidAt ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  if (v == null || v == statusVal) return;

                  bool ok = false;

                  if (v == 'dibayar') {
                    ok = await PaymentServiceAdmin.confirmPayment(p.paymentId);
                  } else {
                    ok = await PaymentServiceAdmin.updateStatus(
                      paymentId: p.paymentId,
                      status: v,
                    );
                  }

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Status payment diubah' : 'Gagal ubah status',
                      ),
                    ),
                  );

                  if (ok) _refresh();
                },
              ),
            ),
          ),
          canConfirm
              ? ElevatedButton(
                  onPressed: () async {
                    final ok = await PaymentServiceAdmin.confirmPayment(
                      p.paymentId,
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Payment dikonfirmasi (dibayar)'
                              : 'Gagal konfirmasi',
                        ),
                      ),
                    );

                    if (ok) _refresh();
                  },
                  child: const Text('Confirm'),
                )
              : const Icon(Icons.check_circle),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentModel>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? <PaymentModel>[];
        _lastItems = items; // cache tanpa setState

        final filtered = _applyFilter(items);

        return RefreshIndicator(
          onRefresh: _refresh,
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
                          hintText: 'Search (nama/metode)',
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
                    onTap: () => _openMetodeMenu(context),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_metodeFilter == 'semua')
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
                'Filter: ${_metodeFilter.toUpperCase()} • Data: ${filtered.length}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              _table(list: filtered, allCount: items.length),
            ],
          ),
        );
      },
    );
  }
}
