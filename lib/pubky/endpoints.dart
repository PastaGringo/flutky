/// Where Pubky answers, and under which key.
///
/// Kept apart from [homeserver.dart] on purpose: that file reaches the Android
/// keystore through a plugin, so importing it drags Flutter in. A command-line
/// probe that only needs an address would then fail to compile — measured, and
/// the failure is a crash inside the Dart FFI transformer that names neither
/// the plugin nor the import.
///
/// Addresses are data. They belong somewhere a plain Dart script can read.
library;

/// The homeserver this proof of concept writes to.
const homeserverBase = 'https://homeserver.pubky.app';

/// That homeserver's own public key.
///
/// Needed as the `aud` of a proof of possession: binding the proof to one
/// homeserver is what stops it being replayed against another. Read from the
/// runtime configuration pubky.app serves to its own browser
/// (`"homeserver":"…"`) rather than guessed — a wrong audience is refused with
/// a 401 that reads exactly like a bad key.
const homeserverPublicKey =
    '8um71us3fyw6h8wbcxb5ar3rwusy1a6u49956ikzojg3gcwd1dty';

/// The relay Pubky Ring drops an approved grant on.
///
/// Read from the same configuration. Note the `/inbox` path: the host alone
/// answers 404.
const defaultAuthRelay = 'https://httprelay.pubky.app/inbox';
