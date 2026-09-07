/// BLAKE3, in Dart, because the alternative was native code.
///
/// pubky-app addresses a blob by the Crockford base32 of the **first half** of
/// the BLAKE3 hash of its bytes. Without that, an image cannot be uploaded at
/// all — the id is not a name we get to choose.
///
/// The two Dart packages that offer BLAKE3 are both FFI bindings. After ML Kit
/// answered `MissingPluginException` on a signed release where the plugin was
/// demonstrably packaged, shipping another native dependency for one hash
/// function is a bet this project has already lost once. Two hundred lines of
/// pure Dart cannot fail to register.
///
/// It is proven against three independent sets of vectors — the official
/// BLAKE3 ones, the id in pubky-app-specs' own test, and a real blob published
/// by another client. See `test/blake3_test.dart`.
library;

import 'dart:typed_data';

const _outLen = 32;
const _keyLen = 32;
const _blockLen = 64;
const _chunkLen = 1024;

const _chunkStart = 1 << 0;
const _chunkEnd = 1 << 1;
const _parent = 1 << 2;
const _root = 1 << 3;

/// The SHA-256 initialisation vector, which BLAKE3 reuses.
const _iv = <int>[
  0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, //
  0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
];

const _permutation = <int>[2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8];

int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xFFFFFFFF;
int _add(int a, int b) => (a + b) & 0xFFFFFFFF;

void _g(Uint32List s, int a, int b, int c, int d, int mx, int my) {
  s[a] = _add(_add(s[a], s[b]), mx);
  s[d] = _rotr(s[d] ^ s[a], 16);
  s[c] = _add(s[c], s[d]);
  s[b] = _rotr(s[b] ^ s[c], 12);
  s[a] = _add(_add(s[a], s[b]), my);
  s[d] = _rotr(s[d] ^ s[a], 8);
  s[c] = _add(s[c], s[d]);
  s[b] = _rotr(s[b] ^ s[c], 7);
}

void _round(Uint32List s, Uint32List m) {
  _g(s, 0, 4, 8, 12, m[0], m[1]);
  _g(s, 1, 5, 9, 13, m[2], m[3]);
  _g(s, 2, 6, 10, 14, m[4], m[5]);
  _g(s, 3, 7, 11, 15, m[6], m[7]);
  _g(s, 0, 5, 10, 15, m[8], m[9]);
  _g(s, 1, 6, 11, 12, m[10], m[11]);
  _g(s, 2, 7, 8, 13, m[12], m[13]);
  _g(s, 3, 4, 9, 14, m[14], m[15]);
}

/// The compression function: seven rounds, then the feed-forward that folds
/// the second half of the state back into the first.
Uint32List _compress(
  List<int> chaining,
  Uint32List block,
  int counter,
  int blockLen,
  int flags,
) {
  final s = Uint32List(16)
    ..setRange(0, 8, chaining)
    ..setRange(8, 12, _iv)
    ..[12] = counter & 0xFFFFFFFF
    ..[13] = (counter ~/ 0x100000000) & 0xFFFFFFFF
    ..[14] = blockLen & 0xFFFFFFFF
    ..[15] = flags & 0xFFFFFFFF;

  var m = Uint32List.fromList(block);
  for (var round = 0; round < 7; round++) {
    _round(s, m);
    if (round == 6) break;
    final next = Uint32List(16);
    for (var i = 0; i < 16; i++) {
      next[i] = m[_permutation[i]];
    }
    m = next;
  }

  for (var i = 0; i < 8; i++) {
    s[i] ^= s[i + 8];
    s[i + 8] ^= chaining[i];
  }
  return s;
}

/// A 64-byte block read as sixteen little-endian words, zero-padded.
Uint32List _words(Uint8List bytes, int offset, int length) {
  final out = Uint32List(16);
  final data = ByteData(_blockLen);
  for (var i = 0; i < length; i++) {
    data.setUint8(i, bytes[offset + i]);
  }
  for (var i = 0; i < 16; i++) {
    out[i] = data.getUint32(i * 4, Endian.little);
  }
  return out;
}

/// What a subtree produces: enough to be chained, or to be finalised as root.
///
/// The distinction matters — the root is compressed a second time with an
/// extra flag, so a subtree cannot simply hand back its chaining value.
class _Output {
  _Output(this.chaining, this.block, this.counter, this.blockLen, this.flags);

  final List<int> chaining;
  final Uint32List block;
  final int counter;
  final int blockLen;
  final int flags;

  List<int> chainingValue() =>
      _compress(chaining, block, counter, blockLen, flags).sublist(0, 8);

  /// The root bytes. The counter restarts at zero here: it numbers output
  /// blocks, not chunks — a detail that only shows up past 64 bytes, which is
  /// exactly the kind of thing a 32-byte test would never catch.
  Uint8List rootBytes(int length) {
    final out = Uint8List(length);
    var written = 0;
    var counter = 0;
    while (written < length) {
      final words = _compress(chaining, block, counter, blockLen, flags | _root);
      final data = ByteData(64);
      for (var i = 0; i < 16; i++) {
        data.setUint32(i * 4, words[i], Endian.little);
      }
      final take = (length - written).clamp(0, 64);
      out.setRange(written, written + take, data.buffer.asUint8List(), 0);
      written += take;
      counter++;
    }
    return out;
  }
}

/// One chunk of at most 1024 bytes, folded block by block.
_Output _chunkOutput(Uint8List input, int start, int length, int counter) {
  var chaining = _iv.toList();
  var offset = 0;
  var blockFlags = _chunkStart;

  // An empty input still has one block, of length zero.
  final blocks = length == 0 ? 1 : (length + _blockLen - 1) ~/ _blockLen;

  for (var i = 0; i < blocks; i++) {
    final blockLen =
        (length - offset).clamp(0, _blockLen);
    final block = _words(input, start + offset, blockLen);
    final last = i == blocks - 1;
    if (last) {
      return _Output(
        chaining,
        block,
        counter,
        blockLen,
        blockFlags | _chunkEnd,
      );
    }
    chaining =
        _compress(chaining, block, counter, _blockLen, blockFlags).sublist(0, 8);
    blockFlags = 0;
    offset += _blockLen;
  }
  throw StateError('unreachable');
}

_Output _parentOutput(List<int> left, List<int> right) {
  final block = Uint32List(16)
    ..setRange(0, 8, left)
    ..setRange(8, 16, right);
  return _Output(_iv.toList(), block, 0, _blockLen, _parent);
}

/// How much of a subtree goes left: the largest power-of-two number of chunks
/// strictly below the total. Getting this wrong still produces a hash — just
/// not the same one anybody else computes.
int _leftLength(int length) {
  final chunks = (length + _chunkLen - 1) ~/ _chunkLen;
  var power = 1;
  while (power * 2 < chunks) {
    power *= 2;
  }
  return power * _chunkLen;
}

_Output _subtree(Uint8List input, int start, int length, int counter) {
  if (length <= _chunkLen) return _chunkOutput(input, start, length, counter);

  final leftLen = _leftLength(length);
  final left = _subtree(input, start, leftLen, counter).chainingValue();
  final right = _subtree(
    input,
    start + leftLen,
    length - leftLen,
    counter + leftLen ~/ _chunkLen,
  ).chainingValue();
  return _parentOutput(left, right);
}

/// The BLAKE3 hash of [input], [length] bytes long (32 by default).
Uint8List blake3(Uint8List input, {int length = _outLen}) =>
    _subtree(input, 0, input.length, 0).rootBytes(length);

/// Kept so the constants above are not dead weight to a reader wondering
/// whether keyed mode exists here. It does not: pubky-app never needs it.
const blake3KeyLength = _keyLen;
