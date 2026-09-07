/// Splitting post content into plain text, mentions and links.
///
/// pubky-app writes a mention as the literal string `pubky` followed by the
/// 52-character z-base-32 key, with no separator — measured on live posts:
/// `Hey pubkyw3ase343…fge6y, how can I reach you?`. Rendered raw it reads as a
/// 57-character blob, which is what a naive client shows.
library;

sealed class ContentSpan {
  const ContentSpan();
}

class TextSpanPart extends ContentSpan {
  const TextSpanPart(this.text);
  final String text;
}

class MentionSpan extends ContentSpan {
  const MentionSpan(this.pubky);
  final String pubky;
}

class LinkSpan extends ContentSpan {
  const LinkSpan(this.url);
  final String url;
}

/// `pubky` + 52 z-base-32 chars. The negative lookahead keeps `pubky://…`
/// URIs out: those are resource links, not mentions.
///
/// Kept as source strings too, so they can be folded into a larger pattern —
/// the compose sheet builds one that also covers the aliases on screen.
const mentionPattern = r'pubky(?!:\/\/)([a-z0-9]{52})';
const linkPattern = r'https?:\/\/[^\s<>"]+';

final _mention = RegExp(mentionPattern);
final _link = RegExp(linkPattern);

/// Splits content in one pass, so a link inside a sentence and a mention next
/// to it both survive. Order matters only for overlapping matches, which these
/// two patterns cannot produce.
List<ContentSpan> parseContent(String content) {
  if (content.isEmpty) return const [];

  final matches = <({int start, int end, ContentSpan span})>[
    for (final m in _mention.allMatches(content))
      (start: m.start, end: m.end, span: MentionSpan(m.group(1)!)),
    for (final m in _link.allMatches(content))
      (start: m.start, end: m.end, span: LinkSpan(m.group(0)!)),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final spans = <ContentSpan>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start < cursor) continue; // overlapped by a previous match
    if (match.start > cursor) {
      spans.add(TextSpanPart(content.substring(cursor, match.start)));
    }
    spans.add(match.span);
    cursor = match.end;
  }
  if (cursor < content.length) {
    spans.add(TextSpanPart(content.substring(cursor)));
  }
  return spans;
}

/// Every key mentioned in a piece of content — used to resolve display names
/// in the same batch call as the post authors.
Set<String> mentionedKeys(String content) =>
    _mention.allMatches(content).map((m) => m.group(1)!).toSet();

/// A stable, space-free `@Name` standing for a key in the editor.
///
/// Spaces are dropped rather than kept: an alias containing one is broken by
/// any edit inside it, and the mention would then vanish without saying so. A
/// name made only of emoji leaves nothing usable, hence the fallback to the
/// head of the key. Two people sharing a name get a key suffix — the alias is
/// what the substitution matches, so it has to be unique.
String aliasForMention(
  String pubky,
  String name,
  Map<String, String> existing,
) {
  var base = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  if (base.isEmpty) base = pubky.substring(0, 6);
  if (base.length > 24) base = base.substring(0, 24);

  final plain = '@$base';
  final taken = existing[plain];
  if (taken == null || taken == pubky) return plain;
  return '@$base-${pubky.substring(0, 4)}';
}
