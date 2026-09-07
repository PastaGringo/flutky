import 'package:url_launcher/url_launcher.dart';

/// Session handed back by Pubky Ring through its x-callback-url flow.
///
/// The flow, as implemented in Ring's `src/utils/actions/sessionAction.ts`:
///
///   1. we open   pubkyring://session?x-success=flutky://session&x-error=…
///   2. Ring asks the user to pick a pubky, then to approve the request
///   3. Ring re-opens us at
///      flutky://session?pubky=…&grant_secret=…&capabilities=…
class RingSession {
  const RingSession({
    required this.pubky,
    required this.grantSecret,
    required this.capabilities,
  });

  /// The user's public key, bare z-base32 (52 chars, no `pubky:` prefix).
  final String pubky;

  /// Bearer-equivalent credential. Anyone holding it can act as the user.
  /// Kept in memory only for this proof of concept — a real app puts it in
  /// the Android keystore and never logs or displays it.
  final String grantSecret;

  final List<String> capabilities;
}

/// Everything Ring can hand back on the callback: either a session, a refusal,
/// or an error it ran into on its side.
sealed class RingCallback {
  const RingCallback();

  /// Parses a URI re-opened by Ring. Returns null when the URI is not ours.
  ///
  /// Deliberately tolerant about *where* the payload sits: what identifies a
  /// session is the presence of `pubky` + a secret, not the host Ring chose.
  /// Ring routes an incoming link through several handlers, and only one of
  /// them appends the payload — so keying off the host alone misreads the
  /// others as malformed.
  static RingCallback? tryParse(Uri uri) {
    if (uri.scheme != callbackScheme) return null;

    final q = uri.queryParameters;
    final pubky = _firstOf(q, const ['pubky', 'pubkey', 'public_key', 'publicKey']);
    final secret = _firstOf(
      q,
      const ['grant_secret', 'grantSecret', 'session_secret', 'sessionSecret', 'secret'],
    );

    // A payload wins over the host: some Ring paths reply on a generic URL.
    if (pubky != null && secret != null) {
      final caps = _firstOf(q, const ['capabilities', 'caps']) ?? '';
      return RingApproved(
        RingSession(
          pubky: pubky,
          grantSecret: secret,
          capabilities: caps.isEmpty
              ? const []
              : caps.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList(),
        ),
      );
    }

    switch (uri.host) {
      case 'cancel':
        return const RingCancelled();

      case 'error':
        return RingFailed(
          code: q['errorCode'] ?? 'UNKNOWN',
          message: q['errorMessage'] ?? 'Erreur inconnue côté Ring.',
        );

      case 'session':
        // Ring came back on the success URL but appended nothing. This is the
        // signature of a handler that calls openXSuccess() rather than
        // openXSuccessWithParams() — i.e. the link was routed somewhere other
        // than the session flow.
        return RingEmpty(uri);

      default:
        return null;
    }
  }

  static String? _firstOf(Map<String, String> q, List<String> keys) {
    for (final k in keys) {
      final v = q[k];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }
}

class RingApproved extends RingCallback {
  const RingApproved(this.session);
  final RingSession session;
}

class RingCancelled extends RingCallback {
  const RingCancelled();
}

class RingFailed extends RingCallback {
  const RingFailed({required this.code, required this.message});
  final String code;
  final String message;
}

/// Ring returned on the success URL, carrying nothing usable.
class RingEmpty extends RingCallback {
  const RingEmpty(this.uri);
  final Uri uri;
}

/// Our own URL scheme, declared in AndroidManifest.xml.
const callbackScheme = 'flutky';

/// The two spellings Ring's parser normalises to the same route. Trying both
/// tells us whether the trailing slash is what decides the routing.
enum SessionUrlVariant {
  plain('pubkyring://session', 'sans barre oblique'),
  trailingSlash('pubkyring://session/', 'avec barre oblique');

  const SessionUrlVariant(this.base, this.label);
  final String base;
  final String label;
}

/// Raised when the intent could not be handed to any app — in practice, Ring
/// is not installed.
class RingNotReachable implements Exception {
  const RingNotReachable();
}

/// Builds the link handed to Ring. Exposed so the UI can show exactly what was
/// sent — half of any deep-link diagnosis is knowing the outgoing URL.
Uri buildSessionUrl(SessionUrlVariant variant) {
  String cb(String host) => Uri.encodeComponent('$callbackScheme://$host');

  return Uri.parse(
    '${variant.base}'
    '?x-success=${cb('session')}'
    '&x-error=${cb('error')}'
    '&x-cancel=${cb('cancel')}'
    '&x-source=${Uri.encodeComponent('Flutky')}',
  );
}

/// Asks Pubky Ring for a homeserver session.
///
/// Throws [RingNotReachable] when no app answers the `pubkyring` scheme.
Future<void> requestSession(SessionUrlVariant variant) async {
  // Deliberately not gated behind canLaunchUrl: on Android 11+ it answers
  // false for custom schemes unless <queries> is declared, and even then it
  // makes a poor witness. launchUrl fails outright when nothing handles the
  // intent, which is the signal we actually want.
  final launched = await launchUrl(
    buildSessionUrl(variant),
    mode: LaunchMode.externalApplication,
  );
  if (!launched) throw const RingNotReachable();
}
