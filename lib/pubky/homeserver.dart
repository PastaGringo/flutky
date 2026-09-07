import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'blake3.dart';
import 'cookie_auth.dart';
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

/// What pubky-app-specs allows for one blob, and what the homeserver accepts
/// in one request — the two happen to agree at 100 MB.
const maxBlobBytes = 100 * 1024 * 1024;

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

  /// Longer, because this one carries megabytes over a phone connection.
  static const _uploadTimeout = Duration(minutes: 3);

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
      // The exported token is `<key>:<secret>`, not the cookie value itself.
      final credential = CookieCredential.parse(
        session.grantSecret,
        sessionPubky: session.pubky,
      );
      return {'Cookie': credential.header};
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

  /// Checks that the homeserver actually accepts our credentials, without
  /// writing anything.
  ///
  /// A grant is proven by minting a bearer — the exchange either works or
  /// throws. A cookie proves nothing locally, so it has to be presented to
  /// `GET /session`: building the header is not a check, and treating it as
  /// one reports "write open" on a session the server will refuse.
  Future<void> checkWriteAccess() async {
    final headers = await _authHeaders();
    if (authKind == AuthKind.grant) return; // the exchange above is the proof

    final res = await _client
        .get(
          Uri.parse('$homeserverBase/session?pubky-host=${session.pubky}'),
          headers: headers,
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw WriteUnauthorized(res.statusCode, _shorten(res.body), authKind);
    }
  }

  /// Publishes a short post and returns its id.
  ///
  /// Optional fields are omitted rather than sent as null — that is the shape
  /// real pubky.app clients produce.
  /// Publishes a post, optionally carrying attachments.
  ///
  /// `kind` follows what is attached: pubky-app writes `image` for a post with
  /// a picture and `short` otherwise. Measured on a real post rather than
  /// guessed, along with the shape of the record — optional fields are
  /// **omitted**, never written as null.
  Future<String> createShortPost(
    String content, {
    List<String> attachments = const [],
  }) async {
    final trimmed = content.trim();
    // A picture is content: only a post with neither text nor attachment is
    // empty.
    if (trimmed.isEmpty && attachments.isEmpty) {
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
          body: utf8.encode(jsonEncode({
            'content': trimmed,
            'kind': attachments.isEmpty ? 'short' : 'image',
            if (attachments.isNotEmpty) 'attachments': attachments,
          })),
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

  /// Uploads the bytes of a picture, and returns the `pubky://` URI to attach.
  ///
  /// Three writes, in an order that matters. The blob comes first, because its
  /// **id is its content**: `Crockford(BLAKE3(bytes)[..16])`, not a name we
  /// choose. Then the file record that describes it. Then the post that points
  /// at the file. Any earlier order would publish a record pointing at
  /// something that does not exist yet.
  ///
  /// A wrong blob id does not fail: the homeserver stores the bytes happily
  /// and the indexer ignores the post, in silence. Hence the hash being tested
  /// against the official vectors, against pubky-app-specs' own vector, and
  /// against a blob published by another client.
  Future<String> uploadImage(
    Uint8List bytes, {
    required String name,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('Une image vide ne peut pas être envoyée.');
    }
    if (bytes.length > maxBlobBytes) {
      throw ArgumentError(
        'Image trop lourde : ${bytes.length ~/ (1024 * 1024)} Mo pour un '
        'maximum de ${maxBlobBytes ~/ (1024 * 1024)} Mo.',
      );
    }

    final hash = blake3(bytes);
    final blobId = crockfordBytes(hash.sublist(0, hash.length ~/ 2));
    await _put(
      '/pub/pubky.app/blobs/$blobId',
      bytes,
      contentType: 'application/octet-stream',
    );

    final fileId = newCrockfordId();
    final record = <String, dynamic>{
      'content_type': contentType,
      'created_at': DateTime.now().toUtc().microsecondsSinceEpoch,
      'name': name,
      'size': bytes.length,
      'src': 'pubky://${session.pubky}/pub/pubky.app/blobs/$blobId',
    };
    await _put(
      '/pub/pubky.app/files/$fileId',
      utf8.encode(jsonEncode(record)),
      contentType: 'application/json',
    );

    return 'pubky://${session.pubky}/pub/pubky.app/files/$fileId';
  }

  /// One authenticated write, with the refusals told apart.
  Future<void> _put(
    String path,
    List<int> body, {
    required String contentType,
  }) async {
    final res = await _client
        .put(
          _entry(path),
          headers: {...await _authHeaders(), 'Content-Type': contentType},
          body: body,
        )
        .timeout(_uploadTimeout);

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw WriteUnauthorized(res.statusCode, _shorten(res.body), authKind);
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw WriteFailed(res.statusCode, _shorten(res.body));
    }
  }

  /// Follows an account.
  ///
  /// The resource is named after the target key — no computed id — and its
  /// body carries only a creation time, in microseconds. Measured on a real
  /// follow: `{"created_at":1750359659005000}`.
  Future<void> follow(String targetPubky) async {
    final res = await _client
        .put(
          _entry('/pub/pubky.app/follows/$targetPubky'),
          headers: {
            ...await _authHeaders(),
            'Content-Type': 'application/json',
          },
          body: utf8.encode(jsonEncode({
            'created_at': DateTime.now().toUtc().microsecondsSinceEpoch,
          })),
        )
        .timeout(_timeout);

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw WriteUnauthorized(res.statusCode, _shorten(res.body), authKind);
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw WriteFailed(res.statusCode, _shorten(res.body));
    }
  }

  /// Stops following. Deleting a resource that is not there is not an error
  /// worth surfacing — the end state is the one the user asked for.
  Future<void> unfollow(String targetPubky) async {
    final res = await _client
        .delete(
          _entry('/pub/pubky.app/follows/$targetPubky'),
          headers: await _authHeaders(),
        )
        .timeout(_timeout);

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw WriteUnauthorized(res.statusCode, _shorten(res.body), authKind);
    }
    if (res.statusCode >= 400 && res.statusCode != 404) {
      throw WriteFailed(res.statusCode, _shorten(res.body));
    }
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
