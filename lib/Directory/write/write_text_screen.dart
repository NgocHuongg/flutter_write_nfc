import 'package:flutter/material.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../nfc/nfc_utils.dart';


class WriteTextScreen extends StatefulWidget {
  const WriteTextScreen({super.key});
  @override
  State<WriteTextScreen> createState() => _WriteTextScreenState();
}

class _WriteTextScreenState extends State<WriteTextScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _writeText() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung cần ghi.')),
      );
      return;
    }

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

          final msg = NdefMessage(records: [NfcUtils.buildTextRecord(text)]);
          await ndef.write(message: msg);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ghi Text thành công!')),
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
      appBar: AppBar(title: const Text('Ghi NDEF Text')),
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
                    labelText: 'Nhập nội dung Text cần ghi',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null,
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _writeText, child: const Text('Write Text')),
              ],
            ),
          );
        },
      ),
    );
  }
}
