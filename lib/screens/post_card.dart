import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../pubky/homeserver.dart';
import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../pubky/tags.dart';
import '../theme.dart';
import '../pubky/mentions.dart';
import '../pubky/translation.dart';
import '../settings/preferences_scope.dart';
import 'compose_sheet.dart';
import 'image_viewer.dart';
import 'post_content.dart';
import 'post_screen.dart';
import 'profile_sheet.dart';

/// One post in the timeline, and everything one can do to it.
///
/// A repost is an ordinary post pointing at another. With text of its own it
/// reads as a quote — the quoted post goes in a framed block underneath; with
/// no text, it is a plain share and the original takes the whole card, under a
/// discreet "reposted" line.
///
/// A reply points at its parent the same way on the wire, but says so with an
/// arrow rather than a frame: the answer is what the card is about, and
/// repeating the post it answers under every reply turned the feed into a hall
/// of mirrors.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.nexus,
    required this.profiles,
    this.session,
    this.quoted,
    this.quotedAuthor,
    this.pending = false,
    this.onOpen,
    this.hideQuote = false,
    this.onChanged,
  });

  final PubkyPost post;
  final NexusClient nexus;
  final Map<String, PubkyProfile> profiles;

  /// Lets the profile sheet offer Follow, and the card write — reply, repost,
  /// quote, tag. Absent, it stays strictly read-only.
  final RingSession? session;

  /// The post this one reposts or replies to, once loaded.
  final PubkyPost? quoted;
  final PubkyProfile? quotedAuthor;

  /// Published from this device and not yet visible through the indexer.
  final bool pending;

  /// Opens the thread. Absent inside the thread itself, where tapping a card
  /// to reach the screen you are already on is a dead end.
  final VoidCallback? onOpen;

  /// Hides what the post points at — the quoted block of a repost, the arrow
  /// of a reply.
  ///
  /// Inside a thread every reply answers the post displayed above it, so
  /// naming it under each one would repeat the screen.
  final bool hideQuote;

  /// Something was published from this card. The screen around it decides what
  /// that is worth: a thread reloads its replies, a timeline usually does
  /// nothing and lets the card refresh its own counters.
  final VoidCallback? onChanged;

  @override
  State<PostCard> createState() => _PostCardState();

  /// Falls back to a shortened key rather than showing 52 characters, and to a
  /// translated placeholder when even that is missing.
  static String displayName(PubkyProfile? profile, String key, L10n l) {
    final name = profile?.name;
    if (name != null && name.isNotEmpty) return name;
    if (key.length <= 12) return key.isEmpty ? l.profileNoName : key;
    return '${key.substring(0, 6)}…${key.substring(key.length - 4)}';
  }

  static String relativeTime(L10n l, DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return l.timeJustNow;
    if (diff.inMinutes < 60) return l.timeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l.timeHours(diff.inHours);
    if (diff.inDays < 30) return l.timeDays(diff.inDays);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

class _PostCardState extends State<PostCard> {
  /// The translated text, once it exists. Kept beside the original rather than
  /// replacing it: a translation is a reading aid, and the words the author
  /// actually wrote must stay one tap away.
  String? _translated;
  bool _translating = false;

  /// The post as the indexer serves it once something has been written here.
  /// Nexus lags the homeserver by a second or two, so it arrives late — until
  /// then the card shows what it was given, corrected by [_added] and
  /// [_removed].
  PubkyPost? _fresh;

  /// Labels applied and removed from this device, kept until the indexer
  /// agrees. Without them a tag disappears for the seconds Nexus takes to see
  /// it, which reads exactly like a write that failed.
  final _added = <String>{};
  final _removed = <String>{};

  /// A write is in flight. One at a time: tapping a chip twice while the first
  /// PUT travels would race the second against it.
  bool _busy = false;

  /// The post being answered, folded away. Shown by default — reading an
  /// answer without the question is the thing the thread rail exists to fix —
  /// but a long parent above every reply is a lot of feed, so it folds.
  bool _parentCollapsed = false;

  PubkyPost get post => _fresh ?? widget.post;

  /// A post the indexer has not seen has no thread and no counters yet, and a
  /// card without a session is a reader's view.
  bool get _canAct => widget.session != null && !widget.pending;

  Future<void> _translate() async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_translated != null) {
      setState(() => _translated = null);
      return;
    }

    final key = PreferencesScope.maybeOf(context)?.deepLKey ?? '';
    if (key.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.composeTranslateNoKey)),
      );
      return;
    }

    setState(() => _translating = true);
    final translator = Translator(deepLKey: key);
    try {
      final out = await translator.translateProtecting(
        post.content,
        // Detected server-side: reading someone else's post, you do not know
        // what language it is in — that is the whole reason for the button.
        from: autoDetect,
        to: Localizations.localeOf(context).languageCode,
        protect: RegExp('$mentionPattern|$linkPattern'),
      );
      if (mounted) setState(() => _translated = out);
    } on TranslationRefused catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(e.badKey
              ? l.composeTranslateBadKey
              : e.quotaExhausted
                  ? l.composeTranslateQuota
                  : l.composeTranslateFailed(e.message)),
        ));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.composeTranslateFailed('$e'))),
        );
      }
    } finally {
      translator.close();
      if (mounted) setState(() => _translating = false);
    }
  }

  /// Reads the post back from the indexer after something was written to it.
  ///
  /// Twice, because indexing lands a second or two after the write and the
  /// first look usually comes back unchanged — the same two-step the thread
  /// screen uses after a reply, for the same reason.
  Future<void> _refreshSoon() async {
    for (final delay in const [Duration(seconds: 3), Duration(seconds: 6)]) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
      final fresh = await widget.nexus.fetchPost(
        post.author,
        post.id,
        viewerId: widget.session?.pubky,
      );
      if (fresh == null || !mounted) continue;
      setState(() {
        _fresh = fresh;
        // A local correction is dropped only where the indexer now agrees
        // with it; anything still in flight keeps its optimistic state.
        _added.removeWhere((label) =>
            fresh.tags.any((t) => t.label == label && t.appliedByViewer));
        _removed.removeWhere((label) =>
            !fresh.tags.any((t) => t.label == label && t.appliedByViewer));
      });
    }
  }

  Future<void> _reply() async {
    final session = widget.session;
    if (session == null) return;
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final published = await showComposeSheet(
      context,
      session: session,
      nexus: widget.nexus,
      uiLanguage: Localizations.localeOf(context).languageCode,
      deepLKey: PreferencesScope.maybeOf(context)?.deepLKey ?? '',
      parent: post.uri,
      // Answering something you cannot re-read while writing is guesswork.
      quotedPost: post,
      quotedAuthor: widget.profiles[post.author],
    );
    if (published == null) return;

    messenger.showSnackBar(SnackBar(content: Text(l.postReplyPublished)));
    unawaited(widget.nexus.requestIngest(session.pubky));
    widget.onChanged?.call();
    unawaited(_refreshSoon());
  }

  /// Repost or quote — the same write, told apart by whether it carries words.
  Future<void> _share() async {
    if (!_canAct) return;
    final choice = await showModalBottomSheet<_ShareChoice>(
      context: context,
      backgroundColor: kSurface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ShareSheet(),
    );
    if (choice == null || !mounted) return;
    if (choice == _ShareChoice.repost) {
      await _repost();
    } else {
      await _quote();
    }
  }

  Future<void> _repost() async {
    final session = widget.session;
    if (session == null || _busy) return;
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    final client = HomeserverClient(session: session);
    try {
      await client.repost(post.uri);
      messenger.showSnackBar(SnackBar(content: Text(l.postReposted)));
      unawaited(widget.nexus.requestIngest(session.pubky));
      widget.onChanged?.call();
      unawaited(_refreshSoon());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quote() async {
    final session = widget.session;
    if (session == null) return;
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final published = await showComposeSheet(
      context,
      session: session,
      nexus: widget.nexus,
      uiLanguage: Localizations.localeOf(context).languageCode,
      deepLKey: PreferencesScope.maybeOf(context)?.deepLKey ?? '',
      quote: post.uri,
      quotedPost: post,
      quotedAuthor: widget.profiles[post.author],
    );
    if (published == null) return;

    messenger.showSnackBar(SnackBar(content: Text(l.postReposted)));
    unawaited(widget.nexus.requestIngest(session.pubky));
    widget.onChanged?.call();
    unawaited(_refreshSoon());
  }

  /// Applies a label, or removes it when this account already applied it.
  Future<void> _toggleTag(String label) async {
    final session = widget.session;
    if (session == null || _busy) return;
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final mine = _labels().any((t) => t.label == label && t.appliedByViewer);

    setState(() {
      _busy = true;
      // Optimistic, and reversed below if the write fails: a tag that appears
      // three seconds after the tap reads as a broken button.
      if (mine) {
        _added.remove(label);
        _removed.add(label);
      } else {
        _removed.remove(label);
        _added.add(label);
      }
    });

    final client = HomeserverClient(session: session);
    try {
      if (mine) {
        await client.untagPost(uri: post.uri, label: label);
        messenger.showSnackBar(
          SnackBar(content: Text(l.postTagRemoved(label))),
        );
      } else {
        await client.tagPost(uri: post.uri, label: label);
        messenger.showSnackBar(
          SnackBar(content: Text(l.postTagApplied(label))),
        );
      }
      unawaited(widget.nexus.requestIngest(session.pubky));
      unawaited(_refreshSoon());
    } catch (e) {
      if (mounted) {
        setState(() {
          if (mine) {
            _removed.remove(label);
          } else {
            _added.remove(label);
          }
        });
      }
      messenger.showSnackBar(SnackBar(
        content: Text(e is ArgumentError ? '${e.message}' : '$e'),
      ));
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addTag() async {
    if (!_canAct) return;
    final label = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TagSheet(existing: _labels()),
    );
    if (label == null || !mounted) return;
    await _toggleTag(label);
  }

  /// The labels to show: what the indexer knows, corrected by what this device
  /// has just done.
  List<ProfileTag> _labels() {
    final out = <ProfileTag>[];
    for (final tag in post.tags) {
      final added = _added.contains(tag.label);
      final removed = _removed.contains(tag.label);
      // Nobody else carried it, so removing mine removes the label itself.
      if (removed && tag.appliedByViewer && tag.taggersCount <= 1) continue;
      out.add(ProfileTag(
        label: tag.label,
        taggersCount: tag.taggersCount +
            (added && !tag.appliedByViewer ? 1 : 0) -
            (removed && tag.appliedByViewer ? 1 : 0),
        taggers: tag.taggers,
        appliedByViewer: (tag.appliedByViewer || added) && !removed,
      ));
    }
    for (final label in _added) {
      if (out.any((t) => t.label == label)) continue;
      out.add(ProfileTag(label: label, taggersCount: 1, appliedByViewer: true));
    }
    return out;
  }

  /// Opens the post this one answers or shares.
  void _openQuoted() {
    final session = widget.session;
    final uri = post.repliedUri ?? post.repostedUri;
    if (session == null || uri == null) return;
    unawaited(PostScreen.openUri(
      context,
      nexus: widget.nexus,
      session: session,
      uri: uri,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final profiles = widget.profiles;
    final pending = widget.pending;
    final onOpen = widget.onOpen;
    final hideQuote = widget.hideQuote;
    final nexus = widget.nexus;
    final session = widget.session;
    final quoted = widget.quoted;
    final quotedAuthor = widget.quotedAuthor;
    final author = profiles[post.author];
    final name = PostCard.displayName(author, post.author, l);
    final labels = _labels();

    final card = Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.isRepost)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.repeat_rounded, size: 14, color: kTextMuted),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '$name ${l.postRepostedLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          // A reply carries the post it answers above it, joined by a rail
          // down the left: the link is drawn rather than described, which is
          // what makes a timeline of answers readable at a glance.
          if (!hideQuote && post.isReply && quoted != null)
            _ParentThread(
              parent: quoted,
              author: quotedAuthor,
              nexus: nexus,
              profiles: profiles,
              collapsed: _parentCollapsed,
              onToggle: () =>
                  setState(() => _parentCollapsed = !_parentCollapsed),
              onOpen: session == null ? null : _openQuoted,
            ),
          _Header(
            post: post,
            author: author,
            name: name,
            nexus: nexus,
            session: session,
            pending: pending,
          ),
          if (post.article case final article?) ...[
            const SizedBox(height: 12),
            _Article(article: article),
          ] else if (post.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            PostContent(
              // The translation replaces the text in place, and the button
              // below puts the original back. Mentions and links survive it:
              // they are cut out before the request and slotted back after.
              content: _translated ?? post.content,
              nexus: nexus,
              knownProfiles: profiles,
            ),
            if (_translated != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l.postTranslatedBy,
                  style: const TextStyle(color: kTextMuted, fontSize: 11.5),
                ),
              ),
          ],
          // Not while pending: the indexer serves the variants, and it has
          // not seen the file yet — the card would flash a broken image for
          // the few seconds before indexing lands.
          if (!pending && post.imageUrls().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Images(urls: post.imageUrls()),
          ],
          if (!hideQuote && post.isRepost) ...[
            const SizedBox(height: 12),
            _QuotedBlock(
              post: quoted,
              author: quotedAuthor,
              nexus: nexus,
              profiles: profiles,
            ),
          ],
          if (labels.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TagRow(
              tags: labels,
              profiles: profiles,
              nexus: nexus,
              session: session,
              onToggle: _canAct && !_busy ? _toggleTag : null,
            ),
          ],
          _Actions(
            post: post,
            tagCount: labels.length,
            onReply: _canAct ? _reply : null,
            onShare: _canAct && !_busy ? _share : null,
            onTag: _canAct && !_busy ? _addTag : null,
            // Nothing to translate in a post with no words, and nothing to
            // translate in one this device has not indexed yet.
            onTranslate: (post.content.isEmpty || pending) ? null : _translate,
            translating: _translating,
            translated: _translated != null,
          ),
        ],
      ),
    );

    // The mentions and links inside carry their own tap recognisers, and those
    // win over this one — so opening the thread never steals a tap meant for a
    // profile.
    if (onOpen == null) return card;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

/// The post a reply answers, drawn above it and joined to it by a rail.
///
/// This replaced two earlier attempts, both wrong in the same way: a framed
/// copy of the parent *under* the answer, then a line of text naming its
/// author. Both said which post was being answered; neither showed it. A rail
/// down the left gutter, curving into the card below, is read without being
/// read — which is the whole point in a timeline where half the cards are
/// answers.
///
/// The parent is shown whole, not excerpted: an answer to a truncated
/// question is as good as an answer to nothing. It folds away instead, for
/// when the feed gets long.
class _ParentThread extends StatelessWidget {
  const _ParentThread({
    required this.parent,
    required this.author,
    required this.nexus,
    required this.profiles,
    required this.collapsed,
    required this.onToggle,
    required this.onOpen,
  });

  final PubkyPost parent;
  final PubkyProfile? author;
  final NexusClient nexus;
  final Map<String, PubkyProfile> profiles;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback? onOpen;

  /// Width of the gutter the rail lives in. The rail sits at its centre and
  /// curves right into the card below.
  static const _gutter = 30.0;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _gutter,
            child: Column(
              children: [
                Tooltip(
                  message: collapsed ? l.postThreadExpand : l.postThreadCollapse,
                  child: InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        collapsed
                            ? Icons.add_circle_outline_rounded
                            : Icons.remove_circle_outline_rounded,
                        size: 17,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    painter: _RailPainter(),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _DashedBorderPainter(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _ParentBody(
                      post: parent,
                      author: author,
                      nexus: nexus,
                      profiles: profiles,
                      collapsed: collapsed,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentBody extends StatelessWidget {
  const _ParentBody({
    required this.post,
    required this.author,
    required this.nexus,
    required this.profiles,
    required this.collapsed,
  });

  final PubkyPost post;
  final PubkyProfile? author;
  final NexusClient nexus;
  final Map<String, PubkyProfile> profiles;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipOval(
              child: Image.network(
                '$nexusBase/static/avatar/${post.author}',
                width: 22,
                height: 22,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: kTextMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                PostCard.displayName(author, post.author, l),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              PostCard.relativeTime(l, post.indexedAt),
              style: const TextStyle(color: kTextMuted, fontSize: 11),
            ),
          ],
        ),
        if (!collapsed) ...[
          if (post.article case final article?) ...[
            const SizedBox(height: 8),
            _Article(article: article, compact: true),
          ] else if (post.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Whole, not excerpted: this is the question the card answers.
            PostContent(
              content: post.content,
              nexus: nexus,
              knownProfiles: profiles,
            ),
          ],
          if (post.imageUrls().isNotEmpty) ...[
            const SizedBox(height: 8),
            _Images(urls: post.imageUrls(), height: 150),
          ],
        ],
      ],
    );
  }
}

/// The line joining a parent to the answer below it: down the gutter, then a
/// quarter turn into the card.
class _RailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const radius = 10.0;
    final x = size.width / 2;
    final path = Path()
      ..moveTo(x, 0)
      ..lineTo(x, size.height - radius)
      ..arcToPoint(
        Offset(x + radius, size.height),
        radius: const Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(size.width, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) => false;
}

/// A dashed frame, which is how pubky.app tells a quoted parent from a card of
/// its own — a solid border would read as another post in the timeline.
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kBorder
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );

    // Walked rather than drawn in one go: Flutter has no dash phase, so the
    // outline is measured and cut into segments.
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.post,
    required this.author,
    required this.name,
    required this.nexus,
    required this.session,
    required this.pending,
  });

  final PubkyPost post;
  final PubkyProfile? author;
  final String name;
  final NexusClient nexus;
  final RingSession? session;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return Row(
      children: [
        InkWell(
          onTap: () => showProfileSheet(
            context,
            nexus: nexus,
            pubky: post.author,
            known: author,
            session: session,
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
                    ? l.postPending
                    : PostCard.relativeTime(l, post.indexedAt),
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
    );
  }
}

/// The quoted post, framed so it cannot be mistaken for the author's own
/// words. Reposts only: a reply points at its parent with an arrow instead.
class _QuotedBlock extends StatelessWidget {
  const _QuotedBlock({
    required this.post,
    required this.author,
    required this.nexus,
    required this.profiles,
  });

  final PubkyPost? post;
  final PubkyProfile? author;
  final NexusClient nexus;
  final Map<String, PubkyProfile> profiles;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: post == null
          ? Text(
              l.postQuotedUnavailable,
              style: const TextStyle(color: kTextMuted, fontSize: 12.5),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: Image.network(
                        '$nexusBase/static/avatar/${post!.author}',
                        width: 22,
                        height: 22,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: kTextMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        PostCard.displayName(author, post!.author, l),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      PostCard.relativeTime(l, post!.indexedAt),
                      style: const TextStyle(color: kTextMuted, fontSize: 11),
                    ),
                  ],
                ),
                if (post!.article case final article?) ...[
                  const SizedBox(height: 8),
                  _Article(article: article, compact: true),
                ] else if (post!.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  PostContent(
                    content: post!.content,
                    nexus: nexus,
                    knownProfiles: profiles,
                  ),
                ],
                if (post!.imageUrls().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Images(urls: post!.imageUrls(), height: 130),
                ],
              ],
            ),
    );
  }
}

class _Images extends StatelessWidget {
  const _Images({required this.urls, this.height = 190});

  final List<String> urls;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: urls.length == 1
            ? GestureDetector(
                onTap: () => showImageViewer(context, urls: urls),
                child: _Thumb(url: urls.first, height: height),
              )
            : SizedBox(
                height: height * 0.7,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: urls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 170,
                      child: GestureDetector(
                        onTap: () =>
                            showImageViewer(context, urls: urls, initial: i),
                        child: _Thumb(url: urls[i], height: height * 0.7),
                      ),
                    ),
                  ),
                ),
              ),
      );
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

/// Reply, repost and tag, each carrying its own counter.
///
/// Those counters used to be the whole row, and they were a dead end: the card
/// said "1 reply, 5 tags" with no way to add either. Same numbers, now on the
/// buttons that produce them — and a reply button on the card is what makes it
/// obvious which post an answer is going to.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.post,
    required this.tagCount,
    required this.onReply,
    required this.onShare,
    required this.onTag,
    required this.onTranslate,
    required this.translating,
    required this.translated,
  });

  final PubkyPost post;
  final int tagCount;
  final VoidCallback? onReply;
  final VoidCallback? onShare;
  final VoidCallback? onTag;
  final VoidCallback? onTranslate;
  final bool translating;
  final bool translated;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          _Action(
            icon: Icons.mode_comment_outlined,
            count: post.counts['replies'] ?? 0,
            tooltip: l.postReply,
            onTap: onReply,
          ),
          _Action(
            icon: Icons.repeat_rounded,
            count: post.counts['reposts'] ?? 0,
            tooltip: l.postActionRepost,
            onTap: onShare,
          ),
          _Action(
            icon: Icons.sell_outlined,
            // The labels on screen, not the number of taggings: five people
            // agreeing on one word are one chip, and a chip is what the button
            // adds.
            count: tagCount,
            tooltip: l.postActionTag,
            onTap: onTag,
          ),
          const Spacer(),
          if (onTranslate != null)
            Tooltip(
              message: l.postTranslate,
              child: InkWell(
                onTap: translating ? null : onTranslate,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: translating
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : Icon(
                          translated
                              ? Icons.undo_rounded
                              : Icons.translate_rounded,
                          size: 15,
                          color: translated ? kAccent : kTextMuted,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 18, 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: kTextMuted),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: const TextStyle(color: kTextMuted, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// The labels on a post: tap to add or remove your own, long-press to see who
/// applied one.
///
/// The taggers matter — a label is auditable precisely because Nexus publishes
/// the keys behind it — but they are one line down rather than on the chip:
/// a timeline showing five names per label is a list of names, not a feed.
class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tags,
    required this.profiles,
    required this.nexus,
    required this.session,
    required this.onToggle,
  });

  final List<ProfileTag> tags;
  final Map<String, PubkyProfile> profiles;
  final NexusClient nexus;
  final RingSession? session;
  final void Function(String label)? onToggle;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in tags)
            _TagChip(
              tag: tag,
              onTap: onToggle == null ? null : () => onToggle!(tag.label),
              onShowTaggers:
                  tag.taggers.isEmpty ? null : () => _showTaggers(context, tag),
            ),
        ],
      );

  void _showTaggers(BuildContext context, ProfileTag tag) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final l = L10n.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.postTaggersTitle(tag.label),
                  style: const TextStyle(
                    color: kTextMuted,
                    fontSize: 12.5,
                    letterSpacing: 0.3,
                  ),
                ),
                for (final tagger in tag.taggers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipOval(
                      child: Image.network(
                        '$nexusBase/static/avatar/$tagger',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person_rounded, color: kTextMuted),
                      ),
                    ),
                    title: Text(
                      PostCard.displayName(profiles[tagger], tagger, l),
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      showProfileSheet(
                        context,
                        nexus: nexus,
                        pubky: tagger,
                        known: profiles[tagger],
                        session: session,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.onTap,
    required this.onShowTaggers,
  });

  final ProfileTag tag;
  final VoidCallback? onTap;
  final VoidCallback? onShowTaggers;

  @override
  Widget build(BuildContext context) {
    final mine = tag.appliedByViewer;

    return InkWell(
      onTap: onTap,
      onLongPress: onShowTaggers,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: mine ? kAccent.withValues(alpha: 0.14) : kBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: mine ? kAccent.withValues(alpha: 0.55) : kBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag.label,
              style: TextStyle(fontSize: 12.5, color: mine ? kAccent : kText),
            ),
            if (tag.taggersCount > 1) ...[
              const SizedBox(width: 6),
              Text(
                '${tag.taggersCount}',
                style: const TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ShareChoice { repost, quote }

/// Repost as it is, or add words to it. Both write the same resource — a post
/// carrying an `embed` — which is why they share one button.
class _ShareSheet extends StatelessWidget {
  const _ShareSheet();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.postShareTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat_rounded, color: kAccent),
              title: Text(l.postShareRepost),
              subtitle: Text(
                l.postShareRepostNote,
                style: const TextStyle(color: kTextMuted, fontSize: 12.5),
              ),
              onTap: () => Navigator.pop(context, _ShareChoice.repost),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.format_quote_rounded, color: kAccent),
              title: Text(l.postShareQuote),
              subtitle: Text(
                l.postShareQuoteNote,
                style: const TextStyle(color: kTextMuted, fontSize: 12.5),
              ),
              onTap: () => Navigator.pop(context, _ShareChoice.quote),
            ),
          ],
        ),
      ),
    );
  }
}

/// Types a label, refusing here what the network would refuse silently.
///
/// A label over twenty characters, or carrying a comma, a colon or a space, is
/// rejected by the spec — and a rejected write is stored by the homeserver and
/// ignored by the indexer, which looks exactly like nothing happening.
class _TagSheet extends StatefulWidget {
  const _TagSheet({required this.existing});

  /// Already on the post: tapping one is faster than typing it, and it is the
  /// only hint of what other people are using.
  final List<ProfileTag> existing;

  @override
  State<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<_TagSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final label = sanitizeTagLabel(_controller.text);
    if (label.isEmpty || tagLabelProblem(label) != null) return;
    Navigator.pop(context, label);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final label = sanitizeTagLabel(_controller.text);
    // Nothing typed yet is not a mistake, so it carries no error.
    final problem = label.isEmpty
        ? null
        : switch (tagLabelProblem(label)) {
            'tooLong' => l.postTagTooLong(maxTagLabelLength),
            'invalidChar' => l.postTagInvalidChar,
            _ => null,
          };

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.postTagTitle,
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 15.5),
            decoration: InputDecoration(
              hintText: l.postTagHint(maxTagLabelLength),
              hintStyle: const TextStyle(color: kTextMuted),
              filled: true,
              fillColor: kBackground,
              errorText: problem,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kAccent.withValues(alpha: 0.6)),
              ),
            ),
          ),
          if (widget.existing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in widget.existing)
                  _TagChip(
                    tag: tag,
                    onTap: () => Navigator.pop(context, tag.label),
                    onShowTaggers: null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: label.isEmpty || problem != null ? null : _submit,
            child: Text(l.postTagAdd),
          ),
        ],
      ),
    );
  }
}

/// A `long` post: title plus a Markdown body, both packed as JSON inside the
/// content field. The feed shows the title and an excerpt — a full Markdown
/// render belongs on a detail screen, which does not exist yet, and pasting a
/// whole article into a timeline card would drown the rest.
class _Article extends StatelessWidget {
  const _Article({required this.article, this.compact = false});

  final ({String title, String body}) article;

  /// Inside a quoted block, where the card already carries its own header.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          article.title.isEmpty ? l.articleUntitled : article.title,
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        if (article.body.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _plainExcerpt(article.body),
            maxLines: compact ? 3 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              height: 1.5,
              fontSize: compact ? 13 : 14,
              color: kTextMuted,
            ),
          ),
        ],
      ],
    );
  }

  /// Strips the Markdown that reads badly as plain text — headings, emphasis,
  /// list bullets and link syntax — so the excerpt is a sentence rather than
  /// a line of punctuation.
  static String _plainExcerpt(String markdown) {
    var text = markdown;
    text = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*[*\-+]\s+', multiLine: true), '• ');
    text = text.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
    text = text.replaceAll(RegExp(r'[*_`]{1,3}'), '');
    // Collapse blank lines: an excerpt of four lines should not spend two of
    // them on paragraph spacing.
    text = text.replaceAll(RegExp(r'\n{2,}'), '\n');
    return text.trim();
  }
}
