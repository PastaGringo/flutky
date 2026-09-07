import 'dart:convert';
import 'dart:io';

import 'package:flutky/pubky/nexus.dart';
import 'package:flutky/pubky/ring_session.dart';
import 'package:flutky/pubky/session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the platform keystore. The real one needs a device; what we
/// can prove here is that the store round-trips, rejects half-written values,
/// and never leaves anything behind after clear().
class _FakeStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};
  bool throwOnRead = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnRead) throw KeystoreDecryptFailure(); // e.g. restored onto a new device
    return values[key];
  }

  @override
  Future<void> delete({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed for these tests');
}

class KeystoreDecryptFailure implements Exception {}

void main() {
  group('Session store', () {
    late _FakeStorage storage;
    late SessionStore store;

    const session = RingSession(
      pubky: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      grantSecret: 'un-secret-qui-vaut-mot-de-passe',
      capabilities: ['/pub/pubky.app/:rw'],
    );

    setUp(() {
      storage = _FakeStorage();
      store = SessionStore(storage: storage);
    });

    test('round-trips a session', () async {
      await store.save(session);
      final back = await store.read();

      expect(back, isNotNull);
      expect(back!.pubky, session.pubky);
      expect(back.grantSecret, session.grantSecret);
      expect(back.capabilities, session.capabilities);
    });

    test('returns null when nothing was stored', () async {
      expect(await store.read(), isNull);
    });

    test('discards a record missing its secret rather than half-restoring', () async {
      storage.values['ring_session_v1'] = jsonEncode({'pubky': 'abc'});

      expect(await store.read(), isNull);
      expect(storage.values, isEmpty, reason: 'the unusable record is cleared');
    });

    test('a keystore that refuses to decrypt yields null, not a crash', () async {
      await store.save(session);
      storage.throwOnRead = true;

      expect(await store.read(), isNull);
    });

    test('clear leaves nothing behind', () async {
      await store.save(session);
      await store.clear();

      expect(storage.values, isEmpty);
      expect(await store.read(), isNull);
    });
  });

  group('Feed posts', () {
    // Untouched body of GET /v0/stream/posts?kind=image&… captured from
    // nexus.pubky.app, so the parsing is proven against what is really served.
    late List<PubkyPost> posts;

    setUpAll(() {
      final raw = File('test/fixtures/nexus_stream.json').readAsStringSync();
      posts = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(PubkyPost.fromJson)
          .toList();
    });

    test('parses a whole page', () {
      expect(posts, hasLength(10));
      for (final post in posts) {
        expect(post.id, isNotEmpty);
        expect(post.author, hasLength(52));
        expect(post.kind, 'image');
      }
    });

    test('turns pubky:// attachments into URLs Nexus serves', () {
      final withImages = posts.where((p) => p.attachments.isNotEmpty).toList();
      expect(withImages, isNotEmpty);

      for (final post in withImages) {
        final urls = post.imageUrls();
        expect(urls, hasLength(post.attachments.length));
        for (final url in urls) {
          expect(url, startsWith('$nexusBase/static/files/'));
          expect(url, endsWith('/feed'));
        }
      }
    });

    test('asks for the feed-sized variant by default, main on request', () {
      final post = posts.firstWhere((p) => p.attachments.isNotEmpty);
      expect(post.imageUrls().first, endsWith('/feed'));
      expect(post.imageUrls(variant: 'main').first, endsWith('/main'));
    });

    test('ignores an attachment URI that is not a pubky file', () {
      final post = PubkyPost.fromJson({
        'details': {
          'id': 'x',
          'author': 'y',
          'attachments': ['https://example.com/a.png', 'pubky://k/pub/other/z'],
        },
      });
      expect(post.imageUrls(), isEmpty);
    });

    test('survives a post stripped of every optional field', () {
      final bare = PubkyPost.fromJson({'details': {'id': 'x'}});
      expect(bare.content, isEmpty);
      expect(bare.kind, 'unknown');
      expect(bare.attachments, isEmpty);
      expect(bare.counts, isEmpty);
      expect(bare.indexedAt, isNull);
    });
  });

  group('Feed sources', () {
    test('offers only the sources that work with an observer alone', () {
      // `author` exists in the enum but is not a tab: it needs author_id, and
      // serves only to fold the user's own posts into the following feed.
      expect(
        FeedSource.values.map((s) => s.apiValue),
        containsAll(['following', 'friends', 'all', 'bookmarks']),
      );
      expect(FeedSource.author.apiValue, 'author');
    });
  });
}
