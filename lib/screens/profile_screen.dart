import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';

/// Order matters: these are the counts worth surfacing first, with the label
/// Nexus does not carry.
const _countLabels = <String, String>{
  'posts': 'Publications',
  'replies': 'Réponses',
  'followers': 'Abonnés',
  'following': 'Abonnements',
  'friends': 'Amis',
  'tagged': 'Fois taggé',
  'unique_tags': 'Tags distincts',
  'bookmarks': 'Favoris',
  'collections': 'Collections',
};

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.session,
    required this.profile,
    required this.busy,
    required this.error,
    required this.onRefresh,
    required this.onDisconnect,
  });

  final RingSession session;
  final PubkyProfile profile;
  final bool busy;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final err = error;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackground,
        title: const Text('Mon profil Pubky'),
        actions: [
          IconButton(
            onPressed: busy ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recharger',
          ),
          IconButton(
            onPressed: onDisconnect,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              if (err != null) ...[
                ErrorPanel(message: err),
                const SizedBox(height: 18),
              ],
              _Header(profile: profile),
              const SizedBox(height: 18),
              _PubkyCard(pubky: profile.id),
              if (profile.bio != null) ...[
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Bio'),
                      const SizedBox(height: 10),
                      Text(
                        profile.bio!,
                        style: const TextStyle(height: 1.5, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _Counts(counts: profile.counts),
              if (profile.links.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Links(links: profile.links),
              ],
              if (profile.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Tags(tags: profile.tags),
              ],
              const SizedBox(height: 14),
              _SessionCard(session: session, indexedAt: profile.indexedAt),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final PubkyProfile profile;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kAccent.withValues(alpha: 0.4), width: 2),
            ),
            child: ClipOval(
              child: Image.network(
                profile.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: kSurface,
                  alignment: Alignment.center,
                  child: Text(
                    profile.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: kAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26),
          ),
          if (profile.status != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: kBorder),
              ),
              child: Text(
                profile.status!,
                style: const TextStyle(color: kTextMuted, fontSize: 13),
              ),
            ),
          ],
        ],
      );
}

class _PubkyCard extends StatelessWidget {
  const _PubkyCard({required this.pubky});

  final String pubky;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle('Clé publique'),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: pubky));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Clé copiée')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded, size: 18, color: kTextMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              pubky,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: kAccent,
              ),
            ),
          ],
        ),
      );
}

class _Counts extends StatelessWidget {
  const _Counts({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final entries = _countLabels.entries
        .where((e) => counts.containsKey(e.key))
        .map((e) => (label: e.value, value: counts[e.key]!))
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Activité'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final e in entries)
                Container(
                  width: 96,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${e.value}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: kAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kTextMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.links});

  final List<ProfileLink> links;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Liens'),
            const SizedBox(height: 6),
            for (final link in links)
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(link.url),
                  mode: LaunchMode.externalApplication,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, size: 18, color: kTextMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              link.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

class _Tags extends StatelessWidget {
  const _Tags({required this.tags});

  final List<ProfileTag> tags;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Tags reçus'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: kBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(
                      '${tag.label} · ${tag.taggersCount}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.indexedAt});

  final RingSession session;
  final DateTime? indexedAt;

  @override
  Widget build(BuildContext context) {
    final caps = session.capabilities.isEmpty
        ? 'aucune capacité annoncée'
        : session.capabilities.join(', ');

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, size: 18, color: kAccent),
              const SizedBox(width: 8),
              const _SectionTitle('Session Ring'),
            ],
          ),
          const SizedBox(height: 12),
          _Row('Secret reçu', '${session.grantSecret.length} caractères '
              '(non affiché)'),
          _Row('Capacités', caps),
          if (indexedAt != null)
            _Row('Indexé le', _formatDate(indexedAt!)),
          const SizedBox(height: 10),
          const Text(
            'Le secret de session vaut mot de passe\u00A0: cette preuve de concept '
            'le garde en mémoire seulement, et le perd à la fermeture.',
            style: TextStyle(color: kTextMuted, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}h${two(d.minute)}';
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 108,
              child: Text(
                label,
                style: const TextStyle(color: kTextMuted, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: kTextMuted,
        ),
      );
}
