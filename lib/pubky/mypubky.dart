import 'dart:convert';

import 'package:http/http.dart' as http;

import 'endpoints.dart';

/// The capability a grant needs before a card can be rewritten.
///
/// Reading needs none: `/pub/` is world-readable and the card is a plain JSON
/// file. Only the Save button asks for anything.
const mypubkyCapability = '/pub/mypubky.com/:rw';

const mypubkyCardPath = '/pub/mypubky.com/card.json';

/// One entry under the bio on a mypubky card.
///
/// The shape is what the app writes, not what a specification says — there is
/// no `mypubky-app-specs` package. Read off five real cards on the live
/// homeserver: a link carries `title` plus exactly one of `url` or `mailto`.
class MypubkyLink {
  const MypubkyLink({required this.title, this.url, this.mailto});

  final String title;
  final String? url;
  final String? mailto;

  factory MypubkyLink.fromJson(Map<String, dynamic> json) => MypubkyLink(
        title: json['title']?.toString() ?? '',
        url: json['url']?.toString(),
        mailto: json['mailto']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        if (url != null && url!.isNotEmpty) 'url': url,
        if (mailto != null && mailto!.isNotEmpty) 'mailto': mailto,
      };

  /// What the link resolves to when tapped.
  String? get target {
    if (mailto != null && mailto!.isNotEmpty) return 'mailto:$mailto';
    if (url != null && url!.isNotEmpty) return url;
    return null;
  }
}

/// A social account shown as an icon. `key` names the platform (`github`,
/// `x`, …) and drives the icon on mypubky.com.
class MypubkySocial {
  const MypubkySocial({
    required this.key,
    required this.title,
    required this.url,
  });

  final String key;
  final String title;
  final String url;

  factory MypubkySocial.fromJson(Map<String, dynamic> json) => MypubkySocial(
        key: json['key']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'key': key, 'title': title, 'url': url};
}

/// The profile card `mypubky.com/<key>` renders.
///
/// Fields kept verbatim from the file and written back unchanged where Flutky
/// does not edit them — a client that drops what it does not understand
/// silently deletes the other app's settings the first time it saves.
class MypubkyCard {
  MypubkyCard({
    required this.pubky,
    required this.raw,
    required this.links,
    required this.socials,
  });

  final String pubky;

  /// Everything the file held, so a save preserves what is not edited here.
  final Map<String, dynamic> raw;

  final List<MypubkyLink> links;
  final List<MypubkySocial> socials;

  String get bitcoinAddress => raw['bitcoinAddress']?.toString() ?? '';
  bool get donateEnabled => raw['donateEnabled'] == true;
  bool get showLatestPost => raw['showLatestPost'] == true;
  bool get showTags => raw['showTags'] == true;
  String get cardPosition => raw['cardPosition']?.toString() ?? 'center';
  String get cardBackgroundMode =>
      raw['cardBackgroundMode']?.toString() ?? 'dark';
  String get backgroundId => raw['backgroundId']?.toString() ?? 'back1';

  /// The three shipped backgrounds. A fourth value, `custom`, means the owner
  /// uploaded their own — kept as it is, because Flutky cannot replace it
  /// without uploading a file of its own.
  static const builtInBackgrounds = ['back1', 'back2', 'back3'];

  static const positions = ['left', 'center', 'right'];
  static const backgroundModes = ['dark', 'blur', 'clear'];

  /// The public page for this card.
  String get publicUrl => 'https://mypubky.com/$pubky';

  factory MypubkyCard.fromJson(String pubky, Map<String, dynamic> json) =>
      MypubkyCard(
        pubky: pubky,
        raw: Map<String, dynamic>.from(json),
        links: [
          for (final e in (json['extraLinks'] as List? ?? const []))
            if (e is Map<String, dynamic>) MypubkyLink.fromJson(e),
        ],
        socials: [
          for (final e in (json['extraSocials'] as List? ?? const []))
            if (e is Map<String, dynamic>) MypubkySocial.fromJson(e),
        ],
      );

  /// An empty card for someone who has never opened mypubky, with the same
  /// defaults the web app starts from.
  factory MypubkyCard.empty(String pubky) => MypubkyCard(
        pubky: pubky,
        raw: {
          'pubky': pubky,
          'backgroundId': 'back1',
          'backgroundType': 'image',
          // No `backgroundUrl`: see [withBuiltInBackground].
          'bitcoinAddress': '',
          'cardBackgroundMode': 'dark',
          'cardPosition': 'center',
          'donateEnabled': false,
          'donateEndpoint': pubky,
          'showLatestPost': true,
          'showTags': true,
          'extraLinks': <dynamic>[],
          'extraSocials': <dynamic>[],
        },
        links: const [],
        socials: const [],
      );

  Map<String, dynamic> toJson() => {
        ...raw,
        'pubky': pubky,
        'extraLinks': [for (final l in links) l.toJson()],
        'extraSocials': [for (final s in socials) s.toJson()],
      };

  MypubkyCard copyWith({
    Map<String, dynamic>? changes,
    Set<String> removals = const {},
    List<MypubkyLink>? links,
    List<MypubkySocial>? socials,
  }) =>
      MypubkyCard(
        pubky: pubky,
        raw: {
          for (final e in raw.entries)
            if (!removals.contains(e.key)) e.key: e.value,
          ...?changes,
        },
        links: links ?? this.links,
        socials: socials ?? this.socials,
      );

  /// Picks one of the shipped backgrounds by id, and **drops**
  /// `backgroundUrl`.
  ///
  /// Read in mypubky.com's own bundle: it resolves a card with
  /// `backgroundUrl: A.backgroundUrl || i.src`, where `i` is the built-in
  /// matching `backgroundId`. So leaving the URL out makes the site resolve
  /// it, and writing one would pin a build artefact — the shipped files carry
  /// a content hash (`back2-tNt8deMM.png`) that changes at every deployment.
  ///
  /// ⚠️ And a stale one fails silently: every name under `/assets/` answers
  /// **200**, because the site serves its own index.html for anything it does
  /// not have. Measured — `back1.png` returns 815 bytes of HTML while
  /// `back1-Bw9dfpD8.png` returns 1 897 348 bytes of PNG. A status code
  /// proves nothing here.
  MypubkyCard withBuiltInBackground(String id) => copyWith(
        changes: {'backgroundId': id, 'backgroundType': 'image'},
        removals: const {'backgroundUrl'},
      );
}

/// Reads a mypubky card. No authorization of any kind: the file sits under
/// `/pub/`, which the homeserver serves to anyone who asks.
class MypubkyClient {
  MypubkyClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void close() => _client.close();

  /// The card, or null when this account has never made one — which is the
  /// common case and not an error.
  Future<MypubkyCard?> fetchCard(String pubky) async {
    final uri = Uri.parse('$homeserverBase$mypubkyCardPath')
        .replace(queryParameters: {'pubky-host': pubky});
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('mypubky: HTTP ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) return null;
    return MypubkyCard.fromJson(pubky, body);
  }
}
