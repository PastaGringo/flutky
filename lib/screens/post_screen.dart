import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../pubky/mentions.dart';
import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';
import 'post_card.dart';

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

  /// Reloads after something was published from one of the cards.
  ///
  /// The indexer lags the homeserver by a second or two, so the first look
  /// usually comes back without the new reply. Two tries cover it without
  /// turning the screen into a poller — and the thread is reloaded rather than
  /// guessed at, since a wrong guess about ordering would be more confusing
  /// than a second of waiting.
  Future<void> _reloadSoon() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await _load();
    await Future<void>.delayed(const Duration(seconds: 5));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final post = _post;
    // Only a reply gets its parent as a card of its own, under « in reply
    // to »: a repost points at what it shares, and the card renders that as a
    // quoted block with the right wording.
    final parentAbove = (post?.isReply ?? false) ? _parent : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackground,
        title: Text(l.postTitle),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
                if (parentAbove case final parent?) ...[
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
                    hideQuote: true,
                    onChanged: () => unawaited(_reloadSoon()),
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PostScreen(
                          nexus: widget.nexus,
                          session: widget.session,
                          author: parent.author,
                          postId: parent.id,
                          known: parent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                PostCard(
                  post: post,
                  nexus: widget.nexus,
                  profiles: _profiles,
                  // The post it answers is the card right above, so the arrow
                  // would point at what is already on screen.
                  hideQuote: parentAbove != null,
                  quoted: _parent,
                  quotedAuthor:
                      _parent == null ? null : _profiles[_parent!.author],
                  session: widget.session,
                  onChanged: () => unawaited(_reloadSoon()),
                ),
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
                      // Every reply here answers the post above: naming it
                      // again under each one would repeat the screen.
                      hideQuote: true,
                      onChanged: () => unawaited(_reloadSoon()),
                      // A thread is a tree, and Nexus hands back one level at
                      // a time: `post_replies` returns direct children only,
                      // and `counts.replies` counts only those. Measured on a
                      // post announcing 16 replies — all 16 came back, all
                      // pointing at the root, while five of them had a reply
                      // of their own that did not. So each reply opens its
                      // own screen, and its counter says whether that is
                      // worth doing.
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PostScreen(
                            nexus: widget.nexus,
                            session: widget.session,
                            author: reply.author,
                            postId: reply.id,
                            known: reply,
                          ),
                        ),
                      ),
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
