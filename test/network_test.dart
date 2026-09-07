// Hits the real Nexus instance. Kept in its own file so the offline suite
// (`flutter test test/pubky_test.dart`) stays deterministic.
//
//   flutter test test/network_test.dart
import 'package:flutky/pubky/nexus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _knownPubky = 'gujx6qd8ksydh1makdphd3bxu351d9b8waqka8hfg6q7hnqkxexo';

void main() {
  late NexusClient nexus;

  setUp(() => nexus = NexusClient());
  tearDown(() => nexus.close());

  test('reads a real profile from nexus.pubky.app', () async {
    final profile = await nexus.fetchProfile(_knownPubky);

    expect(profile.id, _knownPubky);
    expect(profile.name, isNotEmpty);
    expect(profile.counts['posts'], greaterThan(0));
    // ignore: avoid_print
    print('profil lu : ${profile.name} · ${profile.counts['posts']} posts · '
        '${profile.tags.length} tags');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('serves the avatar the profile points at', () async {
    final profile = await nexus.fetchProfile(_knownPubky);
    final res = await http.get(Uri.parse(profile.avatarUrl));

    expect(res.statusCode, 200);
    expect(res.headers['content-type'], startsWith('image/'));
    expect(res.bodyBytes.length, greaterThan(1000));
    // ignore: avoid_print
    print('avatar : ${res.statusCode} ${res.headers['content-type']} '
        '${res.bodyBytes.length} octets');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('reads a page of the timeline', () async {
    final posts = await nexus.fetchStream(
      source: FeedSource.all,
      observerId: _knownPubky,
      limit: 20,
    );

    expect(posts, isNotEmpty);
    expect(posts.first.id, isNotEmpty);
    expect(posts.first.author, hasLength(52));
    // ignore: avoid_print
    print('flux : ${posts.length} posts, '
        '${posts.where((p) => p.attachments.isNotEmpty).length} avec pièce jointe');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('personalised sources genuinely require the observer', () async {
    // The trap: an ignored `observer_id` silently returns the global timeline,
    // and "personalised" then looks identical to "not filtered at all".
    //
    // Comparing feeds by content was the obvious test and it is unreliable
    // here: the network is small enough that the ten newest posts overall are
    // often all from accounts the user follows, so `following` and `all`
    // legitimately coincide. Measured 2026-09-07 — they matched exactly.
    //
    // These two checks do not depend on what was posted lately.
    for (final source in [FeedSource.following, FeedSource.bookmarks]) {
      await expectLater(
        nexus.fetchStream(source: source, limit: 10),
        throwsA(isA<NexusError>()),
        reason: '${source.apiValue} without an observer must be refused, '
            'not silently answered with the global timeline',
      );
    }

    // Bookmarks are the user's own collection: their content cannot coincide
    // with the global timeline the way `following` can.
    final bookmarks = await nexus.fetchStream(
      source: FeedSource.bookmarks,
      observerId: _knownPubky,
      limit: 10,
    );
    final global = await nexus.fetchStream(
      source: FeedSource.all,
      observerId: _knownPubky,
      limit: 10,
    );

    expect(bookmarks, isNotEmpty);
    expect(
      bookmarks.map((p) => p.id).toList(),
      isNot(equals(global.map((p) => p.id).toList())),
      reason: 'a per-user source must return per-user content',
    );
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('resolves post authors in one batch', () async {
    final posts = await nexus.fetchStream(
      source: FeedSource.all,
      observerId: _knownPubky,
      limit: 20,
    );
    final authors = await nexus.fetchUsersByIds(posts.map((p) => p.author));

    expect(authors, isNotEmpty);
    expect(authors.values.first.name, isNotEmpty);
    // ignore: avoid_print
    print('auteurs résolus : ${authors.length}');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('serves the feed-sized image an attachment points at', () async {
    final posts = await nexus.fetchStream(
      source: FeedSource.all,
      observerId: _knownPubky,
      limit: 30,
    );
    final withImage = posts.where((p) => p.imageUrls().isNotEmpty).toList();
    if (withImage.isEmpty) {
      markTestSkipped('aucune pièce jointe dans cette page du flux');
      return;
    }

    final res = await http.get(Uri.parse(withImage.first.imageUrls().first));
    expect(res.statusCode, 200);
    expect(res.headers['content-type'], startsWith('image/'));
    // ignore: avoid_print
    print('image feed : ${res.headers['content-type']} '
        '${res.bodyBytes.length} octets');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a key Nexus never saw raises ProfileNotIndexed, not a crash', () async {
    // 52 z-base32 chars, syntactically valid, astronomically unlikely to exist.
    const ghost = 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy';
    await expectLater(
      nexus.fetchProfile(ghost),
      throwsA(isA<ProfileNotIndexed>()),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('public discovery', () {
    test('the hot labels come back ordered by a count that varies', () async {
      final tags = await nexus.fetchHotTags(limit: 12);
      expect(tags, isNotEmpty);
      expect(tags.first.label, isNotEmpty);

      // Ordered, descending. And read from `tagged_count`, not from
      // `taggers_count`: the response caps its list of taggers at twenty, so
      // that field reads 20 for every popular label and would order nothing.
      final counts = tags.map((t) => t.taggedCount).toList();
      expect(counts.first, greaterThan(0));
      expect(counts, orderedEquals(counts.toList()..sort((a, b) => b - a)));
      expect(counts.toSet().length, greaterThan(1),
          reason: 'des comptes tous identiques trahiraient le mauvais champ');
      final resume =
          tags.take(4).map((t) => '${t.label}=${t.taggedCount}').join(' · ');
      // ignore: avoid_print
      print('tags chauds : $resume');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('filtering by label really filters', () async {
      const label = 'bitcoin';
      final posts = await nexus.fetchStream(
        source: FeedSource.all,
        tag: label,
        sorting: PostSorting.totalEngagement,
        limit: 10,
      );
      expect(posts, isNotEmpty);
      for (final post in posts) {
        expect(post.tags.map((t) => t.label), contains(label),
            reason: 'un post sans le libellé demandé prouve un filtre ignoré');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an unknown label answers nothing, not the whole timeline', () async {
      // The witness that matters: an ignored filter parameter would hand back
      // the unfiltered stream, and a full page would read as a success.
      //
      // Kept under twenty characters on purpose: a longer label is rejected as
      // invalid (400) before any filtering happens, which would prove nothing
      // about whether the parameter is honoured.
      final posts = await nexus.fetchStream(
        source: FeedSource.all,
        tag: 'zzznobodytagsthis',
        limit: 10,
      );
      expect(posts, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('engagement and timeline are two different orderings', () async {
      final byTime = await nexus.fetchStream(
        source: FeedSource.all,
        limit: 10,
      );
      final byEngagement = await nexus.fetchStream(
        source: FeedSource.all,
        sorting: PostSorting.totalEngagement,
        limit: 10,
      );
      expect(byTime, isNotEmpty);
      expect(byEngagement, isNotEmpty);

      // Not merely a different order: a different set. The newest posts have
      // had no time to gather engagement, so the two pages should not even
      // overlap much — identical sets would mean the parameter did nothing.
      final a = byTime.map((p) => p.id).toSet();
      final b = byEngagement.map((p) => p.id).toSet();
      expect(a, isNot(equals(b)));
      // ignore: avoid_print
      print('recoupement des deux tris : ${a.intersection(b).length}/10');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('the two account rankings are distinct, and carry whole profiles',
        () async {
      final followed =
          await nexus.fetchUserStream(source: UserSource.mostFollowed);
      final influencers =
          await nexus.fetchUserStream(source: UserSource.influencers);

      expect(followed, isNotEmpty);
      expect(influencers, isNotEmpty);
      // A stream of posts carries author keys only; this one carries profiles,
      // which is what lets the strip paint without a second call.
      expect(followed.first.name, isNotEmpty);
      expect(followed.first.id.length, 52);
      expect(
        followed.map((p) => p.id).toList(),
        isNot(equals(influencers.map((p) => p.id).toList())),
        reason: 'deux classements identiques trahiraient un paramètre ignoré',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
