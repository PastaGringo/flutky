import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../pubky/mentions.dart';
import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';
import 'post_card.dart';
import 'profile_sheet.dart';

/// One post, its labels, and what people replied.
///
/// Until this screen existed the counters on a card were the end of the road:
/// it said "1 reply, 5 tags" and there was nowhere to go. Five labels and an
/// answer are the substance of a conversation — a number standing in for them
/// tells you something happened without letting you read it.
class PostScreen extends StatefulWidget {
  const PostScreen({
    super.key,
    required this.nexus,
    required this.session,
    required this.author,
    required this.postId,
    this.known,
  });

  final NexusClient nexus;
  final RingSession session;
  final String author;
  final String postId;

  /// The post as the caller already has it, so the screen paints at once and
  /// refreshes underneath rather than opening on a spinner.
  final PubkyPost? known;

  /// Opens the screen for a `pubky://…/posts/<id>` URI, doing nothing when the
  /// URI is not one — a notification can point at something we cannot show.
  static Future<void> openUri(
    BuildContext context, {
    required NexusClient nexus,
    required RingSession session,
    required String uri,
  }) async {
    final parts = PubkyPost.parsePostUri(uri);
    if (parts == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostScreen(
          nexus: nexus,
          session: session,
          author: parts.author,
          postId: parts.id,
        ),
      ),
    );
  }

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _profiles = <String, PubkyProfile>{};
  final _replies = <PubkyPost>[];

  late PubkyPost? _post = widget.known;
  PubkyPost? _parent;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post = await widget.nexus.fetchPost(widget.author, widget.postId);
      if (post == null) {
        if (mounted) {
          setState(() {
            _error = null;
            _loading = false;
          });
        }
        return;
      }

      final replies = await widget.nexus.fetchReplies(
        author: widget.author,
        postId: widget.postId,
        observerId: widget.session.pubky,
      );

      // A reply opened from a notification is more readable with the post it
      // answers above it, so that one is fetched too when there is one.
      PubkyPost? parent;
      final parentUri = post.repliedUri ?? post.repostedUri;
      if (parentUri != null) {
        final parts = PubkyPost.parsePostUri(parentUri);
        if (parts != null) {
          parent = await widget.nexus.fetchPost(parts.author, parts.id);
        }
      }

      final keys = <String>{
        post.author,
        ...mentionedKeys(post.content),
        for (final r in replies) ...{r.author, ...mentionedKeys(r.content)},
        if (parent != null) ...{parent.author, ...mentionedKeys(parent.content)},
        // The people who applied a label, so the chips can name them on tap.
        for (final tag in post.tags) ...tag.taggers,
      }..removeWhere((k) => k.isEmpty);

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
        _post = post;
        _parent = parent;
        _replies
          ..clear()
          ..addAll(replies);
        _profiles.addAll(resolved);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final post = _post;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackground,
        title: Text(l.postTitle),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (_error != null) ...[
                ErrorPanel(message: _error!),
                const SizedBox(height: 14),
              ],
              if (post == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
                  child: Text(
                    _loading ? l.postLoading : l.postGone,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kTextMuted, height: 1.5),
                  ),
                )
              else ...[
                if (_parent case final parent?) ...[
                  Text(
                    l.postInReplyTo,
                    style: const TextStyle(color: kTextMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  PostCard(
                    post: parent,
                    nexus: widget.nexus,
                    profiles: _profiles,
                    session: widget.session,
                  ),
                  const SizedBox(height: 14),
                ],
                PostCard(
                  post: post,
                  nexus: widget.nexus,
                  profiles: _profiles,
                  session: widget.session,
                ),
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _TagList(
                    tags: post.tags,
                    profiles: _profiles,
                    nexus: widget.nexus,
                    session: widget.session,
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  _replies.isEmpty
                      ? l.postNoReplies
                      : l.postReplies(_replies.length),
                  style: const TextStyle(
                    color: kTextMuted,
                    fontSize: 12.5,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                for (final reply in _replies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(
                      post: reply,
                      nexus: widget.nexus,
                      profiles: _profiles,
                      session: widget.session,
                    ),
                  ),
              ],
              if (_loading && post != null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The labels applied to a post, with who applied them.
///
/// The card only ever showed a count. A label is the thing people actually
/// wrote — five of them say more about how a post landed than the number 5.
class _TagList extends StatelessWidget {
  const _TagList({
    required this.tags,
    required this.profiles,
    required this.nexus,
    required this.session,
  });

  final List<ProfileTag> tags;
  final Map<String, PubkyProfile> profiles;
  final NexusClient nexus;
  final RingSession session;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in tags)
            _TagChip(
              tag: tag,
              profiles: profiles,
              nexus: nexus,
              session: session,
            ),
        ],
      );
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.profiles,
    required this.nexus,
    required this.session,
  });

  final ProfileTag tag;
  final Map<String, PubkyProfile> profiles;
  final NexusClient nexus;
  final RingSession session;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final first = tag.taggers.isEmpty ? null : tag.taggers.first;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      // One tagger opens their profile; several would need a list, which is
      // more screen than the information deserves.
      onTap: first == null || tag.taggers.length > 1
          ? null
          : () => showProfileSheet(
                context,
                nexus: nexus,
                pubky: first,
                known: profiles[first],
                session: session,
              ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag.label,
              style: const TextStyle(fontSize: 13, color: kText),
            ),
            if (tag.taggersCount > 1) ...[
              const SizedBox(width: 7),
              Text(
                '${tag.taggersCount}',
                style: const TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
            ] else if (first != null) ...[
              const SizedBox(width: 7),
              Text(
                PostCard.displayName(profiles[first], first, l),
                style: const TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
