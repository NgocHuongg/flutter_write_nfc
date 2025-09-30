import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:url_launcher/url_launcher.dart';

import '../nfc/nfc_utils.dart';


class ReadNfcScreen extends StatefulWidget {
  const ReadNfcScreen({super.key});
  @override
  State<ReadNfcScreen> createState() => _ReadNfcScreenState();
}

class _ReadNfcScreenState extends State<ReadNfcScreen> {
  String _chipId = '';
  String _ndefText = '';
  String _firstUrl = '';

  void _startRead() {
    NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (tag) async {
        _firstUrl = '';
        try {
          final ndef = Ndef.from(tag);
          final id = NfcUtils.tryGetChipIdHex(ndef);
          if (id != null) setState(() => _chipId = id);

          if (ndef == null || ndef.cachedMessage == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thẻ không có NDEF hoặc không đọc được.')),
              );
            }
            return;
          }

          final buffer = StringBuffer();
          for (final rec in ndef.cachedMessage!.records) {
            final tnf = rec.typeNameFormat;
            final typeStr = utf8.decode(rec.type, allowMalformed: true);

            if (tnf == TypeNameFormat.wellKnown && typeStr == 'T' && rec.payload.isNotEmpty) {
              final status = rec.payload[0];
              final langLen = status & 0x3F;
              if (rec.payload.length > 1 + langLen) {
                final textBytes = rec.payload.sublist(1 + langLen);
                buffer.writeln(utf8.decode(textBytes));
              }
            } else if (tnf == TypeNameFormat.wellKnown && typeStr == 'U' && rec.payload.isNotEmpty) {
              final url = NfcUtils.decodeNdefUri(rec.payload);
              if (url.isNotEmpty && _firstUrl.isEmpty) _firstUrl = url;
            } else {
              buffer.writeln(utf8.decode(rec.payload, allowMalformed: true));
            }
          }

          if (mounted) setState(() => _ndefText = buffer.toString().trim());
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi đọc thẻ: $e')),
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
    return FutureBuilder<bool>(
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
              const Text('ĐỌC THẺ NFC', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _startRead,
                icon: const Icon(Icons.nfc),
                label: const Text('Scan / Read'),
              ),
              const SizedBox(height: 8),
              if (_chipId.isNotEmpty)
                SelectableText('Chip ID: $_chipId', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Nội dung đọc được (NDEF):'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(_ndefText.isEmpty ? 'Chưa có dữ liệu' : _ndefText),
              ),
              const SizedBox(height: 12),
              if (_firstUrl.isNotEmpty) ...[
                const Text('URL đọc được:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(_firstUrl);
                    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Không mở được URL')),
                      );
                    }
                  },
                  child: Text(
                    _firstUrl,
                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
