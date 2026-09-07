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

  test('a key Nexus never saw raises ProfileNotIndexed, not a crash', () async {
    // 52 z-base32 chars, syntactically valid, astronomically unlikely to exist.
    const ghost = 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy';
    await expectLater(
      nexus.fetchProfile(ghost),
      throwsA(isA<ProfileNotIndexed>()),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
