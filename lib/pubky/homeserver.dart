import 'dart:convert';

import 'package:http/http.dart' as http;

import 'crockford.dart';
import 'grant_auth.dart';
import 'ring_session.dart';

/// The homeserver this proof of concept writes to.
///
/// Resolving a user's own homeserver means decoding a signed pkarr packet
/// (a DNS message behind 64 bytes of signature), which this POC does not carry.
/// Everyone Nexus indexes today is on the official one; an account hosted
/// elsewhere gets a clear error rather than a silent failure.
const homeserverBase = 'https://homeserver.pubky.app';

/// Longest `short` post pubky-app-specs accepts. Enforced here so the refusal
/// happens under the text field rather than as an opaque 4xx.
const maxShortPostLength = 2000;

/// How the session authenticates writes. Which one applies is decided by the
/// secret's own format, not by guesswork.
enum AuthKind {
  /// Ring ≤ 1.18: a 26-character session secret presented as a cookie whose
  /// name is the user's public key.
  cookie('cookie'),

  /// Ring ≥ 1.19: refresh material exchanged for a short-lived bearer.
  grant('grant');

  const AuthKind(this.label);
  final String label;
}

class WriteUnauthorized implements Exception {
  const WriteUnauthorized(this.status, this.body, this.kind);
  final int status;
  final String body;
  final AuthKind kind;

  @override
  String toString() =>
      "Le homeserver a refusé l'écriture ($status), authentification "
      '« ${kind.label} ».\n\nRéponse du serveur : '
      '${body.isEmpty ? "(vide)" : body}';
}

class WriteFailed implements Exception {
  const WriteFailed(this.status, this.body);
  final int status;
  final String body;

  @override
  String toString() => 'Le homeserver a répondu $status : $body';
}

/// Writes pubky-app resources on the user's behalf.
class HomeserverClient {
  HomeserverClient({required this.session, http.Client? client})
      : _client = client ?? http.Client();

  final RingSession session;
  final http.Client _client;
  static const _timeout = Duration(seconds: 30);

  BearerToken? _bearer;

  AuthKind get authKind =>
      isGrantSecret(session.grantSecret) ? AuthKind.grant : AuthKind.cookie;

  /// Legacy addressing on purpose: the documented `/storage/{user}/{path}`
  /// form answers 500 on the official homeserver (measured again 2026-09-07),
  /// while `?pubky-host=` answers 200.
  Uri _entry(String path) =>
      Uri.parse('$homeserverBase$path?pubky-host=${session.pubky}');

  /// Builds the auth header, minting or refreshing a bearer when the session
  /// is grant-based. A cookie session needs no round trip.
  Future<Map<String, String>> _authHeaders() async {
    if (authKind == AuthKind.cookie) {
      return {'Cookie': '${session.pubky}=${session.grantSecret}'};
    }

    final current = _bearer;
    if (current != null && !current.needsRefresh) {
      return {'Authorization': 'Bearer ${current.token}'};
    }

    final stored = StoredGrant.parse(session.grantSecret);
    final claims = GrantClaims.fromJws(stored.grantJws);
    if (claims.isExpired) {
      throw const GrantFormatError(
        'Le grant a expiré. Il faut se reconnecter via Pubky Ring.',
      );
    }

    final fresh = await exchangeGrantForBearer(
      stored: stored,
      claims: claims,
      baseUrl: homeserverBase,
      client: _client,
    );
    _bearer = fresh;
    return {'Authorization': 'Bearer ${fresh.token}'};
  }

  /// Mints a token without writing anything — used to tell the user whether
  /// publishing will work before they have typed a word.
  Future<void> checkWriteAccess() async {
    await _authHeaders();
  }

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
          headers: {
            ...await _authHeaders(),
            'Content-Type': 'application/json',
          },
          body: utf8.encode(jsonEncode({'content': trimmed, 'kind': 'short'})),
        )
        .timeout(_timeout);

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw WriteUnauthorized(res.statusCode, _shorten(res.body), authKind);
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
        .delete(_entry('/pub/pubky.app/posts/$id'), headers: await _authHeaders())
        .timeout(_timeout);
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw WriteUnauthorized(res.statusCode, _shorten(res.body), authKind);
    }
    if (res.statusCode >= 400) {
      throw WriteFailed(res.statusCode, _shorten(res.body));
    }
  }

  void close() => _client.close();

  static String _shorten(String body) =>
      body.length <= 300 ? body : '${body.substring(0, 300)}…';
}
