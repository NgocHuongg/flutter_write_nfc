import 'package:flutter/material.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../nfc/nfc_utils.dart';

enum SocialKind { facebook, instagram, youtube, github }

class WriteSocialScreen extends StatefulWidget {
  final SocialKind initialKind;
  const WriteSocialScreen({
    super.key,
    this.initialKind = SocialKind.facebook, // <-- nhận mạng mặc định
  });

  @override
  State<WriteSocialScreen> createState() => _WriteSocialScreenState();
}

class _WriteSocialScreenState extends State<WriteSocialScreen> {
  final TextEditingController _usernameCtrl = TextEditingController();
  late SocialKind _kind; // <-- lấy từ initialKind
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind; // <-- khởi tạo theo tab chọn từ Social Hub
  }

  String _buildUrl(String handle) {
    final h = handle.trim();
    switch (_kind) {
      case SocialKind.facebook:
        return 'https://www.facebook.com/$h';
      case SocialKind.instagram:
        return 'https://www.instagram.com/$h';
      case SocialKind.youtube:
        final y = h.startsWith('@') ? h : '@$h';
        return 'https://www.youtube.com/$y';
      case SocialKind.github:
        return 'https://github.com/$h';
    }
  }

  Future<void> _writeToTag() async {
    final handle = _usernameCtrl.text.trim();
    if (handle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập username/handle trước đã.')),
      );
      return;
    }

    final url = _buildUrl(handle);
    setState(() => _writing = true);

    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            await NfcManager.instance.stopSession(
              errorMessageIos: 'Thẻ không hỗ trợ NDEF',
            );
            if (mounted) setState(() => _writing = false);
            return;
          }
          if (!ndef.isWritable) {
            await NfcManager.instance.stopSession(
              errorMessageIos: 'Thẻ không cho phép ghi',
            );
            if (mounted) setState(() => _writing = false);
            return;
          }

          final uriRecord = NfcUtils.buildUriRecord(url);
          await ndef.write(
            message: NdefMessage(records: [uriRecord]),
          );

          await NfcManager.instance.stopSession(
            alertMessageIos: 'Đã ghi thành công',
          );

          if (!mounted) return;
          setState(() => _writing = false);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Đã ghi thành công'),
              content: Text('Đã ghi: $url'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } catch (e) {
          await NfcManager.instance.stopSession(
            errorMessageIos: 'Ghi thất bại: $e',
          );
          if (mounted) setState(() => _writing = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildUrl(
      _usernameCtrl.text.isEmpty ? 'abc' : _usernameCtrl.text.trim(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ghi URL trang cá nhân')),
      body: AbsorbPointer(
        absorbing: _writing,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const Text('Chọn mạng xã hội', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<SocialKind>(
                segments: const [
                  ButtonSegment(value: SocialKind.facebook, icon: Icon(Icons.facebook), label: Text('Facebook')),
                ButtonSegment(value: SocialKind.instagram, icon: Icon(Icons.camera_alt_outlined), label: Text('Instagram')),
                  ButtonSegment(value: SocialKind.youtube, icon: Icon(Icons.play_circle_outline), label: Text('YouTube')),
                  ButtonSegment(value: SocialKind.github, icon: Icon(Icons.code), label: Text('GitHub')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  labelText: switch (_kind) {
                    SocialKind.youtube => 'YouTube handle (vd: @abc hoặc abc)',
                    SocialKind.facebook => 'Facebook username (vd: abc)',
                    SocialKind.instagram => 'Instagram username (vd: abc)',
                    SocialKind.github => 'GitHub username (vd: abc)',
                  },
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.link),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          preview,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _writeToTag,
                icon: _writing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_writing ? 'Đang chờ chạm thẻ…' : 'Ghi vào thẻ'),
              ),
              const SizedBox(height: 8),

              const Text(
                'Mẹo: chỉ cần nhập "abc", app sẽ tự ghép URL đúng chuẩn:\n'
                '- https://www.facebook.com/abc\n'
                '- https://www.instagram.com/abc\n'
                '- https://www.youtube.com/@abc\n'
                '- https://github.com/abc',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
