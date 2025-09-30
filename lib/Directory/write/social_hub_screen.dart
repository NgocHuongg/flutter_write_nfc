import 'package:flutter/material.dart';

import 'write_social_screen.dart';

class SocialHubScreen extends StatelessWidget {
  const SocialHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <_SocialItem>[
      _SocialItem(
        title: 'Facebook',
        subtitle: 'Ghi URL https://www.facebook.com/{username}',
        icon: Icons.facebook,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WriteSocialScreen(initialKind: SocialKind.facebook),
          ),
        ),
      ),
      _SocialItem(
        title: 'Instagram',
        subtitle: 'Ghi URL https://www.instagram.com/{username}',
        icon: Icons.camera_alt_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WriteSocialScreen(initialKind: SocialKind.instagram),
          ),
        ),
      ),
      _SocialItem(
        title: 'YouTube',
        subtitle: 'Ghi URL https://www.youtube.com/@{handle}',
        icon: Icons.play_circle_outline,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WriteSocialScreen(initialKind: SocialKind.youtube),
          ),
        ),
      ),
      _SocialItem(
        title: 'GitHub',
        subtitle: 'Ghi URL https://github.com/{username}',
        icon: Icons.code,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const WriteSocialScreen(initialKind: SocialKind.github),
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Social – Ghi URL trang cá nhân')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final t = tiles[i];
          return Card(
            child: ListTile(
              leading: Icon(t.icon),
              title: Text(t.title),
              subtitle: Text(t.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: t.onTap,
            ),
          );
        },
      ),
    );
  }
}

class _SocialItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  _SocialItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}
