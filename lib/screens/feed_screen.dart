import 'dart:async';

import 'package:flutter/material.dart';

import '../pubky/mentions.dart';
import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';
import 'compose_sheet.dart';
import 'post_content.dart';
import 'profile_sheet.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.nexus, required this.session});

  final NexusClient nexus;
  final RingSession session;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final _posts = <PubkyPost>[];

  /// Authors *and* mentioned accounts: a mention renders as a name only if its
  /// profile is in here, so both are resolved in the same batch call.
  final _profiles = <String, PubkyProfile>{};

  /// Posts published from this device, kept in front of the stream until the
  /// indexer catches up.
  final _pending = <PubkyPost>[];

  FeedSource _source = FeedSource.following;
  bool _loading = false;
  bool _exhausted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _exhausted || !_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) _loadMore();
  }

  Future<void> _reload() async {
    setState(() {
      _posts.clear();
      _exhausted = false;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _exhausted) return;
    setState(() => _loading = true);

    try {
      final page = await widget.nexus.fetchStream(
        source: _source,
        observerId: widget.session.pubky,
        limit: _pageSize,
        skip: _posts.length,
      );

      // Resolving names is a second call; a failure there must not lose the
      // posts we already have — the timeline degrades to shortened keys.
      Map<String, PubkyProfile> resolved = const {};
      final unknown = <String>{
        for (final post in page) ...{post.author, ...mentionedKeys(post.content)},
      }..removeWhere((k) => k.isEmpty || _profiles.containsKey(k));

      if (unknown.isNotEmpty) {
        try {
          resolved = await widget.nexus.fetchUsersByIds(unknown);
        } catch (_) {
          resolved = const {};
        }
      }

      if (!mounted) return;
      setState(() {
        _posts.addAll(page);
        _profiles.addAll(resolved);
        _exhausted = page.length < _pageSize;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchSource(FeedSource source) {
    if (source == _source) return;
    setState(() => _source = source);
    _reload();
  }

  Future<void> _compose() async {
    final published = await showComposeSheet(context, session: widget.session);
    if (published == null || !mounted) return;

    // Optimistic: the post is on the homeserver — the sheet read it back — but
    // Nexus has not seen it yet, so the stream cannot show it.
    setState(() {
      _pending.insert(
        0,
        PubkyPost(
          id: published.id,
          author: widget.session.pubky,
          content: published.content,
          kind: 'short',
          attachments: const [],
          counts: const {},
          tags: const [],
          indexedAt: DateTime.now(),
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Publié. Le flux le montrera dès que Nexus aura indexé.'),
      ),
    );

    // Nudge the indexer. Best effort: the post exists on the homeserver either
    // way, and the pending card stays until a reload brings back the real one.
    unawaited(widget.nexus.requestIngest(widget.session.pubky));
  }

  @override
  Widget build(BuildContext context) {
    final err = _error;
    final all = [..._pending, ..._posts];
    final empty = all.isEmpty && !_loading && err == null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _compose,
        backgroundColor: kAccent,
        foregroundColor: const Color(0xFF04120E),
        tooltip: 'Écrire un post',
        child: const Icon(Icons.edit_rounded),
      ),
      body: Column(
        children: [
          _SourceBar(current: _source, onPick: _switchSource),
          if (err != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: ErrorPanel(message: err),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: empty
                  ? _EmptyState(source: _source)
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: all.length + (_loading ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i >= all.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 22),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final post = all[i];
                        return PostCard(
                          post: post,
                          nexus: widget.nexus,
                          profiles: _profiles,
                          pending: i < _pending.length,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBar extends StatelessWidget {
  const _SourceBar({required this.current, required this.onPick});

  final FeedSource current;
  final void Function(FeedSource) onPick;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            for (final source in FeedSource.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: source.label,
                  selected: source == current,
                  onTap: () => onPick(source),
                ),
              ),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? kAccent.withValues(alpha: 0.16) : kSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? kAccent.withValues(alpha: 0.55) : kBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? kAccent : kTextMuted,
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.source});

  final FeedSource source;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(28, 60, 28, 28),
        children: [
          const Icon(Icons.inbox_rounded, size: 40, color: kTextMuted),
          const SizedBox(height: 16),
          Text(
            source == FeedSource.following
                ? "Rien à afficher. Ce flux ne montre que les comptes que tu "
                    'suis — tire vers le bas pour recharger, ou passe sur '
                    '« Global ».'
                : 'Rien à afficher pour ce flux.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kTextMuted, height: 1.5),
          ),
        ],
      );
}

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.nexus,
    required this.profiles,
    this.pending = false,
  });

  final PubkyPost post;
  final NexusClient nexus;
  final Map<String, PubkyProfile> profiles;

  /// Published from this device and not yet visible through the indexer.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final images = post.imageUrls();
    final author = profiles[post.author];
    final name = author?.name ?? _shortKey(post.author);
    final replies = post.counts['replies'] ?? 0;
    final tags = post.counts['tags'] ?? 0;
    final reposts = post.counts['reposts'] ?? 0;

    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => showProfileSheet(
                  context,
                  nexus: nexus,
                  pubky: post.author,
                  known: author,
                ),
                borderRadius: BorderRadius.circular(999),
                child: ClipOval(
                  child: Image.network(
                    '$nexusBase/static/avatar/${post.author}',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 36,
                      height: 36,
                      color: kBackground,
                      alignment: Alignment.center,
                      child: Text(
                        name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: kAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      pending
                          ? "publié à l'instant · en attente d'indexation"
                          : _relative(post.indexedAt),
                      style: TextStyle(
                        color: pending ? kAccent : kTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.kind != 'short' && post.kind != 'unknown')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kBorder),
                  ),
                  child: Text(
                    post.kind,
                    style: const TextStyle(color: kTextMuted, fontSize: 11),
                  ),
                ),
            ],
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            PostContent(
              content: post.content,
              nexus: nexus,
              knownProfiles: profiles,
            ),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: images.length == 1
                  ? _Thumb(url: images.first, height: 190)
                  : SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 170,
                            child: _Thumb(url: images[i], height: 130),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
          if (replies + tags + reposts > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (replies > 0) _Metric(Icons.mode_comment_outlined, replies),
                if (reposts > 0) _Metric(Icons.repeat_rounded, reposts),
                if (tags > 0) _Metric(Icons.sell_outlined, tags),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _shortKey(String key) =>
      key.length <= 12 ? key : '${key.substring(0, 6)}…${key.substring(key.length - 4)}';

  static String _relative(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.height});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) => Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          height: height,
          color: kBackground,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: kTextMuted),
        ),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                height: height,
                color: kBackground,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.value);

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Row(
          children: [
            Icon(icon, size: 15, color: kTextMuted),
            const SizedBox(width: 5),
            Text(
              '$value',
              style: const TextStyle(color: kTextMuted, fontSize: 12.5),
            ),
          ],
        ),
      );
}
