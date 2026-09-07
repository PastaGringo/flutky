import 'dart:convert';
import 'dart:io';

import 'package:flutky/pubky/mentions.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'io4n977ogo1i8j66xx9xxnwosk7syazxw4xnuhhzegn3jsqhzwuy';

void main() {
  group('Mentions', () {
    test('picks a mention out of surrounding text', () {
      final spans = parseContent('Hey pubky$_key, ça va ?');

      expect(spans, hasLength(3));
      expect((spans[0] as TextSpanPart).text, 'Hey ');
      expect((spans[1] as MentionSpan).pubky, _key);
      expect((spans[2] as TextSpanPart).text, ', ça va ?');
    });

    test('does not mistake a pubky:// URI for a mention', () {
      const uri = 'pubky://$_key/pub/pubky.app/posts/0035NR9Z7A840';
      final spans = parseContent('voir $uri ici');

      expect(spans.whereType<MentionSpan>(), isEmpty);
      expect(mentionedKeys(uri), isEmpty);
    });

    test('keeps links and mentions side by side', () {
      final spans = parseContent(
        'Hey pubky$_key, joue ici : https://example.com/x?a=1 merci',
      );

      expect(spans.whereType<MentionSpan>(), hasLength(1));
      final links = spans.whereType<LinkSpan>().toList();
      expect(links, hasLength(1));
      expect(links.first.url, 'https://example.com/x?a=1');
    });

    test('handles several mentions in one post', () {
      const other = 'gabrijfdx7t8nc1yo94repxc8wo8nic9kcs5prwfafixy5hr3aeo';
      final keys = mentionedKeys('pubky$_key et pubky$other');

      expect(keys, {_key, other});
    });

    test('leaves plain content untouched', () {
      final spans = parseContent('juste du texte');
      expect(spans, hasLength(1));
      expect((spans.single as TextSpanPart).text, 'juste du texte');
      expect(parseContent(''), isEmpty);
    });

    // The witness: mentions written by real clients, not by our own encoder.
    // Nexus reports which keys a post mentions, so the parser can be checked
    // against that list rather than against our own assumption of the format.
    test('finds exactly the keys Nexus reports as mentioned', () {
      final raw = File('test/fixtures/nexus_mentions.json').readAsStringSync();
      final posts = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      expect(posts, isNotEmpty);

      var checked = 0;
      for (final post in posts) {
        final content = post['details']['content'] as String;
        final reported = ((post['relationships']?['mentioned'] as List<dynamic>?) ?? [])
            .cast<String>()
            .toSet();
        if (reported.isEmpty) continue;

        // A deleted post keeps its relationship but loses its text.
        if (content == '[DELETED]') continue;

        expect(mentionedKeys(content), reported,
            reason: 'contenu : $content');
        checked++;
      }
      expect(checked, greaterThan(0), reason: 'aucun post exploitable dans la fixture');
    });
  });
}
