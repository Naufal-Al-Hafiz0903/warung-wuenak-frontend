import 'package:flutter/material.dart';
import 'admin_menu_item.dart';
import 'admin_ui.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<AdminMenuItemData> items;
  final ValueChanged<int> onSelect;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AdminPageBg(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xCCFFFFFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x1A000000),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withAlpha(31),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Panel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'warung_wuenak',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final it = items[i];
                    final sel = i == selectedIndex;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onSelect(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? cs.primary.withAlpha(26)
                                : const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel
                                  ? cs.primary.withAlpha(55)
                                  : const Color(0x22FFFFFF),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                it.icon,
                                color: sel ? cs.primary : Colors.black54,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  it.title,
                                  style: TextStyle(
                                    fontWeight: sel
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: sel ? cs.primary : Colors.black87,
                                  ),
                                ),
                              ),
                              if (sel)
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: cs.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
