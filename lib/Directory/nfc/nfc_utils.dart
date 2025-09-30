import 'dart:convert';
import 'dart:typed_data';

import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

class NfcUtils {
  // Bảng prefix theo chuẩn RTD URI
  static const List<String> uriPrefixes = [
    '', 'http://www.', 'https://www.', 'http://', 'https://', 'tel:', 'mailto:',
    'ftp://anonymous:anonymous@', 'ftp://ftp.', 'ftps://', 'sftp://', 'sms:',
    'smsto:', 'mms:', 'mmsto:', 'geo:', 'irc:', 'ircs:', 'urn:', 'urn:nfc:',
  ];

  static NdefRecord buildTextRecord(String text, {String lang = 'en'}) {
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

  static Uint8List _uriPayloadFromString(String url) {
    int chosenCode = 0;
    String remainder = url;

    for (int i = uriPrefixes.length - 1; i >= 0; i--) {
      final p = uriPrefixes[i];
      if (p.isNotEmpty && url.startsWith(p)) {
        chosenCode = i;
        remainder = url.substring(p.length);
        break;
      }
    }

    if (chosenCode == 0) {
      final looksLikeDomain = RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$');
      if (looksLikeDomain.hasMatch(url)) {
        chosenCode = 4; // https://
        remainder = url;
      }
    }

    final restBytes = utf8.encode(remainder);
    return Uint8List.fromList([chosenCode, ...restBytes]);
  }

  static NdefRecord buildUriRecord(String url) {
    final payload = _uriPayloadFromString(url);
    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList(utf8.encode('U')),
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  static String decodeNdefUri(Uint8List payload) {
    if (payload.isEmpty) return '';
    final prefixCode = payload[0];
    final rest = utf8.decode(payload.sublist(1), allowMalformed: true);
    final prefix =
        (prefixCode < uriPrefixes.length) ? uriPrefixes[prefixCode] : '';
    return '$prefix$rest';
  }

  static String? tryGetChipIdHex(Ndef? ndef) {
    try {
      final add = ndef?.additionalData;
      if (add != null &&
          add.containsKey('identifier') &&
          add['identifier'] is List<int>) {
        final idBytes = (add['identifier'] as List<int>);
        return idBytes
            .map((e) => e.toRadixString(16).padLeft(2, '0'))
            .join(':')
            .toUpperCase();
      }
    } catch (_) {}
    return null;
  }
}
