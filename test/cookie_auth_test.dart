import 'package:flutky/pubky/cookie_auth.dart';
import 'package:flutter_test/flutter_test.dart';

const _pubky = 'w3ase343kdnbtp4y3x69qd1qyt8peyrdtkhf671ujucc9i8fge6y';
const _secret = 'ABCDEFGHJKMNPQRSTVWXYZ0123'; // 26 chars, base32 Crockford

void main() {
  group('Cookie credential', () {
    test('splits the token the SDK exports', () {
      // export_secret() returns `format!("{public_key}:{cookie}")`.
      // Measured on a real session: 52 + 1 + 26 = 79 characters.
      const token = '$_pubky:$_secret';
      expect(token, hasLength(79));

      final credential = CookieCredential.parse(token, sessionPubky: _pubky);

      expect(credential.publicKey, _pubky);
      expect(credential.secret, _secret);
      expect(credential.secret, hasLength(cookieSecretLength));
    });

    test('builds the header the homeserver documents', () {
      final credential =
          CookieCredential.parse('$_pubky:$_secret', sessionPubky: _pubky);

      // "the cookie name is the user's z-base-32 public key and the value is
      // the session secret"
      expect(credential.header, '$_pubky=$_secret');
      expect(credential.header, isNot(contains(':')));
    });

    test('the whole token as a value is exactly the bug this fixes', () {
      final credential =
          CookieCredential.parse('$_pubky:$_secret', sessionPubky: _pubky);

      expect(credential.header, isNot('$_pubky=$_pubky:$_secret'),
          reason: 'sending the prefix inside the value is what returned 401');
    });

    test('accepts a bare secret, in case the prefix ever goes away', () {
      final credential = CookieCredential.parse(_secret, sessionPubky: _pubky);

      expect(credential.publicKey, _pubky);
      expect(credential.secret, _secret);
    });

    test('refuses a token that names a different account', () {
      const other = 'gujx6qd8ksydh1makdphd3bxu351d9b8waqka8hfg6q7hnqkxexo';

      expect(
        () => CookieCredential.parse('$other:$_secret', sessionPubky: _pubky),
        throwsA(isA<CookieFormatError>()),
        reason: 'authenticating as somebody else must fail loudly',
      );
    });

    test('refuses a token with an empty secret', () {
      expect(
        () => CookieCredential.parse('$_pubky:', sessionPubky: _pubky),
        throwsA(isA<CookieFormatError>()),
      );
    });
  });
}
