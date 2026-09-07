/// Grant-based authentication, reimplemented in Dart.
///
/// Pubky Ring 1.19+ hands back a *grant* secret rather than a cookie one. A
/// grant is not a bearer token: it is refresh material that must be exchanged
/// at the homeserver for a short-lived opaque bearer, proving along the way
/// that we hold the client key the grant is bound to.
///
/// The exchange is three steps, all reproducible without Rust:
///
///   1. decode the stored credential — it is plain text with `:` separators
///   2. sign a Proof-of-Possession JWS (Ed25519) over the grant id
///   3. POST {grant, pop} to /auth/grant/session and keep the bearer
///
/// Everything here follows `pubky-sdk/src/actors/auth/grant/credential.rs`
/// and `pubky-common/src/auth/{jws,pop}.rs`.
library;

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

const _storedPrefix = 'pubky-grant-credential-v1';
const _storedPrefixFamily = 'pubky-grant-credential-';
const _popTyp = 'pubky-pop';

/// Bearers last an hour; refresh well before that so a slow request never
/// lands on an expired token. Mirrors the SDK's own slack.
const _refreshSlack = Duration(minutes: 5);

/// True when Ring handed back grant material rather than a cookie secret.
///
/// The check is a plain prefix on purpose: the stored credential carries its
/// own version tag in clear text, so this is a fact, not a heuristic.
bool isGrantSecret(String secret) => secret.startsWith(_storedPrefixFamily);

class GrantFormatError implements Exception {
  const GrantFormatError(this.message);
  final String message;

  @override
  String toString() => message;
}

class GrantExchangeError implements Exception {
  const GrantExchangeError(this.status, this.body);
  final int status;
  final String body;

  @override
  String toString() =>
      "L'échange du grant contre un jeton a échoué ($status) : "
      '${body.isEmpty ? "(réponse vide)" : body}';
}

/// The three parts packed into an exported grant secret.
class StoredGrant {
  const StoredGrant({
    required this.homeserverPublicKey,
    required this.clientSecret,
    required this.grantJws,
  });

  /// z-base-32 key of the homeserver this grant is bound to. Doubles as the
  /// PoP audience, which is what prevents replaying the proof elsewhere.
  final String homeserverPublicKey;

  /// 32-byte Ed25519 seed of the client key the grant's `cnf` binds.
  final List<int> clientSecret;

  /// The user-signed grant, in JWS compact form.
  final String grantJws;

  /// Format: `pubky-grant-credential-v1:<homeserver>:<secret>:<grant_jws>`.
  /// The JWS contains `.` but no `:`, so splitting on the first three colons
  /// is unambiguous.
  factory StoredGrant.parse(String token) {
    final parts = token.split(':');
    if (parts.length < 4) {
      throw const GrantFormatError('Secret de grant malformé.');
    }
    if (parts[0] != _storedPrefix) {
      throw GrantFormatError(
        'Version de secret de grant non gérée : ${parts[0]}.',
      );
    }

    final secret = base64Url.decode(_pad(parts[2]));
    if (secret.length != 32) {
      throw GrantFormatError(
        'La clé cliente doit faire 32 octets (${secret.length} ici).',
      );
    }

    final jws = parts.sublist(3).join(':');
    if (jws.isEmpty) {
      throw const GrantFormatError('Le grant est vide.');
    }

    return StoredGrant(
      homeserverPublicKey: parts[1],
      clientSecret: secret,
      grantJws: jws,
    );
  }
}

/// The claims we need out of the grant. Read without verifying the signature:
/// the homeserver verifies it, we only need the id to bind our proof to.
class GrantClaims {
  const GrantClaims({required this.grantId, required this.issuer, required this.expiresAt});

  final String grantId; // jti
  final String issuer; // iss — the user's own key
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  factory GrantClaims.fromJws(String jws) {
    final parts = jws.split('.');
    if (parts.length != 3) {
      throw const GrantFormatError('Grant JWS malformé.');
    }
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(base64Url.decode(_pad(parts[1]))))
          as Map<String, dynamic>;
    } catch (e) {
      throw GrantFormatError('Charge utile du grant illisible : $e');
    }

    final jti = payload['jti']?.toString();
    final iss = payload['iss']?.toString();
    final exp = payload['exp'];
    if (jti == null || iss == null || exp is! num) {
      throw const GrantFormatError('Le grant ne porte pas jti, iss et exp.');
    }

    return GrantClaims(
      grantId: jti,
      issuer: iss,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true),
    );
  }
}

/// A bearer minted by the homeserver, with the moment it stops being usable.
class BearerToken {
  const BearerToken(this.token, this.expiresAt);
  final String token;
  final DateTime expiresAt;

  bool get needsRefresh =>
      DateTime.now().toUtc().add(_refreshSlack).isAfter(expiresAt);
}

/// Signs a Proof-of-Possession JWS with the grant's client key.
///
/// Header `{"alg":"EdDSA","typ":"pubky-pop"}`, payload
/// `{"aud":…,"gid":…,"nonce":…,"iat":…}`, both base64url without padding,
/// signature over `header.payload`.
Future<String> signPopProof({
  required List<int> clientSecret,
  required String homeserverPublicKey,
  required String grantId,
}) async {
  final header = _b64(utf8.encode(jsonEncode({'alg': 'EdDSA', 'typ': _popTyp})));
  final payload = _b64(utf8.encode(jsonEncode({
    'aud': homeserverPublicKey,
    'gid': grantId,
    'nonce': _nonce(),
    'iat': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
  })));

  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(clientSecret);
  final signature = await algorithm.sign(
    utf8.encode('$header.$payload'),
    keyPair: keyPair,
  );

  return '$header.$payload.${_b64(signature.bytes)}';
}

/// Exchanges the grant for a fresh bearer at `POST /auth/grant/session`.
///
/// [baseUrl] is where the homeserver answers over HTTP; the `pubky-host`
/// header names the user whose tenant we are addressing.
Future<BearerToken> exchangeGrantForBearer({
  required StoredGrant stored,
  required GrantClaims claims,
  required String baseUrl,
  required http.Client client,
}) async {
  final pop = await signPopProof(
    clientSecret: stored.clientSecret,
    homeserverPublicKey: stored.homeserverPublicKey,
    grantId: claims.grantId,
  );

  final res = await client
      .post(
        Uri.parse('$baseUrl/auth/grant/session'),
        headers: {
          'Content-Type': 'application/json',
          'pubky-host': claims.issuer,
        },
        body: jsonEncode({'grant': stored.grantJws, 'pop': pop}),
      )
      .timeout(const Duration(seconds: 30));

  if (res.statusCode != 200 && res.statusCode != 201) {
    throw GrantExchangeError(res.statusCode, _shorten(res.body));
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  } catch (e) {
    throw GrantExchangeError(res.statusCode, 'réponse illisible : $e');
  }

  final token = body['token']?.toString();
  if (token == null || token.isEmpty) {
    throw GrantExchangeError(res.statusCode, 'réponse sans jeton');
  }

  final expiresAt = (body['session'] as Map<String, dynamic>?)?['token_expires_at'];
  return BearerToken(
    token,
    expiresAt is num
        ? DateTime.fromMillisecondsSinceEpoch(expiresAt.toInt() * 1000, isUtc: true)
        // No expiry reported: assume the documented hour, minus the slack.
        : DateTime.now().toUtc().add(const Duration(minutes: 55)),
  );
}

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String _pad(String s) => s.padRight(s.length + ((4 - s.length % 4) % 4), '=');

/// 128 bits of randomness, base64url — same shape as the SDK's RandomId.
String _nonce() {
  final rng = Random.secure();
  return _b64(List<int>.generate(16, (_) => rng.nextInt(256)));
}

String _shorten(String body) =>
    body.length <= 300 ? body : '${body.substring(0, 300)}…';
