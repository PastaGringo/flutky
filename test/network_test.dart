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

  test('the observer actually personalises the stream', () async {
    // The trap this guards against: an ignored filter silently returns the
    // global timeline, and "personalised" looks identical to "not filtered".
    const other = 'nkcct8tzquo8n4z5ysz9t963ye9kq1w7gb55aad1z4tmsgjjhmto';

    Future<List<String>> ids(FeedSource source, String observer) async =>
        (await nexus.fetchStream(source: source, observerId: observer, limit: 10))
            .map((p) => p.id)
            .toList();

    final following = await ids(FeedSource.following, _knownPubky);
    final global = await ids(FeedSource.all, _knownPubky);
    final otherFollowing = await ids(FeedSource.following, other);

    expect(following, isNotEmpty);
    expect(following, isNot(equals(global)),
        reason: 'following must differ from the global timeline');
    expect(following, isNot(equals(otherFollowing)),
        reason: 'two observers must not get the same following stream');
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
}
