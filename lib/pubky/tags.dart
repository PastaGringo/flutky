/// Tag ids, which are content-addressed rather than chosen.
///
/// A tag lives at `/pub/pubky.app/tags/<id>` where the id is the Crockford
/// base32 of the **first half** of `BLAKE3("<uri>:<label>")` — the same
/// derivation as a blob id, applied to a string rather than to bytes. That is
/// what makes a tag idempotent: tagging the same post with the same label
/// twice writes the same resource, and removing it is a DELETE on a path both
/// sides can compute.
///
/// The consequence of getting it wrong is the usual pubky one: the homeserver
/// stores the file happily and the indexer ignores it, in silence. Hence the
/// test against pubky-app-specs' own vector.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'blake3.dart';
import 'crockford.dart';

/// What pubky-app-specs accepts for a label, checked here so the refusal
/// happens under the text field rather than as a silently ignored write.
const maxTagLabelLength = 20;
const minTagLabelLength = 1;

/// `tag_invalid_chars` in the spec. The comma and the colon are structural —
/// the colon separates uri from label in the very hash that names the tag.
const tagInvalidChars = [',', ':', ' ', '\t', '\n', '\r'];

/// Trimmed and lower-cased, exactly as `sanitize()` does before the id is
/// computed. Skipping this writes a resource whose id nobody else derives.
String sanitizeTagLabel(String raw) => raw.trim().toLowerCase();

/// Null when the label is publishable, otherwise the reason.
String? tagLabelProblem(String label) {
  // Counted in code points, as the spec does — an emoji label is one
  // character there and four here if counted in UTF-16.
  final length = label.runes.length;
  if (length < minTagLabelLength) return 'empty';
  if (length > maxTagLabelLength) return 'tooLong';
  for (final c in tagInvalidChars) {
    if (label.contains(c)) return 'invalidChar';
  }
  return null;
}

/// `Crockford(BLAKE3("<uri>:<label>")[..16])`.
///
/// The label must already be sanitized: the id is computed on what will be
/// stored, and `Cool` and `cool` are the same tag with different hashes.
String tagId(String uri, String label) {
  final data = Uint8List.fromList(utf8.encode('$uri:$label'));
  final hash = blake3(data);
  return crockfordBytes(hash.sublist(0, hash.length ~/ 2));
}
