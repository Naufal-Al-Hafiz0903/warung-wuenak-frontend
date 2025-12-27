import 'package:flutter/material.dart';
import 'admin_menu_item.dart';

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
    return ListView(
      children: [
        const DrawerHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Panel',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('warung_wuenak', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        for (int i = 0; i < items.length; i++)
          ListTile(
            leading: Icon(items[i].icon),
            title: Text(items[i].title),
            selected: i == selectedIndex,
            onTap: () => onSelect(i),
          ),
      ],
    );
  }
}
