import 'package:flutter/material.dart';

class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final members = <Map<String, String>>[
      {
        "name": "Nguyễn Lê Trọng Tín",
        "id": "MSSV: 2387700068",
        "avatar": "assets/avatars/1.png"
      },
      {
        "name": "Đoàn Xuân Hướng",
        "id": "MSSV: 2387700025",
        "avatar": "assets/avatars/4.png"
      },
      {
        "name": "Đỗ Minh Khoa",
        "id": "MSSV: 2387700031",
        "avatar": "assets/avatars/2.png"
      },
      {
        "name": "Lê Gia Minh",
        "id": "MSSV: 2387700043",
        "avatar": "assets/avatars/3.jpg"
      },
      {
        "name": "Nguyễn Ngọc Khôi Nguyên",
        "id": "MSSV: 2387700046",
        "avatar": "assets/avatars/5.png"
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Thông tin nhóm',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text('Tên đề tài: Đọc ghi nội dung thẻ NFC'),
        const SizedBox(height: 8),
        const Text('Giảng viên hướng dẫn: Nguyễn Mạnh Hùng'),
        const Divider(height: 24),
        const Text('Thành viên:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...members.map((m) => Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: AssetImage(m["avatar"]!), // hoặc NetworkImage
              radius: 24,
            ),
            title: Text(m["name"]!),
            subtitle: Text(m["id"]!),
          ),
        )),
        const SizedBox(height: 16),
        const Text('Ghi chú: Cập nhật thông tin thực tế của nhóm.'),
      ],
    );
  }
}
