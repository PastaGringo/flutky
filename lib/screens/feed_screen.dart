import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../pubky/mentions.dart';
import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../settings/feed_preferences.dart';
import '../theme.dart';
import 'compose_sheet.dart';
import 'post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.nexus,
    required this.session,
    required this.preferences,
  });

  final NexusClient nexus;
  final RingSession session;
  final FeedPreferences preferences;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final _posts = <PubkyPost>[];

  /// Authors, mentioned accounts and quoted authors — a name only appears if
  /// its profile is in here, so all three are resolved in the same batch.
  final _profiles = <String, PubkyProfile>{};

  /// Posts that others reposted or replied to, keyed by their `pubky://` URI.
  final _quoted = <String, PubkyPost>{};

  /// Published from this device, kept in front of the stream until the indexer
  /// catches up.
  final _pending = <PubkyPost>[];

  FeedSource _source = FeedSource.following;
  bool _loading = false;
  bool _exhausted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.preferences.addListener(_onPreferencesChanged);
    _reload();
  }

  void _onPreferencesChanged() {
    // Only the following feed is affected; reloading the others would throw
    // away their scroll position for nothing.
    if (_source == FeedSource.following) _reload();
  }

  @override
  void dispose() {
    widget.preferences.removeListener(_onPreferencesChanged);
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
      var page = await widget.nexus.fetchStream(
        source: _source,
        observerId: widget.session.pubky,
        limit: _pageSize,
        skip: _posts.length,
      );

      // Nexus's `following` stream covers the accounts you follow, never you.
      // Folding your own posts in means a second read, merged by date — the
      // API has no flag for it.
      if (_source == FeedSource.following &&
          widget.preferences.includeOwnPosts) {
        page = await _mergeOwnPosts(page);
      }

      if (!mounted) return;
      setState(() {
        _posts.addAll(page);
        _exhausted = page.length < _pageSize;
        _error = null;
      });

      // Names and quoted posts load after the page is on screen: a failure
      // there degrades the cards, it does not cost us the timeline.
      unawaited(_resolve(page));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Merges the user's own posts into a page of the following feed.
  ///
  /// Both streams are ordered newest first, so the merge is a sort by date;
  /// the page is then trimmed back to its size, and the offset of the next
  /// request stays that of the following feed alone. A post already present
  /// is not added twice — reposting yourself would otherwise duplicate it.
  Future<List<PubkyPost>> _mergeOwnPosts(List<PubkyPost> page) async {
    if (page.isEmpty) return page;
    try {
      final mine = await widget.nexus.fetchStream(
        source: FeedSource.author,
        authorId: widget.session.pubky,
        observerId: widget.session.pubky,
        limit: _pageSize,
        skip: 0,
      );

      final oldest = page.last.indexedAt;
      final seen = page.map((p) => p.id).toSet();
      final merged = [
        ...page,
        ...mine.where((p) =>
            !seen.contains(p.id) &&
            (oldest == null ||
                p.indexedAt == null ||
                !p.indexedAt!.isBefore(oldest))),
      ]..sort((a, b) => (b.indexedAt ?? DateTime(0))
          .compareTo(a.indexedAt ?? DateTime(0)));

      return merged.take(page.length).toList();
    } catch (_) {
      // The following feed is what matters; losing the merge is not worth
      // losing the page.
      return page;
    }
  }

  /// Fetches the quoted posts, then every profile involved — authors,
  /// mentions, and the authors of the quoted posts — in a single batch call.
  Future<void> _resolve(List<PubkyPost> page) async {
    final quotedUris = page
        .map((p) => p.repostedUri ?? p.repliedUri)
        .whereType<String>()
        .where((uri) => !_quoted.containsKey(uri))
        .toSet();

    final fetched = <String, PubkyPost>{};
    for (final uri in quotedUris) {
      final parts = PubkyPost.parsePostUri(uri);
      if (parts == null) continue;
      final post = await widget.nexus.fetchPost(parts.author, parts.id);
      if (post != null) fetched[uri] = post;
    }

    final keys = <String>{
      for (final p in page) ...{p.author, ...mentionedKeys(p.content)},
      for (final p in fetched.values) ...{p.author, ...mentionedKeys(p.content)},
    }..removeWhere((k) => k.isEmpty || _profiles.containsKey(k));

    Map<String, PubkyProfile> resolved = const {};
    if (keys.isNotEmpty) {
      try {
        resolved = await widget.nexus.fetchUsersByIds(keys);
      } catch (_) {
        resolved = const {};
      }
    }

    if (!mounted) return;
    setState(() {
      _quoted.addAll(fetched);
      _profiles.addAll(resolved);
    });
  }

  void _switchSource(FeedSource source) {
    if (source == _source) return;
    setState(() => _source = source);
    _reload();
  }

  Future<void> _compose({String initialContent = ''}) async {
    final published = await showComposeSheet(
      context,
      session: widget.session,
      nexus: widget.nexus,
      // The interface language is the likeliest target for a translation, and
      // reading it here avoids threading the controller down another screen.
      uiLanguage: Localizations.localeOf(context).languageCode,
      deepLKey: widget.preferences.deepLKey,
      initialContent: initialContent,
    );
    if (published == null || !mounted) return;

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
      SnackBar(content: Text(L10n.of(context).feedPublished)),
    );

    // Nudge the indexer. Best effort: the post exists on the homeserver either
    // way, and the pending card stays until a reload brings back the real one.
    unawaited(widget.nexus.requestIngest(widget.session.pubky));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final all = [..._pending, ..._posts];
    final empty = all.isEmpty && !_loading && _error == null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Asking the AI is just a post that mentions it: the shortcut only
          // pre-fills the mention, the rest of the flow is unchanged.
          FloatingActionButton.extended(
            heroTag: 'askJeb',
            onPressed: () => _compose(initialContent: 'pubky$jebPubky '),
            backgroundColor: kSurface,
            foregroundColor: kAccent,
            icon: const Icon(Icons.smart_toy_outlined, size: 19),
            label: Text(l.composeAskJeb),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'compose',
            onPressed: _compose,
            backgroundColor: kAccent,
            foregroundColor: const Color(0xFF04120E),
            tooltip: l.feedComposeTooltip,
            child: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _SourceBar(current: _source, onPick: _switchSource),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: ErrorPanel(message: _error!),
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
                        final quotedUri = post.repostedUri ?? post.repliedUri;
                        final quoted =
                            quotedUri == null ? null : _quoted[quotedUri];
                        return PostCard(
                          post: post,
                          nexus: widget.nexus,
                          profiles: _profiles,
                          session: widget.session,
                          quoted: quoted,
                          quotedAuthor:
                              quoted == null ? null : _profiles[quoted.author],
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

  /// The tabs offered, in order. `author` is deliberately absent: it exists
  /// only to fold the user's own posts into the following feed.
  static const tabs = [
    FeedSource.following,
    FeedSource.friends,
    FeedSource.all,
    FeedSource.bookmarks,
  ];

  static String label(L10n l, FeedSource source) => switch (source) {
        FeedSource.following => l.feedSourceFollowing,
        FeedSource.friends => l.feedSourceFriends,
        FeedSource.all => l.feedSourceAll,
        FeedSource.bookmarks => l.feedSourceBookmarks,
        FeedSource.author => l.countPosts,
      };

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final source in _SourceBar.tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Chip(
                label: label(l, source),
                selected: source == current,
                onTap: () => onPick(source),
              ),
            ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 28),
      children: [
        const Icon(Icons.inbox_rounded, size: 40, color: kTextMuted),
        const SizedBox(height: 16),
        Text(
          source == FeedSource.following
              ? l.feedEmptyFollowing
              : l.feedEmptyOther,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kTextMuted, height: 1.5),
        ),
      ],
    );
  }
}
