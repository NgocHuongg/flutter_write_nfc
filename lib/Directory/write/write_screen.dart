import 'package:flutter/material.dart';

import 'write_text_screen.dart';
import 'write_url_screen.dart';

class WriteScreen extends StatelessWidget {
  const WriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text('GHI THẺ NFC', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Ghi NDEF Text'),
              subtitle: const Text('Viết nội dung văn bản vào thẻ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WriteTextScreen()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Ghi NDEF URL'),
              subtitle: const Text('Viết đường dẫn (URI) vào thẻ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WriteUrlScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
