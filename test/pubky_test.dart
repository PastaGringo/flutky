import 'dart:convert';
import 'dart:io';

import 'package:flutky/pubky/nexus.dart';
import 'package:flutky/pubky/ring_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ring callback', () {
    test('parses an approved session', () {
      final result = RingCallback.tryParse(Uri.parse(
        'flutky://session'
        '?pubky=gujx6qd8ksydh1makdphd3bxu351d9b8waqka8hfg6q7hnqkxexo'
        '&grant_secret=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        '&capabilities=%2Fpub%2Fpubky.app%2F%3Arw%2C%2Fpub%2Ffoo%3Ar',
      ));

      expect(result, isA<RingApproved>());
      final session = (result as RingApproved).session;
      expect(session.pubky,
          'gujx6qd8ksydh1makdphd3bxu351d9b8waqka8hfg6q7hnqkxexo');
      expect(session.grantSecret.length, 43);
      expect(session.capabilities, ['/pub/pubky.app/:rw', '/pub/foo:r']);
    });

    test('reports a cancellation', () {
      expect(RingCallback.tryParse(Uri.parse('flutky://cancel')),
          isA<RingCancelled>());
    });

    test('carries Ring errorCode and errorMessage', () {
      final result = RingCallback.tryParse(Uri.parse(
        'flutky://error?errorCode=SESSION_FAILED&errorMessage=Sign-in%20failed',
      ));
      expect(result, isA<RingFailed>());
      expect((result as RingFailed).code, 'SESSION_FAILED');
      expect(result.message, 'Sign-in failed');
    });

    test('flags a success callback that carries no payload', () {
      final result = RingCallback.tryParse(Uri.parse('flutky://session'));
      expect(result, isA<RingEmpty>());

      final partial = RingCallback.tryParse(Uri.parse('flutky://session?pubky=abc'));
      expect(partial, isA<RingEmpty>(),
          reason: 'a pubky without a secret is not a usable session');
    });

    test('accepts a payload whatever host Ring replied on', () {
      // Ring has several handlers; not all reply on the success host we gave.
      for (final host in ['session', 'error', 'cancel', 'whatever']) {
        final result = RingCallback.tryParse(Uri.parse(
          'flutky://$host?pubky=abc&grant_secret=def',
        ));
        expect(result, isA<RingApproved>(), reason: 'host $host');
      }
    });

    test('accepts session_secret as an alias of grant_secret', () {
      final result = RingCallback.tryParse(
        Uri.parse('flutky://session?pubky=abc&session_secret=def'),
      );
      expect(result, isA<RingApproved>());
      expect((result as RingApproved).session.grantSecret, 'def');
    });

    test('ignores links that are not ours', () {
      expect(RingCallback.tryParse(Uri.parse('https://pubky.app/')), isNull);
      expect(RingCallback.tryParse(Uri.parse('flutky://whatever')), isNull);
    });
  });

  group('Outgoing link', () {
    test('carries the three callbacks and the source, both variants', () {
      for (final variant in SessionUrlVariant.values) {
        final url = buildSessionUrl(variant).toString();
        expect(url, startsWith(variant.base));
        expect(url, contains('x-success=flutky%3A%2F%2Fsession'));
        expect(url, contains('x-error=flutky%3A%2F%2Ferror'));
        expect(url, contains('x-cancel=flutky%3A%2F%2Fcancel'));
        expect(url, contains('x-source=Flutky'));
      }
    });

    test('the two variants differ only by the trailing slash', () {
      expect(SessionUrlVariant.plain.base, 'pubkyring://session');
      expect(SessionUrlVariant.trailingSlash.base, 'pubkyring://session/');
    });
  });

  group('Nexus profile', () {
    // Not a hand-written fixture: this is the untouched body of
    // GET /v0/user/gujx6q… captured from nexus.pubky.app.
    late PubkyProfile profile;

    setUpAll(() {
      final raw = File('test/fixtures/nexus_user.json').readAsStringSync();
      profile = PubkyProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    });

    test('reads identity fields', () {
      expect(profile.id, 'gujx6qd8ksydh1makdphd3bxu351d9b8waqka8hfg6q7hnqkxexo');
      expect(profile.name, 'John Carvalho');
      expect(profile.bio, contains('Synonym'));
      expect(profile.status, isNotNull);
    });

    test('reads links, counts and tags', () {
      expect(profile.links, isNotEmpty);
      expect(profile.links.first.url, startsWith('http'));
      expect(profile.counts['posts'], greaterThan(0));
      expect(profile.counts.containsKey('followers'), isTrue);
      expect(profile.tags, isNotEmpty);
      expect(profile.tags.first.taggersCount, greaterThan(0));
    });

    test('builds the avatar URL Nexus actually serves', () {
      expect(profile.avatarUrl, '$nexusBase/static/avatar/${profile.id}');
    });

    test('turns indexed_at milliseconds into a plausible date', () {
      expect(profile.indexedAt, isNotNull);
      expect(profile.indexedAt!.year, inInclusiveRange(2024, 2030));
    });

    test('survives a response with every optional field missing', () {
      final bare = PubkyProfile.fromJson({
        'details': {'id': 'abc'},
      });
      // The model no longer invents a placeholder name: wording belongs to the
      // interface, which translates it.
      expect(bare.name, isEmpty);
      expect(bare.bio, isNull);
      expect(bare.links, isEmpty);
      expect(bare.counts, isEmpty);
      expect(bare.indexedAt, isNull);
    });
  });
}
