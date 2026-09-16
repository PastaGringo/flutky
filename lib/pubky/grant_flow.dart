/// The grant authorization handshake, in Dart.
///
/// Flutky signs in today with a **cookie** session, which pubky-core v0.10
/// marks "deprecated and scheduled for removal". Its own migration guide gives
/// the reason plainly: the cookie belongs to the homeserver's domain rather
/// than to the application, so "website B can receive the same homeserver
/// cookie used by website A". A grant is bound to a per-application key,
/// expires in an hour, and can be revoked on its own — none of which a cookie
/// offers.
///
/// The flow, as read from pubky-core rather than guessed:
///
/// 1. The app invents a 32-byte **client secret** and an Ed25519 **client
///    keypair**.
/// 2. It opens `pubkyauth://signin_grant?caps=…&relay=…&secret=…&cid=…&cpk=…`.
/// 3. Ring asks the person, then posts the grant — encrypted with that secret —
///    to a channel on the relay.
/// 4. The app polls that channel, decrypts, and holds a grant JWS.
/// 5. [GrantAuth] signs a proof of possession with the client key and trades
///    the grant for a bearer token.
///
/// Two details that are silent failures if guessed wrong, and are therefore
/// taken from the source:
///
/// - the channel is `base64url(blake3(secret))`, **not** the secret itself;
/// - the payload is XSalsa20-Poly1305 with a 24-byte nonce in front — NaCl
///   secretbox. `package:cryptography` offers XChaCha20, which is a different
///   algorithm under a similar name.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
// Aliased: `package:cryptography` exports a `SecretBox` of its own, and the
// two are unrelated. Left unqualified, the wrong one resolves and the error
// talks about a missing `mac` parameter — which says nothing about the real
// cause.
import 'package:pinenacl/api.dart' show ByteList;
import 'package:pinenacl/x25519.dart' as nacl;

import 'blake3.dart';
import 'z32.dart';

/// The relay pubky.app itself uses, read from its served page rather than from
/// a guess. Note the `/inbox` path: the host alone answers 404.
const defaultAuthRelay = 'https://httprelay.pubky.app/inbox';

/// What the app calls itself in the authorization screen. Ring shows it to the
/// person approving, and the homeserver binds the grant to it.
const flutkyClientId = 'flutky.pastalabs.dev';

/// Read and write under pubky-app's own prefix — the same capability a cookie
/// session from Ring carries today, so nothing the app already does is lost.
const flutkyCapabilities = '/pub/pubky.app/:rw';

/// The nonce XSalsa20-Poly1305 prefixes to its ciphertext.
const _nonceLength = 24;

/// Something went wrong before any grant could be obtained.
class GrantFlowError implements Exception {
  const GrantFlowError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One authorization attempt: the keys it invented, and the link to open.
class GrantAuthFlow {
  GrantAuthFlow._({
    required this.clientSecret,
    required this.clientKeyPair,
    required this.clientPublicKey,
    required this.relay,
    required this.clientId,
    required this.capabilities,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Thirty-two bytes that do two jobs: they name the relay channel (through
  /// their hash) and they are the key the payload is encrypted with. They
  /// never leave the device except inside the authorization link.
  final Uint8List clientSecret;

  /// The key the grant is bound to. Proving possession of it is what lets the
  /// bearer be refreshed without the person's root key.
  final SimpleKeyPair clientKeyPair;
  final Uint8List clientPublicKey;

  final Uri relay;
  final String clientId;
  final String capabilities;

  final http.Client _http;

  static final _random = Random.secure();

  /// Starts a flow, inventing the secret and the client key.
  static Future<GrantAuthFlow> begin({
    String relay = defaultAuthRelay,
    String clientId = flutkyClientId,
    String capabilities = flutkyCapabilities,
    http.Client? httpClient,
  }) async {
    final secret = Uint8List.fromList(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    final algorithm = Ed25519();
    final pair = await algorithm.newKeyPair();
    final publicKey = await pair.extractPublicKey();

    return GrantAuthFlow._(
      clientSecret: secret,
      clientKeyPair: pair,
      clientPublicKey: Uint8List.fromList(publicKey.bytes),
      relay: Uri.parse(relay),
      clientId: clientId,
      capabilities: capabilities,
      httpClient: httpClient,
    );
  }

  /// `base64url(blake3(secret))`, without padding.
  ///
  /// The hash is what keeps the secret off the relay: anyone watching the
  /// channel sees an opaque name, not the key that decrypts what lands there.
  String get channelId =>
      base64Url.encode(blake3(clientSecret)).replaceAll('=', '');

  /// The channel's URL on the relay.
  Uri get channelUrl {
    final segments = [
      ...relay.pathSegments.where((s) => s.isNotEmpty),
      channelId,
    ];
    return relay.replace(pathSegments: segments);
  }

  /// The link to hand to Pubky Ring.
  ///
  /// Parameter names are not negotiable — `caps`, `relay`, `secret`, `cid`,
  /// `cpk` — and the secret travels as base64url without padding while the
  /// client key travels as z-base-32. Two different base32-ish encodings in one
  /// URL is a trap worth naming.
  Uri get authorizationUrl => Uri(
        scheme: 'pubkyauth',
        host: 'signin_grant',
        queryParameters: {
          'caps': capabilities,
          'relay': relay.toString(),
          'secret': base64Url.encode(clientSecret).replaceAll('=', ''),
          'cid': clientId,
          'cpk': z32Encode(clientPublicKey),
        },
      );

  /// Polls the relay until Ring drops the grant, and returns it as a JWS.
  ///
  /// The relay holds a message until it is read, so a poll that answers
  /// nothing simply means the person has not approved yet. [timeout] bounds
  /// the wait so a link that was never opened does not hang forever.
  Future<String> awaitGrant({
    Duration timeout = const Duration(minutes: 3),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final payload = await _poll();
      if (payload != null) return decryptGrant(payload, clientSecret);
      await Future<void>.delayed(interval);
    }
    throw const GrantFlowError('Aucune approbation reçue.');
  }

  /// One look at the channel. Null when there is nothing yet.
  Future<Uint8List?> _poll() async {
    try {
      final res = await _http
          .get(channelUrl)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      return res.bodyBytes;
    } catch (_) {
      // A relay that times out is a relay with nothing to say; the loop above
      // decides when to stop, not a single failed look.
      return null;
    }
  }

  void close() => _http.close();
}

/// Decrypts what Ring posted: 24 bytes of nonce, then the sealed grant.
///
/// Kept a free function so a test can exercise it without a network, against a
/// message it sealed itself.
String decryptGrant(Uint8List payload, Uint8List secret) {
  if (payload.length <= _nonceLength) {
    throw GrantFlowError(
      'Message du relais trop court : ${payload.length} octets pour un nonce '
      'de $_nonceLength.',
    );
  }
  try {
    final box = nacl.SecretBox(secret);
    final plain = box.decrypt(
      ByteList(payload.sublist(_nonceLength)),
      nonce: payload.sublist(0, _nonceLength),
    );
    return utf8.decode(plain);
  } on GrantFlowError {
    rethrow;
  } catch (e) {
    throw GrantFlowError('Déchiffrement du grant impossible : $e');
  }
}

/// Seals a grant the way Ring does. Exists for the tests — nothing in the app
/// encrypts, it only ever reads.
Uint8List sealGrant(String jws, Uint8List secret, {Uint8List? nonce}) {
  final box = nacl.SecretBox(secret);
  final sealed = box.encrypt(
    Uint8List.fromList(utf8.encode(jws)),
    nonce: nonce,
  );
  return Uint8List.fromList([
    ...sealed.nonce,
    ...sealed.cipherText,
  ]);
}
