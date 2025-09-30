import 'package:flutter/material.dart';

import 'read/read_nfc_screen.dart';
import 'write/write_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _pages = const [
    ReadNfcScreen(),
    WriteScreen(), // hub ghi: điều hướng sang ghi text / ghi url
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC Read/Write (nfc_manager v4)')),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.nfc), label: 'Đọc'),
          NavigationDestination(icon: Icon(Icons.edit), label: 'Ghi'),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
