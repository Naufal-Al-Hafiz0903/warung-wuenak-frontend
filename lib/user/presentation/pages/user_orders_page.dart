import 'package:flutter/material.dart';
import '../../../features/user/pages/user_orders_page.dart' as v2;

class UserOrdersPage extends StatelessWidget {
  final Map<String, dynamic> user;
  const UserOrdersPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return const v2.UserOrdersPage();
  }
}
