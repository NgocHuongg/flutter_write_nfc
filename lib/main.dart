import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter NFC Demo (v4)',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('NFC Read/Write (nfc_manager v4)')),
        body: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _chipId = '';
  String _readFromNfcTag = '';
  final TextEditingController _writeController = TextEditingController();

  @override
  void dispose() {
    _writeController.dispose();
    super.dispose();
  }

  // ---- Helpers --------------------------------------------------------------

  // Tạo Text Record theo chuẩn NDEF (gói ndef_record)
  NdefRecord _buildTextRecord(String text, {String lang = 'en'}) {
    final langBytes = utf8.encode(lang);
    final textBytes = utf8.encode(text);
    // status byte: UTF-8 (bit7=0) + độ dài mã ngôn ngữ (6 bit thấp)
    final status = langBytes.length & 0x3F;
    final payload = Uint8List.fromList([status, ...langBytes, ...textBytes]);

    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,               // ✅ đúng enum
      type: Uint8List.fromList(utf8.encode('T')),            // 'T' = Text
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  void _readChipIdSafely(Ndef? ndef) {
    try {
      final add = ndef?.additionalData;
      if (add != null &&
          add.containsKey('identifier') &&
          add['identifier'] is List<int>) {
        final idBytes = (add['identifier'] as List<int>);
        final chipId = idBytes
            .map((e) => e.toRadixString(16).padLeft(2, '0'))
            .join(':')
            .toUpperCase();
        setState(() => _chipId = chipId);
      }
    } catch (_) {}
  }

  // ---- NFC: READ ------------------------------------------------------------

  void _readNfcTag() {
    NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag); // từ gói nfc_manager_ndef
          _readChipIdSafely(ndef);

          if (ndef == null || ndef.cachedMessage == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Thẻ không có NDEF hoặc không đọc được.')),
              );
            }
            return;
          }

          final buffer = StringBuffer();
          for (final rec in ndef.cachedMessage!.records) {
            // Text Record: TNF Well-known + type 'T'
            if (rec.typeNameFormat == TypeNameFormat.wellKnown &&
                utf8.decode(rec.type) == 'T' &&
                rec.payload.isNotEmpty) {
              final status = rec.payload[0];
              final langLen = status & 0x3F; // 6 bit thấp = độ dài mã ngôn ngữ
              if (rec.payload.length > 1 + langLen) {
                final textBytes = rec.payload.sublist(1 + langLen);
                buffer.writeln(utf8.decode(textBytes));
              }
            } else {
              // Các record khác: thử decode thô
              buffer.writeln(utf8.decode(rec.payload, allowMalformed: true));
            }
          }

          if (mounted) {
            setState(() => _readFromNfcTag = buffer.toString().trim());
          }
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

  // ---- NFC: WRITE -----------------------------------------------------------

  void _writeNfcTag(String text) {
    if (text.trim().isEmpty) {
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
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag); // từ gói nfc_manager_ndef
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

          final msg = NdefMessage(records: [
            _buildTextRecord(text),
          ]);                                           // ✅ records: [...]
          await ndef.write(message: msg);               // ✅ message: msg

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ghi NDEF thành công!')),
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

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: NfcManager.instance.isAvailable(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text('Error checking NFC'));
        }
        if (snap.data == false) {
          return const Center(child: Text('NFC not available'));
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const Text('ĐỌC THẺ NFC',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _readNfcTag,
                icon: const Icon(Icons.nfc),
                label: const Text('Scan / Read'),
              ),
              const SizedBox(height: 8),
              if (_chipId.isNotEmpty)
                SelectableText('Chip ID: $_chipId',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Nội dung đọc được (NDEF):'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _readFromNfcTag.isEmpty
                      ? 'Chưa có dữ liệu'
                      : _readFromNfcTag,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text('GHI THẺ NFC (NDEF Text)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _writeController,
                decoration: const InputDecoration(
                  labelText: 'Nhập nội dung cần ghi',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _writeNfcTag(_writeController.text),
                child: const Text('Write'),
              ),
            ],
          ),
        );
      },
    );
  }
}
