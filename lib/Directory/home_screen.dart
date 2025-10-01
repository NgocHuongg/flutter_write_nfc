import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'read/read_nfc_screen.dart';
import 'write/write_screen.dart';
import 'package:NFCS_Read_Write/Directory/group_info_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // READ, WRITE, OTHER
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),

        appBar: AppBar(
          backgroundColor: const Color(0xFFF0F1E3),
          title: const Text('NFCS_Read_Write'),
          centerTitle: true,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'about') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Nhóm thực hiện: Wanna.Smile (Hutech_University)\nPhiên 1.0.0',
                      ),
                    ),
                  );
                } else if (value == 'leave') {
                  // thoát app
                  SystemNavigator.pop();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'about', child: Text('Giới thiệu')),
                PopupMenuItem(value: 'leave', child: Text('Thoát')),
              ],
            ),
          ],

          // Nếu muốn đặt TabBar lên AppBar (trên cùng), bỏ comment 3 dòng dưới và
          // xoá phần bottomNavigationBar ở dưới:
          // bottom: const TabBar(
          //   tabs: [Tab(icon: Icon(Icons.nfc)), Tab(icon: Icon(Icons.edit)), Tab(icon: Icon(Icons.settings))],
          // ),
        ),

        // Nội dung từng tab
        body: const TabBarView(
          children: [
            // Tab 1: READ NFC
            ReadNfcScreen(),
            // Tab 2: WRITE NFC (hub điều hướng ghi text/URL)
            WriteScreen(),
            // Tab 3: OTHER / SETTINGS
            GroupInfoScreen(),
          ],
        ),

        // TabBar đặt dưới cùng
        bottomNavigationBar: const Material(
          color: Colors.white, // cần Material để indicator vẽ đúng
          child: TabBar(
            indicatorColor: Colors.orange,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.nfc), text: 'Đọc'),
              Tab(icon: Icon(Icons.edit), text: 'Ghi'),
              Tab(icon: Icon(Icons.settings), text: 'Khác'),
            ],
          ),
        ),
      ),
    );
  }
}
