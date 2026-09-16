import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// What a link looks like when it is worth showing rather than reading.
class LinkPreview {
  const LinkPreview({
    required this.url,
    required this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.imageAspect = 16 / 9,
  });

  final String url;
  final String title;
  final String? description;
  final String? imageUrl;

  /// `YouTube`, `GitHub`… taken from `og:site_name`, or falling back to the
  /// host. Shown small above the title, which is what tells a reader where a
  /// link goes before they tap it.
  final String? siteName;

  /// The shape to reserve for the image, from the dimensions the page
  /// declares beside it, clamped to [minAspect]–[maxAspect].
  ///
  /// Reading the declared shape was measured: cropped to a fixed 16/9,
  /// GitHub's social card — published at 1200×600 — lost its edges and the
  /// repository name ran off both sides. Honouring 2/1 shows it whole.
  final double imageAspect;

  /// The clamp, on the other hand, is a precaution and not a fix for anything
  /// observed: of the pages measured, all declared a landscape shape (GitHub
  /// 2/1, lemonde.fr 1880×984, YouTube 16/9). It exists so that a site which
  /// declares a square or portrait image cannot hand a feed a picture taller
  /// than five sevenths of its width — such an image is cropped instead,
  /// which is what every client does with a square logo.
  static const minAspect = 1.4;
  static const maxAspect = 3.0;

  String get host {
    final h = Uri.tryParse(url)?.host ?? '';
    return h.startsWith('www.') ? h.substring(4) : h;
  }
}

/// Builds previews for the links inside posts.
///
/// Two paths, and the split is measured rather than chosen. Most sites put
/// their OpenGraph tags in `<head>`, so reading up to `</head>` and hanging
/// up is enough — bytes actually transferred, against whole-page sizes:
/// x.com 12,5 ko sur 179, lemonde.fr 15,5 ko sur 882, GitHub 64 ko sur 348.
/// YouTube does not play that game: its `og:title` sits at byte 606 589 of a
/// 763 ko document, well past a `</head>` that ends at byte 3 009. Parsing it
/// the same way would cost three quarters of a megabyte for one line of text,
/// so YouTube goes through its oEmbed endpoint instead — **868 octets**
/// measured, with the full title, the author and a thumbnail.
///
/// ⚠️ Fetching a preview contacts the linked site directly, with the reader's
/// address. That is how every client with previews works, but it is a real
/// disclosure and it is why the whole thing can be switched off.
class LinkPreviewClient {
  LinkPreviewClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Kept for the life of the screen so scrolling a feed back and forth does
  /// not refetch. A failed lookup is cached too — as null — because retrying
  /// a site that answers 403 on every rebuild is a loop, not a retry.
  static final _cache = <String, LinkPreview?>{};

  /// Stops reading here when no `</head>` has been seen. Generous enough for
  /// every page measured, small enough that a misbehaving server cannot make
  /// the feed download a video.
  static const _maxBytes = 192 * 1024;

  /// Some sites serve a stripped page to anything that does not look like a
  /// browser — x.com among them.
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  void close() => _client.close();

  Future<LinkPreview?> fetch(String url) async {
    if (_cache.containsKey(url)) return _cache[url];
    LinkPreview? preview;
    try {
      final videoId = youtubeId(url);
      preview = videoId == null
          ? await _fromOpenGraph(url)
          : await _fromYoutube(url, videoId);
    } catch (_) {
      // A link that cannot be described is still a link: the post shows it as
      // text, exactly as it did before previews existed.
      preview = null;
    }
    _cache[url] = preview;
    return preview;
  }

  /// The eleven-character id, from any of the four shapes YouTube uses.
  static String? youtubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase().replaceFirst('www.', '');
    String? candidate;
    if (host == 'youtu.be') {
      candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (host == 'youtube.com' || host == 'm.youtube.com') {
      final segments = uri.pathSegments;
      if (uri.path == '/watch') {
        candidate = uri.queryParameters['v'];
      } else if (segments.length >= 2 &&
          (segments.first == 'shorts' ||
              segments.first == 'embed' ||
              segments.first == 'live')) {
        candidate = segments[1];
      }
    }
    if (candidate == null) return null;
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate)
        ? candidate
        : null;
  }

  Future<LinkPreview?> _fromYoutube(String url, String videoId) async {
    final endpoint = Uri.https('www.youtube.com', '/oembed', {
      'url': 'https://www.youtube.com/watch?v=$videoId',
      'format': 'json',
    });
    final res = await _client
        .get(endpoint)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) return null;
    final title = body['title']?.toString();
    if (title == null || title.isEmpty) return null;
    return LinkPreview(
      url: url,
      title: title,
      description: body['author_name']?.toString(),
      // hqdefault is the largest size that exists for every video;
      // maxresdefault answers 404 on anything never published in HD.
      imageUrl: body['thumbnail_url']?.toString() ??
          'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      siteName: 'YouTube',
      // Deliberately NOT oEmbed's `thumbnail_width`/`height`: hqdefault is a
      // 4/3 canvas with the 16/9 frame letterboxed inside it, so honouring
      // the declared shape would draw the black bars rather than crop them.
      imageAspect: 16 / 9,
    );
  }

  Future<LinkPreview?> _fromOpenGraph(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;

    final request = http.Request('GET', uri)
      ..followRedirects = true
      ..headers.addAll({
        'User-Agent': _userAgent,
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'fr,en;q=0.8',
      });
    final res =
        await _client.send(request).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      unawaited(res.stream.drain<void>().catchError((_) {}));
      return null;
    }
    final type = res.headers['content-type'] ?? '';
    if (!type.contains('html') && type.isNotEmpty) {
      unawaited(res.stream.drain<void>().catchError((_) {}));
      return null;
    }

    final head = await _readHead(res.stream);
    // Latin-1 keeps every byte addressable and never throws; the entities and
    // the UTF-8 sequences inside are put back together by [_decode].
    return _parse(url, latin1.decode(head, allowInvalid: true));
  }

  /// Reads until `</head>`, then hangs up.
  ///
  /// Cancelling the subscription closes the connection, so the rest of the
  /// document is never transferred — which is the whole point: the tags are
  /// in the first few kilobytes and the body can be a megabyte.
  Future<List<int>> _readHead(Stream<List<int>> stream) {
    final done = Completer<List<int>>();
    final bytes = <int>[];
    late StreamSubscription<List<int>> sub;

    void finish() {
      if (done.isCompleted) return;
      done.complete(bytes);
      unawaited(sub.cancel());
    }

    sub = stream.listen(
      (chunk) {
        bytes.addAll(chunk);
        // Searched over the tail plus a small overlap rather than over the
        // whole buffer each time: `</head>` can straddle two chunks, and
        // rescanning everything turns a large page into quadratic work.
        final from = (bytes.length - chunk.length - 8).clamp(0, bytes.length);
        final window = latin1.decode(
          bytes.sublist(from),
          allowInvalid: true,
        );
        if (window.toLowerCase().contains('</head>') ||
            bytes.length >= _maxBytes) {
          finish();
        }
      },
      onDone: finish,
      onError: (_) => finish(),
      cancelOnError: true,
    );
    return done.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        unawaited(sub.cancel());
        return bytes;
      },
    );
  }

  /// Both attribute orders and both quote styles, because pages use all four.
  static final _metaTag = RegExp(r'<meta\s[^>]*>', caseSensitive: false);
  static final _attribute = RegExp(
    r'''(property|name|content)\s*=\s*("([^"]*)"|'([^']*)')''',
    caseSensitive: false,
  );
  static final _titleTag =
      RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true);

  static LinkPreview? _parse(String url, String html) {
    final meta = <String, String>{};
    for (final tag in _metaTag.allMatches(html)) {
      String? key;
      String? value;
      for (final attr in _attribute.allMatches(tag.group(0)!)) {
        final name = attr.group(1)!.toLowerCase();
        final raw = attr.group(3) ?? attr.group(4) ?? '';
        if (name == 'content') {
          value = raw;
        } else {
          key = raw.toLowerCase();
        }
      }
      if (key != null && value != null && !meta.containsKey(key)) {
        meta[key] = value;
      }
    }

    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = meta[key];
        if (value != null && value.trim().isNotEmpty) return _decode(value);
      }
      return null;
    }

    final title = pick(['og:title', 'twitter:title']) ??
        _decode(_titleTag.firstMatch(html)?.group(1)?.trim() ?? '');
    if (title.isEmpty) return null;

    final image = pick(['og:image', 'og:image:url', 'twitter:image']);
    final width = double.tryParse(meta['og:image:width'] ?? '');
    final height = double.tryParse(meta['og:image:height'] ?? '');
    final aspect = (width != null && height != null && height > 0)
        ? width / height
        : null;
    return LinkPreview(
      url: url,
      title: title,
      description: pick(['og:description', 'twitter:description', 'description']),
      imageUrl: image == null ? null : Uri.tryParse(url)
          ?.resolve(image)
          .toString(),
      siteName: pick(['og:site_name', 'application-name']),
      imageAspect: aspect == null
          ? 16 / 9
          : aspect.clamp(LinkPreview.minAspect, LinkPreview.maxAspect),
    );
  }

  /// Undoes the two layers a meta tag carries: the HTML entities, and the
  /// UTF-8 that was read one byte at a time.
  static String _decode(String raw) {
    var out = raw
        .replaceAll('&quot;', '"')
        .replaceAll('&#34;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)),
        )
        // Last, so a literal `&amp;quot;` does not become a quote.
        .replaceAll('&amp;', '&');
    try {
      out = utf8.decode(latin1.encode(out));
    } on FormatException {
      // Already text, or a charset we do not speak — shown as it came.
    } on ArgumentError {
      // A character outside Latin-1: it was never mis-decoded in the first
      // place, so there is nothing to undo.
    }
    return out.trim();
  }
}
