import 'dart:math' as math;
import 'package:flutter/material.dart';

typedef AdminDbCellsBuilder<T> =
    List<Widget> Function(BuildContext context, T item);

@immutable
class AdminDbColumn {
  final String title; // teks header yang tampil
  final String? columnName; // nama kolom DB (untuk tooltip & info)
  final double width;
  final Alignment headerAlign;
  final Alignment cellAlign;

  const AdminDbColumn({
    required this.title,
    required this.width,
    this.columnName,
    this.headerAlign = Alignment.centerLeft,
    this.cellAlign = Alignment.centerLeft,
  });

  String get column =>
      (columnName?.trim().isNotEmpty ?? false) ? columnName!.trim() : title;
}

class AdminDbTable<T> extends StatefulWidget {
  final String? tableName; // contoh: 'payments', 'users', dll
  final List<AdminDbColumn> columns;
  final List<T> items;
  final AdminDbCellsBuilder<T> cellsBuilder;

  // scroll & layout
  final double gap;
  final double rowsHeight;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry rowPadding;

  // empty state
  final String? emptyMessage;
  final Widget? emptyWidget;

  // optional: pakai controller dari luar (kalau mau)
  final ScrollController? horizontalController;
  final ScrollController? verticalController;

  // aksi klik header (kalau null => default dialog info kolom jika tableName ada)
  final void Function(BuildContext context, AdminDbColumn col)? onHeaderTap;

  const AdminDbTable({
    super.key,
    required this.columns,
    required this.items,
    required this.cellsBuilder,
    this.tableName,
    this.gap = 12,
    this.rowsHeight = 360,
    this.padding = const EdgeInsets.all(10),
    this.rowPadding = const EdgeInsets.symmetric(vertical: 10),
    this.emptyMessage,
    this.emptyWidget,
    this.horizontalController,
    this.verticalController,
    this.onHeaderTap,
  });

  @override
  State<AdminDbTable<T>> createState() => _AdminDbTableState<T>();
}

class _AdminDbTableState<T> extends State<AdminDbTable<T>> {
  late final ScrollController _hCtrl;
  late final ScrollController _vCtrl;
  bool _ownH = false;
  bool _ownV = false;

  @override
  void initState() {
    super.initState();
    if (widget.horizontalController != null) {
      _hCtrl = widget.horizontalController!;
    } else {
      _hCtrl = ScrollController();
      _ownH = true;
    }

    if (widget.verticalController != null) {
      _vCtrl = widget.verticalController!;
    } else {
      _vCtrl = ScrollController();
      _ownV = true;
    }
  }

  @override
  void dispose() {
    if (_ownH) _hCtrl.dispose();
    if (_ownV) _vCtrl.dispose();
    super.dispose();
  }

  double get _tableWidth {
    if (widget.columns.isEmpty) return 0;
    final cols = widget.columns.fold<double>(0, (sum, c) => sum + c.width);
    return cols + widget.gap * (widget.columns.length - 1);
  }

  void _defaultHeaderTap(AdminDbColumn col) {
    if (widget.tableName == null || widget.tableName!.trim().isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Info Kolom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tabel: ${widget.tableName}'),
            const SizedBox(height: 8),
            Text(
              'Kolom: ${col.column}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tips: hover/long-press header untuk lihat nama kolom lengkap.',
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

  Widget _headerCell(AdminDbColumn col) {
    return SizedBox(
      width: col.width,
      child: InkWell(
        onTap: () {
          if (widget.onHeaderTap != null) {
            widget.onHeaderTap!(context, col);
          } else {
            _defaultHeaderTap(col);
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Tooltip(
            message: col.column,
            waitDuration: const Duration(milliseconds: 250),
            child: Align(
              alignment: col.headerAlign,
              child: Text(
                col.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(AdminDbColumn col, Widget child) {
    return SizedBox(
      width: col.width,
      child: Align(alignment: col.cellAlign, child: child),
    );
  }

  Widget _gap() => SizedBox(width: widget.gap);

  // ✅ NEW: build row cells dengan fallback supaya data "pasti tampil"
  List<Widget> _safeBuildCells(BuildContext ctx, T item, int rowIndex) {
    try {
      final built = widget.cellsBuilder(ctx, item);

      // kalau builder kosong, tetap tampilkan sesuatu biar kelihatan ada data
      if (built.isEmpty) {
        return [
          Text(
            'Row ${rowIndex + 1}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ];
      }

      return built;
    } catch (e) {
      // kalau cellsBuilder error, jangan bikin tabel blank
      return [
        Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Row ${rowIndex + 1} error',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final cols = widget.columns;
    final items = widget.items;

    return Card(
      child: Padding(
        padding: widget.padding,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            // ✅ kunci lebar child agar ListView tidak dapat width Infinity
            final effectiveWidth = math.max(_tableWidth, constraints.maxWidth);

            return Scrollbar(
              controller: _hCtrl,
              thumbVisibility: true,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _hCtrl,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: effectiveWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < cols.length; i++) ...[
                            _headerCell(cols[i]),
                            if (i != cols.length - 1) _gap(),
                          ],
                        ],
                      ),
                      const Divider(height: 1),

                      // EMPTY (kasih tinggi minimal biar pesan keliatan jelas)
                      if (items.isEmpty)
                        SizedBox(
                          height: widget.rowsHeight,
                          width: effectiveWidth,
                          child:
                              widget.emptyWidget ??
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    widget.emptyMessage ?? 'Tidak ada data.',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                        )
                      else
                        SizedBox(
                          height: widget.rowsHeight,
                          width: effectiveWidth, // ✅ kunci width ListView
                          child: Scrollbar(
                            controller: _vCtrl,
                            thumbVisibility: true,
                            notificationPredicate: (n) =>
                                n.metrics.axis == Axis.vertical,
                            child: ListView.separated(
                              controller: _vCtrl,
                              padding: EdgeInsets.zero,
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final item = items[i];
                                final cells = _safeBuildCells(ctx, item, i);

                                // safety: pastikan jumlah cell sama dengan jumlah kolom
                                final safeCells = <Widget>[];
                                for (int k = 0; k < cols.length; k++) {
                                  safeCells.add(
                                    k < cells.length
                                        ? cells[k]
                                        : const SizedBox.shrink(),
                                  );
                                }

                                // ✅ sedikit zebra biar row lebih kebaca (tidak mempengaruhi logika)
                                final bg = (i % 2 == 0)
                                    ? Colors.transparent
                                    : const Color(0x06000000);

                                return Container(
                                  color: bg,
                                  child: Padding(
                                    padding: widget.rowPadding,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (
                                          int k = 0;
                                          k < cols.length;
                                          k++
                                        ) ...[
                                          _cell(cols[k], safeCells[k]),
                                          if (k != cols.length - 1) _gap(),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
