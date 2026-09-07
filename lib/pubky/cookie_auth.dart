/// Cookie-based authentication.
///
/// The secret Ring hands back is **not** the cookie value. `export_secret()`
/// in the Pubky SDK returns `format!("{public_key}:{cookie}")` — the key, a
/// colon, then the actual session secret. Measured on a real session: 79
/// characters, being 52 + 1 + 26.
///
/// Sending the whole string as the cookie value fails with
/// `No authenticated session found`, which reads exactly like an expired
/// session and sends you looking in the wrong direction.
library;

/// The 16 random bytes the homeserver stores, rendered as base32 Crockford.
const cookieSecretLength = 26;

class CookieFormatError implements Exception {
  const CookieFormatError(this.message);
  final String message;

  @override
  String toString() => message;
}

class CookieCredential {
  const CookieCredential({required this.publicKey, required this.secret});

  /// The account the cookie belongs to — also the cookie's *name*.
  final String publicKey;

  /// The cookie's value.
  final String secret;

  /// `Cookie: <public key>=<secret>`, as the homeserver's own OpenAPI puts it:
  /// "the cookie name is the user's z-base-32 public key and the value is the
  /// session secret".
  String get header => '$publicKey=$secret';

  /// Reads what Ring exported. Tolerates the bare secret too, in case a
  /// caller already split it or a future Ring stops prefixing.
  ///
  /// [sessionPubky] is the key the session claims; when the token carries a
  /// prefix, the two must agree — a mismatch means we would authenticate as
  /// somebody else's account.
  factory CookieCredential.parse(String token, {required String sessionPubky}) {
    final colon = token.indexOf(':');

    if (colon < 0) {
      // No prefix: the token is the secret itself.
      return CookieCredential(publicKey: sessionPubky, secret: token);
    }

    final prefix = token.substring(0, colon);
    final secret = token.substring(colon + 1);

    if (secret.isEmpty) {
      throw const CookieFormatError('Le secret de session est vide.');
    }
    if (prefix != sessionPubky) {
      throw CookieFormatError(
        'Le secret désigne une autre clé que celle de la session '
        '(${_abbrev(prefix)} contre ${_abbrev(sessionPubky)}).',
      );
    }

    return CookieCredential(publicKey: prefix, secret: secret);
  }

  static String _abbrev(String key) =>
      key.length <= 12 ? key : '${key.substring(0, 6)}…${key.substring(key.length - 4)}';
}
