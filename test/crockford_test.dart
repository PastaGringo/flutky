import 'dart:convert';
import 'dart:io';

import 'package:flutky/pubky/crockford.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Crockford ids', () {
    test('produces 13 characters from the Crockford alphabet', () {
      final id = newCrockfordId();
      expect(id, hasLength(13));
      expect(id, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{13}$')));
      expect(id, isNot(contains(RegExp('[ILOU]'))));
    });

    test('round-trips a known timestamp', () {
      final when = DateTime.utc(2026, 9, 7, 20, 4, 33);
      final decoded = decodeCrockfordId(crockfordId(when.microsecondsSinceEpoch));
      expect(decoded, when);
    });

    // The witness that actually matters. Our own round trip would stay green
    // with a wrong formula; ids minted by pubky.app would not. The arithmetic
    // shortcut this guards against decodes real ids to 2081.
    test('decodes REAL pubky.app ids to a plausible date', () {
      final raw = File('test/fixtures/nexus_stream.json').readAsStringSync();
      final posts = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      expect(posts, isNotEmpty);

      for (final post in posts) {
        final details = post['details'] as Map<String, dynamic>;
        final id = details['id'] as String;
        final indexedAt = (details['indexed_at'] as num).toInt();

        final decoded = decodeCrockfordId(id);
        expect(decoded, isNotNull, reason: 'id $id should decode');

        // The id carries creation time, indexed_at is when Nexus saw it: the
        // two must land in the same neighbourhood, not decades apart.
        final gap = decoded!
            .difference(DateTime.fromMillisecondsSinceEpoch(indexedAt, isUtc: true))
            .abs();
        expect(gap.inDays, lessThan(2),
            reason: 'id $id decodes to $decoded, far from its indexing date');
      }
    });

    test('ids minted now sort after ids minted a second ago', () {
      final before = crockfordId(
        DateTime.now().toUtc().microsecondsSinceEpoch - 1000000,
      );
      final now = newCrockfordId();
      expect(now.compareTo(before), greaterThan(0),
          reason: 'lexical order must follow chronological order');
    });

    test('rejects malformed ids instead of inventing a date', () {
      expect(decodeCrockfordId('trop-court'), isNull);
      expect(decodeCrockfordId('IIIIIIIIIIIII'), isNull, reason: 'I is not in the alphabet');
      expect(decodeCrockfordId(''), isNull);
    });
  });
}
