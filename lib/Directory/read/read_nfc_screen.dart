import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:url_launcher/url_launcher.dart';

class ReadNfcScreen extends StatefulWidget {
  const ReadNfcScreen({super.key});

  @override
  State<ReadNfcScreen> createState() => _ReadNfcScreenState();
}

class _ReadNfcScreenState extends State<ReadNfcScreen> {
  String _nfcData = "Chưa đọc dữ liệu nào";

  // ====== URI prefix map (chuẩn NDEF URI RTD) ======
  static const Map<int, String> _uriPrefixMap = {
    0x00: "",
    0x01: "http://www.",
    0x02: "https://www.",
    0x03: "http://",
    0x04: "https://",
    0x05: "tel:",
    0x06: "mailto:",
    0x07: "ftp://anonymous:anonymous@",
    0x08: "ftp://ftp.",
    0x09: "ftps://",
    0x0A: "sftp://",
    0x0B: "smb://",
    0x0C: "nfs://",
    0x0D: "ftp://",
    0x0E: "dav://",
    0x0F: "news:",
    0x10: "telnet://",
    0x11: "imap:",
    0x12: "rtsp://",
    0x13: "urn:",
    0x14: "pop:",
    0x15: "sip:",
    0x16: "sips:",
    0x17: "tftp:",
    0x18: "btspp://",
    0x19: "btl2cap://",
    0x1A: "btgoep://",
    0x1B: "tcpobex://",
    0x1C: "irdaobex://",
    0x1D: "file://",
    0x1E: "urn:epc:id:",
    0x1F: "urn:epc:tag:",
    0x20: "urn:epc:pat:",
    0x21: "urn:epc:raw:",
    0x22: "urn:epc:",
    0x23: "urn:nfc:",
  };

  // ====== Helpers: decode NDEF ======

  String _decodeTextRecord(Uint8List payload) {
    if (payload.isEmpty) return "";
    final status = payload[0];
    final langLen = status & 0x3F; // lower 6 bits = Language Code length
    final start = 1 + langLen;
    if (start > payload.length) return "";
    return utf8.decode(payload.sublist(start));
  }

  String _decodeUriRecord(Uint8List payload) {
    if (payload.isEmpty) return "";
    final prefixCode = payload[0];
    final prefix = _uriPrefixMap[prefixCode] ?? "";
    final rest = utf8.decode(payload.sublist(1));
    return "$prefix$rest";
  }

  // ====== URL cleaning & launching ======

  // Loại bỏ BOM + ký tự điều khiển/invisible
  String _stripControls(String s) {
    final cleaned = s
        .replaceAll('\uFEFF', '') // BOM
        .replaceAll(RegExp(r'[\u0000-\u0009]'), '') // NUL..TAB
        .replaceAll(RegExp(r'[\u000B-\u001F]'), '') // VT..US
        .replaceAll('\u007F', ''); // DEL
    return cleaned.trim();
  }

  // Chuẩn hoá URL: thêm scheme, sửa lỗi chính tả phổ biến
  String _normalizeUrl(String raw) {
    String url = _stripControls(raw);

    // Sửa thiếu // sau http(s):
    url = url.replaceFirst(RegExp(r'^https:(?!//)', caseSensitive: false), 'https://');
    url = url.replaceFirst(RegExp(r'^http:(?!//)', caseSensitive: false), 'http://');

    // Nếu thiếu scheme mà có dạng domain
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.startsWith('www.')) {
        url = 'https://$url';
      } else if (RegExp(r'^[a-z0-9.-]+\.[a-z]{2,}', caseSensitive: false).hasMatch(url)) {
        url = 'https://$url';
      }
    }

    // Sửa 1 số host phổ biến
    url = url.replaceFirst(RegExp(r'^(https?://)w\.youtube\.com', caseSensitive: false), r'$1www.youtube.com');
    if (url.contains('youtube.com') && !url.contains('://www.')) {
      url = url.replaceFirst('://youtube.com', '://www.youtube.com');
    }
    for (final host in ['facebook.com', 'instagram.com', 'github.com']) {
      final pat = RegExp('://$host', caseSensitive: false);
      if (pat.hasMatch(url)) url = url.replaceFirst(pat, '://www.$host');
    }

    return url;
  }

  Future<void> _openLink(String rawUrl) async {
    final normalized = _normalizeUrl(rawUrl);
    final uri = Uri.tryParse(normalized);

    if (uri == null) {
      _toast("URL không hợp lệ sau khi chuẩn hoá:\n$normalized");
      return;
    }

    // Thử mở app ngoài trước
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }

    // Nếu không mở được app ngoài, thử chế độ mặc định (trình duyệt)
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        launched = false;
      }
    }

    if (!launched) {
      _toast("Không tìm thấy ứng dụng để mở:\n$normalized\n"
          "• Nếu đang dùng emulator: hãy cài Chrome/Browser.\n"
          "• Hãy thử trên máy Android thật.");
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ====== NFC session ======

  Future<void> _startNfcSession() async {
    final isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      setState(() => _nfcData = "Thiết bị không hỗ trợ NFC");
      return;
    }

    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            setState(() => _nfcData = "Thẻ không hỗ trợ NDEF");
            return;
          }

          final message = ndef.cachedMessage;
          if (message == null || message.records.isEmpty) {
            setState(() => _nfcData = "Không có record nào trong thẻ");
            return;
          }

          // Duyệt qua record để lấy nội dung. Nếu là URL -> mở ngay.
          for (final r in message.records) {
            final typeStr = String.fromCharCodes(r.type); // 'T' (0x54) hoặc 'U' (0x55)
            String? content;

            if (typeStr == 'U') {
              content = _decodeUriRecord(r.payload);
            } else if (typeStr == 'T') {
              content = _decodeTextRecord(r.payload);
            } else {
              // Fallback: cố gắng decode thẳng
              try {
                content = utf8.decode(r.payload);
              } catch (_) {
                content = null;
              }
            }

            if (content == null || content.isEmpty) continue;

            setState(() => _nfcData = content ?? "");

            // Nếu giống URL -> mở app ngoài / trình duyệt
            final looksLikeUrl = RegExp(
              r'^(https?:\/\/|www\.|[a-z0-9.-]+\.[a-z]{2,})',
              caseSensitive: false,
            ).hasMatch(content.trim());

            if (looksLikeUrl) {
              await _openLink(content);
              break; // mở 1 link là đủ
            }
          }
        } catch (e) {
          setState(() => _nfcData = "Lỗi khi đọc thẻ: $e");
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );
  }

  // ====== UI ======

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Đọc thẻ NFC"),
        backgroundColor: const Color(0xFFF0F1E3),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _startNfcSession,
              icon: const Icon(Icons.nfc),
              label: const Text("Bắt đầu quét thẻ"),
            ),
            const SizedBox(height: 20),
            const Text(
              "Dữ liệu đọc được:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            SelectableText(
              _nfcData,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "Mẹo: Nếu thẻ lưu thiếu 'https://', app sẽ tự sửa và vẫn mở đúng ứng dụng.",
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
