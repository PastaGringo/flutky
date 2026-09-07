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
final _mention = RegExp(r'pubky(?!:\/\/)([a-z0-9]{52})');
final _link = RegExp(r'https?:\/\/[^\s<>"]+');

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
