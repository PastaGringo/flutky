import 'dart:convert';

import 'package:http/http.dart' as http;

/// Nexus is the indexer behind pubky.app. Its v0 API is public, serves
/// `access-control-allow-origin: *`, and needs no authentication for reads —
/// which is why this proof of concept displays a profile without any Rust.
const nexusBase = 'https://nexus.pubky.app';

/// Shape mirrors `GET /v0/user/{user_id}` as served today (nexus-webapi 0.4.1).
class PubkyProfile {
  const PubkyProfile({
    required this.id,
    required this.name,
    required this.bio,
    required this.status,
    required this.links,
    required this.counts,
    required this.tags,
    required this.indexedAt,
  });

  final String id;
  final String name;
  final String? bio;
  final String? status;
  final List<ProfileLink> links;
  final Map<String, int> counts;
  final List<ProfileTag> tags;
  final DateTime? indexedAt;

  /// Nexus renders avatars itself, keyed by user id — no need to resolve the
  /// `pubky://.../files/<id>` URI carried in `details.image`.
  String get avatarUrl => '$nexusBase/static/avatar/$id';

  factory PubkyProfile.fromJson(Map<String, dynamic> json) {
    final details = (json['details'] as Map<String, dynamic>?) ?? const {};
    final rawCounts = (json['counts'] as Map<String, dynamic>?) ?? const {};
    final rawLinks = (details['links'] as List<dynamic>?) ?? const [];
    final rawTags = (json['tags'] as List<dynamic>?) ?? const [];
    final ms = details['indexed_at'];

    String? nonEmpty(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return PubkyProfile(
      id: details['id']?.toString() ?? '',
      name: nonEmpty(details['name']) ?? '',
      bio: nonEmpty(details['bio']),
      status: nonEmpty(details['status']),
      links: rawLinks
          .whereType<Map<String, dynamic>>()
          .map(ProfileLink.fromJson)
          .toList(),
      counts: {
        for (final e in rawCounts.entries)
          if (e.value is num) e.key: (e.value as num).toInt(),
      },
      tags: rawTags.whereType<Map<String, dynamic>>().map(ProfileTag.fromJson).toList(),
      indexedAt: ms is num
          ? DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true).toLocal()
          : null,
    );
  }
}

class ProfileLink {
  const ProfileLink({required this.title, required this.url});
  final String title;
  final String url;

  factory ProfileLink.fromJson(Map<String, dynamic> json) => ProfileLink(
        title: json['title']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
      );
}

class ProfileTag {
  const ProfileTag({required this.label, required this.taggersCount});
  final String label;
  final int taggersCount;

  factory ProfileTag.fromJson(Map<String, dynamic> json) => ProfileTag(
        label: json['label']?.toString() ?? '',
        taggersCount: (json['taggers_count'] as num?)?.toInt() ?? 0,
      );
}

/// Streams Nexus serves for a given observer. Every value here was exercised
/// against the live API: `author` and `post_replies` need extra ids and are
/// left out on purpose.
enum FeedSource {
  following('following'),
  friends('friends'),
  all('all'),
  bookmarks('bookmarks');

  const FeedSource(this.apiValue);
  final String apiValue;
}

/// One entry of a stream. Mirrors `GET /v0/stream/posts`.
class PubkyPost {
  const PubkyPost({
    required this.id,
    required this.author,
    required this.content,
    required this.kind,
    required this.attachments,
    required this.counts,
    required this.tags,
    required this.indexedAt,
    this.repostedUri,
    this.repliedUri,
  });

  final String id;
  final String author;
  final String content;

  /// short | long | image | video | link | file | collection | unknown
  final String kind;

  /// `pubky://<author>/pub/pubky.app/files/<fileId>` URIs.
  final List<String> attachments;

  final Map<String, int> counts;
  final List<ProfileTag> tags;
  final DateTime? indexedAt;

  /// `pubky://<author>/pub/pubky.app/posts/<id>` of the post this one reposts,
  /// when it does. A repost is an ordinary post that points at another; with
  /// content of its own it reads as a quote, without it as a plain share.
  final String? repostedUri;

  /// Same, for a reply.
  final String? repliedUri;

  bool get isRepost => repostedUri != null;
  bool get isReply => repliedUri != null;

  /// True when the repost carries words of its own — a quote rather than a
  /// bare share. Worth distinguishing: a quote deserves its own text on top.
  bool get isQuote => isRepost && content.trim().isNotEmpty;

  /// Nexus renders three sizes; `feed` is the one sized for a timeline —
  /// measured at 7.7 kB WebP against 149 kB JPEG for `main` on the same image.
  List<String> imageUrls({String variant = 'feed'}) => attachments
      .map((uri) => _fileUrl(uri, variant))
      .whereType<String>()
      .toList();

  static String? _fileUrl(String pubkyUri, String variant) {
    // pubky://<author>/pub/pubky.app/files/<fileId>
    final match = RegExp(r'^pubky://([^/]+)/pub/pubky\.app/files/([^/?#]+)')
        .firstMatch(pubkyUri);
    if (match == null) return null;
    return '$nexusBase/static/files/${match.group(1)}/${match.group(2)}/$variant';
  }

  /// Splits `pubky://<author>/pub/pubky.app/posts/<id>` into its two useful
  /// halves. Returns null for anything that is not a post URI.
  static ({String author, String id})? parsePostUri(String uri) {
    final m = RegExp(r'^pubky://([^/]+)/pub/pubky\.app/posts/([^/?#]+)')
        .firstMatch(uri);
    return m == null ? null : (author: m.group(1)!, id: m.group(2)!);
  }

  factory PubkyPost.fromJson(Map<String, dynamic> json) {
    final details = (json['details'] as Map<String, dynamic>?) ?? const {};
    final rawCounts = (json['counts'] as Map<String, dynamic>?) ?? const {};
    final rawTags = (json['tags'] as List<dynamic>?) ?? const [];
    final rel = (json['relationships'] as Map<String, dynamic>?) ?? const {};
    final ms = details['indexed_at'];

    return PubkyPost(
      id: details['id']?.toString() ?? '',
      author: details['author']?.toString() ?? '',
      content: details['content']?.toString() ?? '',
      kind: details['kind']?.toString() ?? 'unknown',
      attachments: (details['attachments'] as List<dynamic>? ?? const [])
          .map((a) => a.toString())
          .toList(),
      counts: {
        for (final e in rawCounts.entries)
          if (e.value is num) e.key: (e.value as num).toInt(),
      },
      tags: rawTags.whereType<Map<String, dynamic>>().map(ProfileTag.fromJson).toList(),
      indexedAt: ms is num
          ? DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true).toLocal()
          : null,
      repostedUri: rel['reposted']?.toString(),
      repliedUri: rel['replied']?.toString(),
    );
  }
}

/// The account exists as a keypair but Nexus has never indexed it. Nexus only
/// learns about a key once it is wired into the social graph, so a brand new
/// or self-hosted account legitimately lands here.
class ProfileNotIndexed implements Exception {
  const ProfileNotIndexed(this.pubky);
  final String pubky;
}

class NexusError implements Exception {
  const NexusError(this.status, this.body);
  final int status;
  final String body;

  @override
  String toString() => 'Nexus answered $status\u00A0: $body';
}

class NexusClient {
  NexusClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  /// Reads a profile, asking Nexus to index the key first if it does not know
  /// it yet. The retry matters in practice: the indexer lags the homeserver,
  /// so a freshly ingested key is not readable on the very next call.
  Future<PubkyProfile> fetchProfile(String pubky) async {
    try {
      return await _getProfile(pubky);
    } on ProfileNotIndexed {
      final accepted = await requestIngest(pubky);
      if (!accepted) rethrow;
      await Future<void>.delayed(const Duration(seconds: 3));
      return _getProfile(pubky);
    }
  }

  Future<PubkyProfile> _getProfile(String pubky) async {
    final res = await _client
        .get(Uri.parse('$nexusBase/v0/user/$pubky'))
        .timeout(_timeout);

    if (res.statusCode == 404) throw ProfileNotIndexed(pubky);
    if (res.statusCode != 200) {
      throw NexusError(res.statusCode, _shorten(res.body));
    }
    return PubkyProfile.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// `PUT /v0/ingest/{user_id}` asks Nexus to pull this key's events from its
  /// homeserver. Returns whether the request was accepted at all.
  Future<bool> requestIngest(String pubky) async {
    try {
      final res = await _client
          .put(Uri.parse('$nexusBase/v0/ingest/$pubky'))
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Reads a page of the timeline.
  ///
  /// `limit` is clamped to what the API accepts (BoundedLimit_10_50 in its
  /// OpenAPI), and `skip` walks the pages. `observerId` is what personalises
  /// the stream — without it, `following` silently degrades into the global
  /// timeline.
  Future<List<PubkyPost>> fetchStream({
    required FeedSource source,
    String? observerId,
    int limit = 20,
    int skip = 0,
  }) async {
    final query = <String, String>{
      'source': source.apiValue,
      'limit': '${limit.clamp(1, 50)}',
      'skip': '$skip',
      'include_attachment_metadata': 'true',
      // Both are needed: observer_id personalises the stream, viewer_id fills
      // in the per-post relationships.
      'observer_id': ?observerId,
      'viewer_id': ?observerId,
    };

    final res = await _client
        .get(Uri.parse('$nexusBase/v0/stream/posts').replace(queryParameters: query))
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw NexusError(res.statusCode, _shorten(res.body));
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PubkyPost.fromJson)
        .toList();
  }

  /// Resolves post authors in one round trip. A stream only carries author
  /// keys, so without this every card would show a 52-character string.
  Future<Map<String, PubkyProfile>> fetchUsersByIds(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return const {};

    final res = await _client
        .post(
          Uri.parse('$nexusBase/v0/stream/users/by_ids'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'user_ids': unique}),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw NexusError(res.statusCode, _shorten(res.body));
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! List) return const {};

    final out = <String, PubkyProfile>{};
    for (final entry in decoded.whereType<Map<String, dynamic>>()) {
      final profile = PubkyProfile.fromJson(entry);
      if (profile.id.isNotEmpty) out[profile.id] = profile;
    }
    return out;
  }

  /// Reads a single post — used to show what a repost or a reply points at.
  Future<PubkyPost?> fetchPost(String author, String id) async {
    try {
      final res = await _client
          .get(Uri.parse('$nexusBase/v0/post/$author/$id'))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      return PubkyPost.fromJson(decoded);
    } catch (_) {
      // A quoted post that cannot be loaded is not an error worth surfacing:
      // the card shows the quote as unavailable and the rest still reads.
      return null;
    }
  }

  /// Reads the account's notifications, newest first.
  Future<List<PubkyNotification>> fetchNotifications({
    required String pubky,
    int limit = 30,
  }) async {
    final res = await _client
        .get(Uri.parse('$nexusBase/v0/user/$pubky/notifications?limit=$limit'))
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw NexusError(res.statusCode, _shorten(res.body));
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PubkyNotification.fromJson)
        .toList();
  }

  void close() => _client.close();

  static String _shorten(String body) =>
      body.length <= 200 ? body : '${body.substring(0, 200)}…';
}

/// The kinds Nexus emits, read from its OpenAPI rather than guessed.
enum NotificationKind {
  follow,
  newFriend,
  lostFriend,
  tagPost,
  tagProfile,
  untagPost,
  untagProfile,
  reply,
  repost,
  mention,
  postDeleted,
  postEdited,
  unknown;

  static NotificationKind parse(String? raw) => switch (raw) {
        'follow' => follow,
        'new_friend' => newFriend,
        'lost_friend' => lostFriend,
        'tag_post' => tagPost,
        'tag_profile' => tagProfile,
        'untag_post' => untagPost,
        'untag_profile' => untagProfile,
        'reply' => reply,
        'repost' => repost,
        'mention' => mention,
        'post_deleted' => postDeleted,
        'post_edited' => postEdited,
        // Nexus can add kinds without warning; an unknown one is shown as
        // such rather than dropped, so nothing disappears silently.
        _ => unknown,
      };
}

/// One entry of `GET /v0/user/{id}/notifications`.
class PubkyNotification {
  const PubkyNotification({
    required this.kind,
    required this.rawKind,
    required this.timestamp,
    this.actor,
    this.label,
    this.postUri,
  });

  final NotificationKind kind;

  /// Kept for the unknown case, so the interface can name what it received.
  final String rawKind;

  final DateTime timestamp;

  /// Whoever caused it. The field carrying it differs per kind, hence the
  /// several fallbacks below.
  final String? actor;

  /// Tag label, for the tag kinds.
  final String? label;

  /// The post concerned, when there is one.
  final String? postUri;

  factory PubkyNotification.fromJson(Map<String, dynamic> json) {
    final body = (json['body'] as Map<String, dynamic>?) ?? const {};
    final ms = json['timestamp'];

    String? first(List<String> keys) {
      for (final k in keys) {
        final v = body[k]?.toString();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    return PubkyNotification(
      kind: NotificationKind.parse(body['type']?.toString()),
      rawKind: body['type']?.toString() ?? 'unknown',
      timestamp: ms is num
          ? DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true).toLocal()
          : DateTime.now(),
      actor: first(const [
        'followed_by',
        'unfollowed_by',
        'tagged_by',
        'untagged_by',
        'replied_by',
        'reposted_by',
        'mentioned_by',
        'deleted_by',
        'edited_by',
      ]),
      label: body['tag_label']?.toString(),
      postUri: first(const [
        'post_uri',
        'reply_uri',
        'repost_uri',
        'parent_post_uri',
        'linked_uri',
        'deleted_uri',
        'edited_uri',
      ]),
    );
  }
}
