import 'package:flutter/material.dart';

import 'courier_home_page.dart';
import 'courier_profile_page.dart';

class CourierShellPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final int initialIndex;

  const CourierShellPage({
    super.key,
    required this.user,
    this.initialIndex = 0,
  });

  @override
  State<CourierShellPage> createState() => _CourierShellPageState();
}

class _CourierShellPageState extends State<CourierShellPage> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CourierHomePage(user: widget.user),
      CourierProfilePage(user: widget.user),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_rounded),
              label: 'Tugas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
