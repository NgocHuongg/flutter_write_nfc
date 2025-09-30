import 'package:flutter/material.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../nfc/nfc_utils.dart';


class WriteUrlScreen extends StatefulWidget {
  const WriteUrlScreen({super.key});
  @override
  State<WriteUrlScreen> createState() => _WriteUrlScreenState();
}

class _WriteUrlScreenState extends State<WriteUrlScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _writeUrl() {
    String input = _ctrl.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập URL cần ghi.')),
      );
      return;
    }

    // Chuẩn hoá: thêm https:// nếu thiếu scheme
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*:').hasMatch(input)) {
      input = 'https://$input';
    }

    Uri? uri;
    try {
      uri = Uri.parse(input);
    } catch (_) {}
    if (uri == null || !(uri.hasScheme && (uri.host.isNotEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL không hợp lệ.')),
      );
      return;
    }

    final urlForRecord = uri.toString();

    NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thẻ không hỗ trợ NDEF.')),
            );
            return;
          }
          if (!ndef.isWritable) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thẻ bị khóa hoặc không ghi được.')),
            );
            return;
          }

          final msg = NdefMessage(records: [NfcUtils.buildUriRecord(urlForRecord)]);
          await ndef.write(message: msg);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ghi URL thành công!')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi khi ghi thẻ: $e')),
            );
          }
        } finally {
          NfcManager.instance.stopSession();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ghi NDEF URL')),
      body: FutureBuilder<bool>(
        future: NfcManager.instance.isAvailable(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.data != true) {
            return const Center(child: Text('Thiết bị không hỗ trợ/không bật NFC'));
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Nhập URL cần ghi',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _writeUrl,
                  icon: const Icon(Icons.link),
                  label: const Text('Write URL'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
