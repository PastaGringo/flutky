import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ring_session.dart';

/// Keeps the Ring session across launches.
///
/// The secret is bearer-equivalent, so it goes to the platform keystore —
/// EncryptedSharedPreferences on Android, the Keychain on iOS — never to
/// SharedPreferences and never to a log line.
class SessionStore {
  /// Android needs no option here: since flutter_secure_storage 11 the default
  /// already is AES-GCM data encryption with an RSA-OAEP wrapped key held by
  /// the Android Keystore — the old `encryptedSharedPreferences` flag is gone.
  /// iOS is pinned to `first_unlock` so a restart does not force a new pass
  /// through Ring before the user unlocks once.
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _key = 'ring_session_v1';

  Future<void> save(RingSession session) => _storage.write(
        key: _key,
        value: jsonEncode({
          'pubky': session.pubky,
          'secret': session.grantSecret,
          'capabilities': session.capabilities,
        }),
      );

  /// Returns the stored session, or null when there is none — including when
  /// the keystore refuses to decrypt, which happens after a restore onto
  /// another device. A failure to read is not an error worth surfacing: it
  /// simply means the user has to go through Ring again.
  Future<RingSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final pubky = json['pubky'] as String?;
      final secret = json['secret'] as String?;
      if (pubky == null || pubky.isEmpty || secret == null || secret.isEmpty) {
        await clear();
        return null;
      }

      return RingSession(
        pubky: pubky,
        grantSecret: secret,
        capabilities:
            (json['capabilities'] as List<dynamic>? ?? const []).cast<String>(),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Nothing useful to do: the goal is that no session survives.
    }
  }
}
