import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutky/pubky/grant_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a credential shaped exactly like the one Ring exports, so the parser
/// is exercised against the real format rather than a convenient one.
({String token, List<int> secret, String jti, String iss}) buildStoredGrant({
  int expiresInSeconds = 3600,
}) {
  final secret = List<int>.generate(32, (i) => (i * 7 + 3) % 256);
  const iss = 'gujx6qd8ksydh1makdphd3bxu351d9b8waqka8hfg6q7hnqkxexo';
  const jti = 'AbCdEf0123456789_-xyzQ';

  String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');

  final header = b64(utf8.encode(jsonEncode({'alg': 'EdDSA', 'typ': 'pubky-grant'})));
  final payload = b64(utf8.encode(jsonEncode({
    'iss': iss,
    'client_id': 'flutky.test',
    'cnf': 'peer',
    'jti': jti,
    'iat': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    'exp': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + expiresInSeconds,
  })));
  final jws = '$header.$payload.${b64(List<int>.filled(64, 1))}';

  return (
    token: 'pubky-grant-credential-v1:'
        'homeserverkeyz32aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:'
        '${b64(secret)}:$jws',
    secret: secret,
    jti: jti,
    iss: iss,
  );
}

void main() {
  group('Secret kind', () {
    test('recognises grant material by its version prefix', () {
      expect(isGrantSecret(buildStoredGrant().token), isTrue);
    });

    test('treats a 26-character cookie secret as a cookie', () {
      // 16 random bytes in Crockford base32, per the homeserver's own docs.
      expect(isGrantSecret('ABCDEFGHJKMNPQRSTVWXYZ0123'), isFalse);
    });
  });

  group('Stored grant', () {
    test('splits homeserver, client key and grant', () {
      final built = buildStoredGrant();
      final stored = StoredGrant.parse(built.token);

      expect(stored.homeserverPublicKey,
          'homeserverkeyz32aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      expect(stored.clientSecret, built.secret);
      expect(stored.grantJws.split('.'), hasLength(3));
    });

    test('rejects an unknown version instead of guessing', () {
      expect(
        () => StoredGrant.parse('pubky-grant-credential-v9:a:b:c.d.e'),
        throwsA(isA<GrantFormatError>()),
      );
    });

    test('rejects a client key that is not 32 bytes', () {
      expect(
        () => StoredGrant.parse('pubky-grant-credential-v1:hs:AAAA:a.b.c'),
        throwsA(isA<GrantFormatError>()),
      );
    });

    test('rejects a malformed token', () {
      expect(() => StoredGrant.parse('nawak'), throwsA(isA<GrantFormatError>()));
    });
  });

  group('Grant claims', () {
    test('reads jti, iss and exp without verifying the signature', () {
      final built = buildStoredGrant();
      final claims = GrantClaims.fromJws(StoredGrant.parse(built.token).grantJws);

      expect(claims.grantId, built.jti);
      expect(claims.issuer, built.iss);
      expect(claims.isExpired, isFalse);
    });

    test('sees an expired grant as expired', () {
      final built = buildStoredGrant(expiresInSeconds: -60);
      final claims = GrantClaims.fromJws(StoredGrant.parse(built.token).grantJws);

      expect(claims.isExpired, isTrue);
    });

    test('refuses a JWS that is not three parts', () {
      expect(() => GrantClaims.fromJws('a.b'), throwsA(isA<GrantFormatError>()));
    });
  });

  group('Proof of possession', () {
    test('signs a JWS the homeserver could verify', () async {
      final built = buildStoredGrant();
      final jws = await signPopProof(
        clientSecret: built.secret,
        homeserverPublicKey: 'audiencekey',
        grantId: built.jti,
      );

      final parts = jws.split('.');
      expect(parts, hasLength(3));

      String decode(String s) =>
          utf8.decode(base64Url.decode(s.padRight(s.length + ((4 - s.length % 4) % 4), '=')));

      final header = jsonDecode(decode(parts[0])) as Map<String, dynamic>;
      expect(header['alg'], 'EdDSA');
      expect(header['typ'], 'pubky-pop');

      final payload = jsonDecode(decode(parts[1])) as Map<String, dynamic>;
      expect(payload['aud'], 'audiencekey');
      expect(payload['gid'], built.jti);
      expect(payload['nonce'], isA<String>());
      expect((payload['nonce'] as String), hasLength(22));
      expect(payload['iat'], isA<int>());

      // The claim that matters: the signature verifies against the public key
      // derived from the seed. A wrong signing input or a wrong key would pass
      // every check above and fail this one.
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPairFromSeed(built.secret);
      final publicKey = await keyPair.extractPublicKey();
      final signature = Signature(
        base64Url.decode(parts[2].padRight(
            parts[2].length + ((4 - parts[2].length % 4) % 4), '=')),
        publicKey: publicKey,
      );

      expect(
        await algorithm.verify(
          utf8.encode('${parts[0]}.${parts[1]}'),
          signature: signature,
        ),
        isTrue,
      );
    });

    test('a fresh nonce every time, so a proof cannot be replayed', () async {
      final built = buildStoredGrant();
      Future<String> nonce() async {
        final jws = await signPopProof(
          clientSecret: built.secret,
          homeserverPublicKey: 'aud',
          grantId: built.jti,
        );
        final p = jws.split('.')[1];
        final payload = jsonDecode(utf8
            .decode(base64Url.decode(p.padRight(p.length + ((4 - p.length % 4) % 4), '='))));
        return (payload as Map<String, dynamic>)['nonce'] as String;
      }

      expect(await nonce(), isNot(await nonce()));
    });
  });

  group('Bearer token', () {
    test('asks for a refresh inside the slack window', () {
      final soon = BearerToken('t', DateTime.now().toUtc().add(const Duration(minutes: 2)));
      final later = BearerToken('t', DateTime.now().toUtc().add(const Duration(minutes: 30)));

      expect(soon.needsRefresh, isTrue);
      expect(later.needsRefresh, isFalse);
    });
  });
}
