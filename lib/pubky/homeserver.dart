import 'dart:convert';

import 'package:http/http.dart' as http;

import 'crockford.dart';
import 'ring_session.dart';

/// The homeserver this proof of concept writes to.
///
/// Resolving a user's own homeserver means decoding a signed pkarr packet
/// (a DNS message behind 64 bytes of signature), which is a chunk of work this
/// POC does not carry. Everyone indexed by Nexus today is on the official one;
/// an account hosted elsewhere gets a clear error rather than a silent failure.
const homeserverBase = 'https://homeserver.pubky.app';

/// Longest `short` post pubky-app-specs accepts. Enforced here so the refusal
/// happens under the text field rather than as an opaque 4xx.
const maxShortPostLength = 2000;

/// The write path was refused.
///
/// The message carries the raw response on purpose. The homeserver answers 401
/// even for a route that does not exist — authentication runs before routing,
/// measured 2026-09-07 — so a refusal alone does not say whether the problem is
/// the session or the URL. The body is what tells them apart.
class WriteUnauthorized implements Exception {
  const WriteUnauthorized(this.status, this.body);
  final int status;
  final String body;

  @override
  String toString() =>
      "Le homeserver a refusé l'écriture ($status).\n\n"
      'Cause la plus probable : la session Ring est de type « grant », qui '
      'exige un jeton porteur signé — cette version ne sait présenter qu’un '
      'cookie.\n\n'
      'Réponse du serveur : ${body.isEmpty ? "(vide)" : body}';
}

class WriteFailed implements Exception {
  const WriteFailed(this.status, this.body);
  final int status;
  final String body;

  @override
  String toString() => 'Le homeserver a répondu $status : $body';
}

/// Writes pubky-app resources on the user's behalf.
///
/// Authentication is a plain `Cookie` header. The homeserver's own OpenAPI
/// spells the scheme out: "the cookie name is the user's z-base-32 public key
/// and the value is the session secret". That is what makes writing possible
/// here without any Rust — as long as Ring handed back a cookie session.
class HomeserverClient {
  HomeserverClient({required this.session, http.Client? client})
      : _client = client ?? http.Client();

  final RingSession session;
  final http.Client _client;
  static const _timeout = Duration(seconds: 30);

  /// Legacy addressing on purpose: the documented `/storage/{user}/{path}`
  /// form answers 500 on the official homeserver (measured again 2026-09-07),
  /// while `?pubky-host=` answers 200.
  Uri _entry(String path) =>
      Uri.parse('$homeserverBase$path?pubky-host=${session.pubky}');

  Map<String, String> get _headers => {
        'Cookie': '${session.pubky}=${session.grantSecret}',
        'Content-Type': 'application/json',
      };

  /// Publishes a short post and returns its id.
  ///
  /// Optional fields are omitted rather than sent as null — that is the shape
  /// real pubky.app clients produce.
  Future<String> createShortPost(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Un post vide ne peut pas être publié.');
    }
    if (trimmed.length > maxShortPostLength) {
      throw ArgumentError(
        'Un post court est limité à $maxShortPostLength caractères '
        '(${trimmed.length} ici).',
      );
    }

    final id = newCrockfordId();
    final res = await _client
        .put(
          _entry('/pub/pubky.app/posts/$id'),
          headers: _headers,
          body: utf8.encode(jsonEncode({'content': trimmed, 'kind': 'short'})),
        )
        .timeout(_timeout);

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw WriteUnauthorized(res.statusCode, _shorten(res.body));
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw WriteFailed(res.statusCode, _shorten(res.body));
    }
    return id;
  }

  /// Reads back what was just written, straight from the homeserver.
  ///
  /// Worth doing rather than trusting the 201: Nexus lags the homeserver, so
  /// the indexer cannot confirm a fresh write, and this read can — it is the
  /// only immediate proof the post exists.
  Future<Map<String, dynamic>?> readPost(String id) async {
    final res = await _client
        .get(_entry('/pub/pubky.app/posts/$id'))
        .timeout(_timeout);
    if (res.statusCode != 200) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> deletePost(String id) async {
    final res = await _client
        .delete(_entry('/pub/pubky.app/posts/$id'), headers: _headers)
        .timeout(_timeout);
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw WriteUnauthorized(res.statusCode, _shorten(res.body));
    }
    if (res.statusCode >= 400) {
      throw WriteFailed(res.statusCode, _shorten(res.body));
    }
  }

  void close() => _client.close();

  static String _shorten(String body) =>
      body.length <= 200 ? body : '${body.substring(0, 200)}…';
}
