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
        extendBody: true,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: const Color(0x1A000000)),
                ),
                child: BottomNavigationBar(
                  currentIndex: _index,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: const Color(0xFF6D5EF6),
                  unselectedItemColor: Colors.black54,
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
            ),
          ),
        ),
      ),
    );
  }
}
