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
      name: nonEmpty(details['name']) ?? 'Sans nom',
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
  String toString() => 'Nexus a répondu $status\u00A0: $body';
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

  void close() => _client.close();

  static String _shorten(String body) =>
      body.length <= 200 ? body : '${body.substring(0, 200)}…';
}
