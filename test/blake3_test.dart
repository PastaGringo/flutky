import 'dart:convert';
import 'dart:typed_data';

import 'package:flutky/pubky/blake3.dart';
import 'package:flutky/pubky/crockford.dart';
import 'package:flutter_test/flutter_test.dart';

String hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// The input the official BLAKE3 test vectors use: bytes 0,1,2,…,250,0,1,…
Uint8List pattern(int length) =>
    Uint8List.fromList([for (var i = 0; i < length; i++) i % 251]);

void main() {
  // Three independent sources, because a hash that agrees only with itself is
  // a hash nobody else can read. A round trip through our own encoder would
  // stay green with a completely wrong permutation table.
  group('official BLAKE3 vectors', () {
    // Fetched from BLAKE3-team/BLAKE3 test_vectors.json, not recalled.
    //
    // Worth saying why: the first version of this list was written from
    // memory, and three of its entries were wrong. Eleven vectors passed, so
    // the implementation was right — but the three mismatches sent me looking
    // for a bug in correct code. Constants get verified like everything else.
    const vectors = <int, String>{
      0: 'af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262',
      1: '2d3adedff11b61f14c886e35afa036736dcd87a74d27b5c1510225d0f592e213',
      2: '7b7015bb92cf0b318037702a6cdd81dee41224f734684c2c122cd6359cb1ee63',
      3: 'e1be4d7a8ab5560aa4199eea339849ba8e293d55ca0a81006726d184519e647f',
      63: 'e9bc37a594daad83be9470df7f7b3798297c3d834ce80ba85d6e207627b7db7b',
      64: '4eed7141ea4a5cd4b788606bd23f46e212af9cacebacdc7d1f4c6dc7f2511b98',
      65: 'de1e5fa0be70df6d2be8fffd0e99ceaa8eb6e8c93a63f2d8d1c30ecb6b263dee',
      1023: '10108970eeda3eb932baac1428c7a2163b0e924c9a9e25b35bba72b28f70bd11',
      1024: '42214739f095a406f3fc83deb889744ac00df831c10daa55189b5d121c855af7',
      1025: 'd00278ae47eb27b34faecf67b4fe263f82d5412916c1ffd97c8cb7fb814b8444',
      2048: 'e776b6028c7cd22a4d0ba182a8bf62205d2ef576467e838ed6f2529b85fba24a',
      2049: '5f4d72f40d7a5f82b15ca2b2e44b1de3c2ef86c426c95c1af0b6879522563030',
      3072: 'b98cb0ff3623be03326b373de6b9095218513e64f1ee2edd2525c7ad1e5cffd2',
      4096: '015094013f57a5277b59d8475c0501042c0b642e531b0a1c8f58d2163229e969',
    };

    for (final entry in vectors.entries) {
      test('${entry.key} bytes', () {
        expect(hex(blake3(pattern(entry.key))), entry.value);
      });
    }

    test('a longer digest keeps its first 32 bytes', () {
      // The extended output restarts a counter that numbers output blocks
      // rather than chunks — a detail invisible at 32 bytes, which is why it
      // gets its own check.
      final long = blake3(pattern(1024), length: 64);
      expect(hex(long).substring(0, 64), vectors[1024]);
      expect(long.length, 64);
    });

    test('the vectors discriminate: one flipped bit changes everything', () {
      final a = pattern(2048);
      final b = Uint8List.fromList(a)..[1000] ^= 1;
      expect(hex(blake3(a)), isNot(hex(blake3(b))));
    });
  });

  group('the blob id pubky-app actually uses', () {
    /// Crockford of the first half of the hash, as `PubkyAppBlob::create_id`
    /// computes it.
    String blobId(List<int> bytes) {
      final hash = blake3(Uint8List.fromList(bytes));
      return crockfordBytes(hash.sublist(0, hash.length ~/ 2));
    }

    test("matches pubky-app-specs' own test vector", () {
      // From src/models/blob.rs: PubkyAppBlob(vec![1, 2]).create_id().
      expect(blobId([1, 2]), 'PZBQ010FF079VVZPQG1RNFN6DR');
    });

    test('is 26 characters, unlike the 13 of a timestamp id', () {
      final id = blobId(utf8.encode('n\'importe quoi'));
      expect(id.length, 26);
      expect(RegExp(r'^[0-9A-HJKMNP-TV-Z]+$').hasMatch(id), isTrue);
    });

    test('the same bytes always give the same id, different bytes do not', () {
      expect(blobId([1, 2]), blobId([1, 2]));
      expect(blobId([1, 2]), isNot(blobId([1, 2, 3])));
    });
  });
}
