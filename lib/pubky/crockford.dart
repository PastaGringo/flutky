/// Timestamp ids used by pubky-app resources (posts, files, …).
///
/// The format is unforgiving and fails *silently* when wrong: the homeserver
/// accepts any 13-character string, the file is readable, and the indexer
/// simply never picks it up. `validate_crockford_id` wants 13 characters that
/// decode to exactly 8 bytes — the creation time in microseconds, as a
/// big-endian u64, consumed five bits at a time **from the top**.
///
/// The tempting shortcut (repeated division by 32) also yields 13 valid
/// characters, but they decode to a different instant. Nothing errors; the
/// post just never appears.
library;

const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Crockford: no I, L, O, U

/// Encodes a microsecond timestamp as a 13-character Crockford id.
String crockfordId(int microseconds) {
  final bytes = List<int>.filled(8, 0);
  var v = BigInt.from(microseconds);
  for (var i = 7; i >= 0; i--) {
    bytes[i] = (v & BigInt.from(0xff)).toInt();
    v >>= 8;
  }

  var bits = 0;
  var buffer = 0;
  final out = StringBuffer();
  for (final byte in bytes) {
    buffer = (buffer << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out.write(_alphabet[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);

  return out.toString(); // 13 characters
}

/// Id for a resource created now.
String newCrockfordId() =>
    crockfordId(DateTime.now().toUtc().microsecondsSinceEpoch);

/// Reverses the encoding. Exists for one reason: it lets a test decode a *real*
/// pubky.app id and check that it lands on a plausible date. A round trip
/// through our own encoder would pass just as happily with a wrong formula.
DateTime? decodeCrockfordId(String id) {
  if (id.length != 13) return null;

  var bits = 0;
  var buffer = 0;
  final bytes = <int>[];
  for (final char in id.toUpperCase().split('')) {
    final value = _alphabet.indexOf(char);
    if (value < 0) return null;
    buffer = (buffer << 5) | value;
    bits += 5;
    if (bits >= 8) {
      bytes.add((buffer >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  if (bytes.length != 8) return null;

  var micros = BigInt.zero;
  for (final byte in bytes) {
    micros = (micros << 8) | BigInt.from(byte);
  }
  return DateTime.fromMicrosecondsSinceEpoch(micros.toInt(), isUtc: true);
}
