import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../pubky/mentions.dart';
import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';
import 'post_card.dart';
import 'post_screen.dart';
import 'profile_sheet.dart';

/// Public discovery: what the network is talking about, for someone who
/// follows nobody yet.
///
/// Everything here comes from endpoints that need no session and no observer —
/// the hot labels, the engagement ordering and the account rankings are the
/// same for every visitor. That is what makes this tab cheap to add: it reads,
/// it writes nothing, and it cannot fail in a way that costs anything.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.nexus,
    required this.session,
  });

  final NexusClient nexus;
  final RingSession session;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final _posts = <PubkyPost>[];
  final _profiles = <String, PubkyProfile>{};
  final _quoted = <String, PubkyPost>{};

  List<HotTag> _tags = const [];
  List<PubkyProfile> _people = const [];

  /// null means the popular timeline; otherwise the label being browsed.
  String? _tag;

  bool _loading = false;
  bool _exhausted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_loadSidebars());
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

  /// Labels and suggested accounts, loaded beside the stream rather than
  /// before it: neither is worth delaying the posts for, and either can fail
  /// on its own without emptying the screen.
  Future<void> _loadSidebars() async {
    try {
      final tags = await widget.nexus.fetchHotTags(limit: 18);
      if (mounted) setState(() => _tags = tags);
    } catch (_) {
      // A missing label bar leaves the popular timeline, which is the point.
    }
    try {
      final people = await widget.nexus.fetchUserStream(
        source: UserSource.influencers,
        limit: 12,
      );
      if (mounted) setState(() => _people = people);
    } catch (_) {
      // Same: the suggestions are a bonus, not the screen.
    }
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
        source: FeedSource.all,
        // Deliberately no observer: this view is the same for everyone, and
        // personalising it would defeat the point of a discovery tab.
        tag: _tag,
        sorting: PostSorting.totalEngagement,
        limit: _pageSize,
        skip: _posts.length,
      );
      if (!mounted) return;
      setState(() {
        _posts.addAll(page);
        _exhausted = page.length < _pageSize;
        _error = null;
      });
      unawaited(_resolve(page));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Quoted posts, then every profile involved, in one batch — same shape as
  /// the feed: a failure here degrades the cards without costing the page.
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

  void _pickTag(String? tag) {
    if (tag == _tag) return;
    setState(() => _tag = tag);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final empty = _posts.isEmpty && !_loading && _error == null;

    return Column(
      children: [
        _TagBar(tags: _tags, current: _tag, onPick: _pickTag),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: ErrorPanel(message: _error!),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([_loadSidebars(), _reload()]);
            },
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              // One extra row up front for the people strip, one at the end
              // for the spinner. An empty stream still scrolls, so pull to
              // refresh keeps working when there is nothing to show.
              itemCount: 1 + (empty ? 1 : _posts.length) + (_loading ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _PeopleStrip(
                    people: _people,
                    nexus: widget.nexus,
                    session: widget.session,
                  );
                }
                final index = i - 1;
                if (empty && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
                    child: Text(
                      _tag == null ? l.discoverEmpty : l.discoverEmptyTag(_tag!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kTextMuted, height: 1.5),
                    ),
                  );
                }
                if (index >= _posts.length) {
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
                final post = _posts[index];
                final quotedUri = post.repostedUri ?? post.repliedUri;
                final quoted = quotedUri == null ? null : _quoted[quotedUri];
                return PostCard(
                  post: post,
                  nexus: widget.nexus,
                  profiles: _profiles,
                  session: widget.session,
                  quoted: quoted,
                  quotedAuthor:
                      quoted == null ? null : _profiles[quoted.author],
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PostScreen(
                        nexus: widget.nexus,
                        session: widget.session,
                        author: post.author,
                        postId: post.id,
                        known: post,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The labels the network is using most, with the popular timeline first.
class _TagBar extends StatelessWidget {
  const _TagBar({
    required this.tags,
    required this.current,
    required this.onPick,
  });

  final List<HotTag> tags;
  final String? current;
  final void Function(String?) onPick;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _TagChip(
            label: l.discoverPopular,
            selected: current == null,
            onTap: () => onPick(null),
          ),
          for (final tag in tags)
            _TagChip(
              label: '#${tag.label}',
              selected: tag.label == current,
              onTap: () => onPick(tag.label),
            ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
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
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? kAccent : kTextMuted,
                ),
              ),
            ),
          ),
        ),
      );
}

/// Accounts worth a look, as a row of avatars.
///
/// Tapping opens the same profile sheet a mention does, which is where Follow
/// already lives — discovery hands over to a screen that exists rather than
/// growing its own.
class _PeopleStrip extends StatelessWidget {
  const _PeopleStrip({
    required this.people,
    required this.nexus,
    required this.session,
  });

  final List<PubkyProfile> people;
  final NexusClient nexus;
  final RingSession session;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    final l = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Text(
            l.discoverPeople,
            style: const TextStyle(
              color: kTextMuted,
              fontSize: 12.5,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final person = people[i];
              return SizedBox(
                width: 72,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showProfileSheet(
                    context,
                    nexus: nexus,
                    pubky: person.id,
                    known: person,
                    session: session,
                  ),
                  child: Column(
                    children: [
                      ClipOval(
                        child: Image.network(
                          person.avatarUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 52,
                            height: 52,
                            color: kBackground,
                            child: const Icon(Icons.person_rounded,
                                color: kTextMuted, size: 22),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        person.name.isEmpty ? l.profileNoName : person.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11.5, height: 1.25),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
