import 'package:flutky/pubky/mentions.dart';
import 'package:flutky/pubky/translation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pattern the compose sheet builds: the aliases on screen, plus anything
/// already in wire form, plus links.
RegExp protector(Iterable<String> aliases) => RegExp([
      for (final a in aliases.toList()
        ..sort((x, y) => y.length.compareTo(x.length)))
        RegExp.escape(a),
      mentionPattern,
      linkPattern,
    ].join('|'));

const jeb = '9o6xrx8wgqu48dmb47uep6w3dgbwdnf5jgw83gbeuxg9yi7x444y';

void main() {
  group('what a translation must not touch', () {
    test('a raw mention comes out as one indivisible run', () {
      final runs = protectRuns('Hello pubky$jeb, how are you?', protector([]));
      final protectedRuns = runs.where((r) => !r.translatable).toList();

      expect(protectedRuns, hasLength(1));
      expect(protectedRuns.single.text, 'pubky$jeb');
      // And the prose around it is still offered for translation, otherwise
      // protecting the mention would have cost the sentence.
      expect(runs.where((r) => r.translatable).map((r) => r.text),
          ['Hello ', ', how are you?']);
    });

    test('an @alias is protected, and so is a link', () {
      final runs = protectRuns(
        'Ask @Jeb about https://pubky.org please',
        protector(['@Jeb']),
      );
      expect(
        runs.where((r) => !r.translatable).map((r) => r.text),
        ['@Jeb', 'https://pubky.org'],
      );
    });

    test('the runs put back together are the original, byte for byte', () {
      const text = 'Salut @Jeb et pubky$jeb — voir https://pubky.app/x !';
      final runs = protectRuns(text, protector(['@Jeb']));
      expect(runs.map((r) => r.text).join(), text);
    });

    test('a longer alias wins over the shorter one it starts with', () {
      // Two people called Jeb: the second alias carries a key suffix, and the
      // shorter pattern must not eat its head.
      final runs = protectRuns(
        'cc @Jeb-9o6x',
        protector(['@Jeb', '@Jeb-9o6x']),
      );
      expect(runs.where((r) => !r.translatable).single.text, '@Jeb-9o6x');
    });

    test('text with nothing to protect is one translatable run', () {
      final runs = protectRuns('rien à protéger ici', protector([]));
      expect(runs, hasLength(1));
      expect(runs.single.translatable, isTrue);
    });
  });

  group('the @Name shown in the editor', () {
    test('drops spaces and punctuation, keeping the name readable', () {
      expect(aliasForMention(jeb, 'John Carvalho', {}), '@JohnCarvalho');
      expect(aliasForMention(jeb, 'Séverin-Alex B. 🇨🇭', {}), '@Sverin-AlexB');
    });

    test('falls back to the key when a name leaves nothing usable', () {
      // A display name made only of emoji sanitises to an empty string; an
      // empty alias would match everywhere and swallow the whole post.
      expect(aliasForMention(jeb, '🍄‍🟫', {}), '@${jeb.substring(0, 6)}');
    });

    test('reuses the same alias for the same key', () {
      const existing = {'@Jeb': jeb};
      expect(aliasForMention(jeb, 'Jeb', existing), '@Jeb');
    });

    test('disambiguates two people who share a name', () {
      const other = 'yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy';
      const existing = {'@Jeb': jeb};
      final alias = aliasForMention(other, 'Jeb', existing);

      expect(alias, isNot('@Jeb'));
      expect(alias, '@Jeb-yyyy');
    });

    test('a very long name is cut, so the alias stays editable', () {
      final alias = aliasForMention(jeb, 'A' * 60, {});
      expect(alias.length, 25); // '@' plus 24
    });
  });

  group('choosing where to send the request', () {
    test('a free key picks the free host, on its suffix alone', () {
      // DeepL: "Free authentication keys can be identified easily by the
      // suffix :fx". Deducing it means there is no second setting to leave
      // inconsistent with the key.
      expect(deepLBase('abc-123:fx'), 'https://api-free.deepl.com');
      expect(deepLBase('  abc-123:fx  '), 'https://api-free.deepl.com');
      expect(deepLBase('abc-123'), 'https://api.deepl.com');
    });

    test('English and Portuguese targets carry their variant', () {
      // A bare EN or PT is refused as a target: the two spellings differ, so
      // DeepL asks which one.
      expect(deepLTarget('en'), 'EN-GB');
      expect(deepLTarget('pt'), 'PT-PT');
      expect(deepLTarget('de'), 'DE');
    });

    test('without a key nothing is sent at all', () async {
      final translator = Translator();
      expect(translator.ready, isFalse);
      await expectLater(
        translator.translateProtecting('bonjour',
            from: 'fr', to: 'en', protect: RegExp(r'(?!)')),
        throwsA(isA<TranslationKeyMissing>()),
      );
    });
  });
}
