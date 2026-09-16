/// z-base-32, the alphabet Pubky writes keys in.
///
/// Not to be confused with the Crockford base32 used for resource ids — the
/// two look alike and share nothing. Crockford drops `I`, `L`, `O` and `U` and
/// is written upper case; z-base-32 reorders the whole alphabet to put the
/// easiest characters first and is written lower case. Encoding a key with the
/// wrong one produces a plausible string that names nobody.
///
/// Needed because a grant authorization link carries the client public key as
/// `cpk=<z32>`, and Pubky Ring compares it to what it signs.
library;

import 'dart:typed_data';

const _alphabet = 'ybndrfg8ejkmcpqxot1uwisza345h769';

/// Encodes bytes, five bits at a time from the top — the same bit order as the
/// Crockford encoder, only the alphabet differs.
String z32Encode(List<int> bytes) {
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
  return out.toString();
}

/// Decodes, or null when the text is not z-base-32.
///
/// Exists so a test can take a **real** key off the network, decode it and
/// encode it back: a round trip through our own encoder alone would stay green
/// with a shuffled alphabet.
Uint8List? z32Decode(String text) {
  var bits = 0;
  var buffer = 0;
  final out = <int>[];
  for (final char in text.split('')) {
    final value = _alphabet.indexOf(char);
    if (value < 0) return null;
    buffer = (buffer << 5) | value;
    bits += 5;
    if (bits >= 8) {
      out.add((buffer >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Uint8List.fromList(out);
}
