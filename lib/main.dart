import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String _readUrl = '';

  final TextEditingController _writeTextController = TextEditingController();
  final TextEditingController _writeUrlController = TextEditingController();

  @override
  void dispose() {
    _writeTextController.dispose();
    _writeUrlController.dispose();
    super.dispose();
  }

  // ==== Helpers ===============================================================

  // Bảng prefix cho RTD URI (theo chuẩn NDEF – gồm các prefix phổ biến)
  static const List<String> _uriPrefixes = [
    '', // 0x00: no prefix
    'http://www.', // 0x01
    'https://www.', // 0x02
    'http://', // 0x03
    'https://', // 0x04
    'tel:', // 0x05
    'mailto:', // 0x06
    'ftp://anonymous:anonymous@', // 0x07
    'ftp://ftp.', // 0x08
    'ftps://', // 0x09
    'sftp://', // 0x0A
    'sms:', // 0x0B
    'smsto:', // 0x0C
    'mms:', // 0x0D
    'mmsto:', // 0x0E
    'geo:', // 0x0F
    'irc:', // 0x10
    'ircs:', // 0x11
    'urn:', // 0x12
    'urn:nfc:', // 0x13
  ];

  // Tạo Text Record (RTD Text – type 'T')
  NdefRecord _buildTextRecord(String text, {String lang = 'en'}) {
    final langBytes = utf8.encode(lang);
    final textBytes = utf8.encode(text);
    final status = langBytes.length & 0x3F; // UTF-8 + len(lang)
    final payload = Uint8List.fromList([status, ...langBytes, ...textBytes]);

    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList(utf8.encode('T')),
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  // Chọn prefix code & phần còn lại cho 1 URL, trả về payload cho RTD URI (type 'U')
  Uint8List _uriPayloadFromString(String url) {
    // Tìm prefix khớp dài nhất (max compression)
    int chosenCode = 0;
    String remainder = url;

    for (int i = _uriPrefixes.length - 1; i >= 0; i--) {
      final p = _uriPrefixes[i];
      if (p.isNotEmpty && url.startsWith(p)) {
        chosenCode = i;
        remainder = url.substring(p.length);
        break;
      }
    }

    // Nếu không khớp prefix chuẩn, thử tối thiểu: thêm "https://" để hợp lệ
    if (chosenCode == 0) {
      // nếu url giống dạng domain.com/... thì thêm https:// để tránh lỗi
      final looksLikeDomain = RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$');
      if (looksLikeDomain.hasMatch(url)) {
        chosenCode = 4; // 'https://'
        remainder = url;
      }
    }

    final restBytes = utf8.encode(remainder);
    return Uint8List.fromList([chosenCode, ...restBytes]);
  }

  // Tạo URI Record (RTD URI – type 'U') từ string URL
  NdefRecord _buildUriRecord(String url) {
    final payload = _uriPayloadFromString(url);
    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList(utf8.encode('U')),
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  // Decode RTD URI payload về string URL
  String _decodeNdefUri(Uint8List payload) {
    if (payload.isEmpty) return '';
    final prefixCode = payload[0];
    final rest = utf8.decode(payload.sublist(1), allowMalformed: true);
    final prefix =
        (prefixCode < _uriPrefixes.length) ? _uriPrefixes[prefixCode] : '';
    return '$prefix$rest';
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

  // ==== NFC: READ =============================================================

  void _readNfcTag() {
    NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        _readUrl = ''; // reset trước khi đọc
        try {
          final ndef = Ndef.from(tag);
          _readChipIdSafely(ndef);

          if (ndef == null || ndef.cachedMessage == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thẻ không có NDEF hoặc không đọc được.'),
                ),
              );
            }
            return;
          }

          final buffer = StringBuffer();
          for (final rec in ndef.cachedMessage!.records) {
            // Text 'T'
            if (rec.typeNameFormat == TypeNameFormat.wellKnown &&
                utf8.decode(rec.type) == 'T' &&
                rec.payload.isNotEmpty) {
              final status = rec.payload[0];
              final langLen = status & 0x3F;
              if (rec.payload.length > 1 + langLen) {
                final textBytes = rec.payload.sublist(1 + langLen);
                buffer.writeln(utf8.decode(textBytes));
              }
            }
            // URI 'U'
            else if (rec.typeNameFormat == TypeNameFormat.wellKnown &&
                utf8.decode(rec.type) == 'U' &&
                rec.payload.isNotEmpty) {
              final url = _decodeNdefUri(rec.payload);
              if (url.isNotEmpty && _readUrl.isEmpty) {
                _readUrl = url; // lấy URL đầu tiên
              }
            }
            // Khác: decode thô
            else {
              buffer.writeln(
                  utf8.decode(rec.payload, allowMalformed: true));
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

  // ==== NFC: WRITE TEXT =======================================================

  void _writeTextToTag(String text) {
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

          final msg = NdefMessage(records: [
            _buildTextRecord(text),
          ]);
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

  // ==== NFC: WRITE URL ========================================================

  void _writeUrlToTag(String rawUrl) {
    final input = rawUrl.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập URL cần ghi.')),
      );
      return;
    }

    // Chuẩn hoá tối thiểu: nếu thiếu scheme, thêm https:// để Uri.parse hợp lệ
    String normalized = input;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*:').hasMatch(input);
    if (!hasScheme) {
      normalized = 'https://$input';
    }

    // Kiểm tra hợp lệ cơ bản
    Uri? uri;
    try {
      uri = Uri.parse(normalized);
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
      onDiscovered: (NfcTag tag) async {
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

          final msg = NdefMessage(records: [
            _buildUriRecord(urlForRecord),
          ]);
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

  // ==== UI ===================================================================

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
              const SizedBox(height: 12),
              if (_readUrl.isNotEmpty) ...[
                const Text('URL đọc được:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(_readUrl);
                    if (!await launchUrl(uri,
                        mode: LaunchMode.externalApplication)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Không mở được URL')),
                      );
                    }
                  },
                  child: Text(
                    _readUrl,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              // ==== WRITE TEXT =================================================
              const Text('GHI THẺ NFC (NDEF Text)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _writeTextController,
                decoration: const InputDecoration(
                  labelText: 'Nhập nội dung Text cần ghi',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _writeTextToTag(_writeTextController.text),
                child: const Text('Write Text'),
              ),

              const SizedBox(height: 24),

              // ==== WRITE URL ==================================================
              const Text('GHI THẺ NFC (NDEF URL)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _writeUrlController,
                decoration: const InputDecoration(
                  labelText: 'Nhập URL cần ghi',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _writeUrlToTag(_writeUrlController.text),
                icon: const Icon(Icons.link),
                label: const Text('Write URL'),
              ),
            ],
          ),
        );
      },
    );
  }
}
