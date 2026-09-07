import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';
import '../pubky/mentions.dart';
import '../pubky/translation.dart';
import '../settings/preferences_scope.dart';
import 'image_viewer.dart';
import 'post_content.dart';
import 'profile_sheet.dart';

/// One post in the timeline.
///
/// A repost is an ordinary post pointing at another. With text of its own it
/// reads as a quote — the quoted post goes in a framed block underneath; with
/// no text, it is a plain share and the original takes the whole card, under a
/// discreet "reposted" line.
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
  });

  final PubkyPost post;
  final NexusClient nexus;
  final Map<String, PubkyProfile> profiles;

  /// Lets the profile sheet offer Follow. Absent, it stays read-only.
  final RingSession? session;

  /// The post this one reposts or replies to, once loaded.
  final PubkyPost? quoted;
  final PubkyProfile? quotedAuthor;

  /// Published from this device and not yet visible through the indexer.
  final bool pending;

  /// Opens the thread. Absent inside the thread itself, where tapping a card
  /// to reach the screen you are already on is a dead end.
  final VoidCallback? onOpen;

  /// Hides the quoted block entirely.
  ///
  /// Inside a thread, every reply points at the post displayed above it. The
  /// block would either repeat that post under each answer, or — when it is
  /// not passed in — claim the original is unavailable, which is false and
  /// alarming. The context is already on screen; the frame is noise.
  final bool hideQuote;

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

  PubkyPost get post => widget.post;

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
          if (!hideQuote && (post.isRepost || post.isReply)) ...[
            const SizedBox(height: 12),
            _QuotedBlock(
              post: quoted,
              author: quotedAuthor,
              nexus: nexus,
              profiles: profiles,
            ),
          ],
          _Metrics(
            post: post,
            // Nothing to translate in a post with no words, and nothing to
            // translate in one this device has not indexed yet.
            onTranslate:
                (post.content.isEmpty || pending) ? null : _translate,
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

/// The quoted or replied-to post, framed so it cannot be mistaken for the
/// author's own words.
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

class _Metrics extends StatelessWidget {
  const _Metrics({
    required this.post,
    required this.onTranslate,
    required this.translating,
    required this.translated,
  });

  final PubkyPost post;
  final VoidCallback? onTranslate;
  final bool translating;
  final bool translated;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final replies = post.counts['replies'] ?? 0;
    final reposts = post.counts['reposts'] ?? 0;
    final tags = post.counts['tags'] ?? 0;
    if (replies + reposts + tags == 0 && onTranslate == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (replies > 0) _Metric(Icons.mode_comment_outlined, replies),
          if (reposts > 0) _Metric(Icons.repeat_rounded, reposts),
          if (tags > 0) _Metric(Icons.sell_outlined, tags),
          const Spacer(),
          if (onTranslate != null)
            InkWell(
              onTap: translating ? null : onTranslate,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          if (onTranslate != null)
            Semantics(
              label: l.postTranslate,
              child: const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
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
