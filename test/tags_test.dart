import 'package:flutky/pubky/tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tag ids', () {
    // The witness that matters. A tag id is not a name we choose: get the
    // derivation wrong and the homeserver stores the file happily while the
    // indexer ignores it — the same silent failure as a wrong blob id. This
    // vector comes from pubky-app-specs itself (src/models/tag.rs,
    // test_label_id), so agreeing with it is agreeing with the network.
    test('matches the vector published by pubky-app-specs', () {
      expect(
        tagId('pubky://user_id/pub/pubky.app/posts/post_id', 'cool'),
        'CBYS8P6VJPHC5XXT4WDW26662W',
      );
    });

    test('a different label is a different resource', () {
      const uri = 'pubky://user_id/pub/pubky.app/posts/post_id';
      expect(tagId(uri, 'co0l'), isNot(tagId(uri, 'cool')));
    });

    test('a different post is a different resource', () {
      expect(
        tagId('pubky://user_id/pub/pubky.app/posts/other', 'cool'),
        isNot(tagId('pubky://user_id/pub/pubky.app/posts/post_id', 'cool')));
    });

    // Idempotence is the whole point of hashing the pair: tagging twice must
    // write the same file rather than two, and untagging must be able to
    // recompute the path without having kept it.
    test('is stable across calls', () {
      const uri = 'pubky://user_id/pub/pubky.app/posts/post_id';
      expect(tagId(uri, 'cool'), tagId(uri, 'cool'));
    });

    test('reads as a Crockford id of the usual length', () {
      final id = tagId('pubky://user_id/pub/pubky.app/posts/post_id', 'cool');
      expect(id, hasLength(26));
      expect(id, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$')));
    });
  });

  group('Tag labels', () {
    // Sanitizing happens before the id is computed, so skipping it writes a
    // resource nobody else derives: `Cool` and `cool` are the same tag to
    // everyone but a client that forgot to lower-case.
    test('are trimmed and lower-cased', () {
      expect(sanitizeTagLabel('  CoOl '), 'cool');
      expect(tagId('pubky://u/pub/pubky.app/posts/p', sanitizeTagLabel(' COOL ')),
          tagId('pubky://u/pub/pubky.app/posts/p', 'cool'));
    });

    test('accepts an ordinary word', () {
      expect(tagLabelProblem('bitcoin'), isNull);
    });

    test('refuses what the spec refuses', () {
      expect(tagLabelProblem(''), 'empty');
      expect(tagLabelProblem('a' * (maxTagLabelLength + 1)), 'tooLong');
      expect(tagLabelProblem('two words'), 'invalidChar');
      expect(tagLabelProblem('a,b'), 'invalidChar');
      // The colon separates uri from label in the hash that names the tag, so
      // a label carrying one could collide with another pair.
      expect(tagLabelProblem('a:b'), 'invalidChar');
    });

    test('counts in code points, as the spec does', () {
      // Twenty emoji are twenty characters there and forty in UTF-16.
      expect(tagLabelProblem('🙂' * maxTagLabelLength), isNull);
      expect(tagLabelProblem('🙂' * (maxTagLabelLength + 1)), 'tooLong');
    });
  });
}
