import 'package:flutter/material.dart';

class AdminPageBg extends StatelessWidget {
  final Widget child;
  const AdminPageBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F0FF), Color(0xFFFFF1F7)],
        ),
      ),
      child: child,
    );
  }
}

class AdminTopBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  final VoidCallback? onAdd;
  final String addTooltip;
  final IconData addIcon;
  final Color? addColor;

  final VoidCallback? onFilter;
  final String filterTooltip;
  final IconData filterIcon;
  final bool filterActive;
  final Color? filterColor;

  const AdminTopBar({
    super.key,
    required this.controller,
    this.hintText = 'Search',

    this.onAdd,
    this.addTooltip = 'Tambah',
    this.addIcon = Icons.add_rounded,
    this.addColor,

    this.onFilter,
    this.filterTooltip = 'Filter',
    this.filterIcon = Icons.tune_rounded,
    this.filterActive = false,
    this.filterColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color addBtnColor = addColor ?? cs.primary;
    final Color filterBtnColor =
        filterColor ?? (filterActive ? cs.primary : Colors.red);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ✅ tombol +
        if (onAdd != null) ...[
          adminCircleWithIcon(
            tooltip: addTooltip,
            icon: addIcon,
            color: addBtnColor,
            onTap: onAdd!,
          ),
          const SizedBox(width: 10),
        ],

        // ✅ tombol filter
        if (onFilter != null)
          adminCircleWithIcon(
            tooltip: filterTooltip,
            icon: filterIcon,
            color: filterBtnColor,
            onTap: onFilter!,
          ),
      ],
    );
  }
}

class AdminCircleAction extends StatelessWidget {
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  final double size;

  const AdminCircleAction({
    super.key,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    // pastikan alpha full (biar solid)
    final bg = Color.fromARGB(255, color.red, color.green, color.blue);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias, // ✅ ripple aman
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: size, height: size),
        ),
      ),
    );
  }
}

/// Ikon putih di atas circle (ripple tetap bagus karena ignore pointer)
class AdminCircleIcon extends StatelessWidget {
  final IconData icon;
  final double iconSize;

  const AdminCircleIcon(this.icon, {super.key, this.iconSize = 22});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}

/// helper: taruh icon putih di atas AdminCircleAction
Widget adminCircleWithIcon({
  required String tooltip,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
  double size = 46,
  double iconSize = 22,
}) {
  return Stack(
    alignment: Alignment.center,
    children: [
      AdminCircleAction(
        tooltip: tooltip,
        color: color,
        onTap: onTap,
        size: size,
      ),
      AdminCircleIcon(icon, iconSize: iconSize),
    ],
  );
}
