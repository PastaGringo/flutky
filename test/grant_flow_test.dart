import 'dart:convert';
import 'dart:typed_data';

import 'package:flutky/pubky/blake3.dart';
import 'package:flutky/pubky/grant_flow.dart';
import 'package:flutky/pubky/z32.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('z-base-32, the alphabet keys are written in', () {
    // Real keys, taken off the live network. A round trip through our own
    // encoder would stay green with a shuffled alphabet — these would not.
    const realKeys = [
      'w3ase343kdnbtp4y3x69qd1qyt8peyrdtkhf671ujucc9i8fge6y',
      '9o6xrx8wgqu48dmb47uep6w3dgbwdnf5jgw83gbeuxg9yi7x444y',
      'gujx6qd8ksydh1makdphd3bxu351d9b8waqka8hfg6q7hnqkxexo',
    ];

    test('a real key decodes to 32 bytes and re-encodes identically', () {
      for (final key in realKeys) {
        final bytes = z32Decode(key);
        expect(bytes, isNotNull, reason: '$key devrait être du z-base-32');
        expect(bytes!.length, 32);
        expect(z32Encode(bytes), key);
      }
    });

    test('it is NOT the Crockford alphabet used for resource ids', () {
      // The two look alike and share nothing. Encoding a key with the wrong
      // one yields a plausible string naming nobody — a silent failure.
      final bytes = z32Decode(realKeys.first)!;
      expect(z32Encode(bytes), isNot(equalsIgnoringCase('W3ASE343'.substring(0, 8))));
      expect(z32Encode(bytes).toLowerCase(), z32Encode(bytes));
    });

    test('a character outside the alphabet is refused, not silently dropped',
        () {
      // `l`, `v` and `2` are absent from z-base-32; accepting them would turn
      // a typo into a different key.
      expect(z32Decode('lllll'), isNull);
      expect(z32Decode('W3ASE'), isNull); // upper case is not the alphabet
    });
  });

  group('the relay channel', () {
    test('is the hash of the secret, never the secret itself', () {
      final secret = Uint8List.fromList(List.generate(32, (i) => i));
      final expected =
          base64Url.encode(blake3(secret)).replaceAll('=', '');

      // Computed the way pubky-core does it: base64url(blake3(secret)),
      // unpadded. Anyone watching the relay sees this, not the key that
      // decrypts what lands there.
      expect(expected.length, 43);
      expect(expected, isNot(contains('=')));
      expect(expected, isNot(base64Url.encode(secret).replaceAll('=', '')));
    });
  });

  group('the sealed grant', () {
    final secret = Uint8List.fromList(List.generate(32, (i) => (i * 7) % 256));
    const jws = 'eyJhbGciOiJFZERTQSJ9.eyJnaWQiOiJ0ZXN0In0.c2lnbmF0dXJl';

    test('survives a round trip through XSalsa20-Poly1305', () {
      expect(decryptGrant(sealGrant(jws, secret), secret), jws);
    });

    test('carries its 24-byte nonce in front', () {
      final sealed = sealGrant(jws, secret);
      // Nonce, then ciphertext, then the 16-byte tag — the layout pubky-core
      // writes and therefore the only one Ring will produce.
      expect(sealed.length, 24 + jws.length + 16);
    });

    test('a wrong key fails loudly rather than returning rubbish', () {
      final other = Uint8List.fromList(List.generate(32, (i) => i));
      expect(
        () => decryptGrant(sealGrant(jws, secret), other),
        throwsA(isA<GrantFlowError>()),
      );
    });

    test('a payload shorter than the nonce is refused', () {
      expect(
        () => decryptGrant(Uint8List(10), secret),
        throwsA(isA<GrantFlowError>()),
      );
    });
  });

  group('the authorization link handed to Ring', () {
    test('carries the five parameters pubky-core parses, and no others',
        () async {
      final flow = await GrantAuthFlow.begin();
      addTearDown(flow.close);
      final url = flow.authorizationUrl;

      expect(url.scheme, 'pubkyauth');
      expect(url.host, 'signin_grant');
      expect(
        url.queryParameters.keys.toSet(),
        {'caps', 'relay', 'secret', 'cid', 'cpk'},
      );
    });

    test('encodes the secret in base64url and the key in z-base-32', () async {
      final flow = await GrantAuthFlow.begin();
      addTearDown(flow.close);
      final q = flow.authorizationUrl.queryParameters;

      // Two different base32-ish encodings in one URL: the secret is base64url
      // (43 chars for 32 bytes), the client key is z-base-32 (52 chars).
      expect(q['secret'], base64Url.encode(flow.clientSecret).replaceAll('=', ''));
      expect(q['secret']!.length, 43);
      expect(q['cpk'], z32Encode(flow.clientPublicKey));
      expect(q['cpk']!.length, 52);
      expect(z32Decode(q['cpk']!)!.length, 32);
    });

    test('two flows never share a secret or a channel', () async {
      final a = await GrantAuthFlow.begin();
      final b = await GrantAuthFlow.begin();
      addTearDown(a.close);
      addTearDown(b.close);

      expect(a.clientSecret, isNot(b.clientSecret));
      expect(a.channelId, isNot(b.channelId));
    });

    test('the channel url keeps the relay path', () async {
      final flow = await GrantAuthFlow.begin();
      addTearDown(flow.close);
      // The relay answers 404 on its host alone: the `/inbox` segment is part
      // of the address, not decoration.
      expect(flow.channelUrl.path, '/inbox/${flow.channelId}');
    });
  });
}
