import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// On-device translation, through Google's ML Kit.
///
/// Chosen over a web API on purpose: no key, no account, no quota, nothing
/// sent to a third party, and it works offline. The cost is a language model
/// downloaded once per language — around 30 MB — which is why the first
/// translation into a new language takes a moment.
///
/// The source language is detected rather than asked for: a person writing a
/// post already knows what language they are writing in, and making them say
/// so is a question with an obvious answer.
/// The two languages a translation runs between, once settled.
typedef TranslationChoice = ({TranslateLanguage from, TranslateLanguage to});

/// A stretch of text, and whether a translator may touch it.
class TextRun {
  const TextRun(this.text, {required this.translatable});
  final String text;
  final bool translatable;
}

/// Cuts [text] around the fragments [protect] matches, so they can be put back
/// byte for byte after a translation.
///
/// A mention is `pubky` followed by 52 characters, and an @Name in the editor
/// stands for one. A translator mangles both: it lowercases, inserts spaces,
/// or translates the name itself — and a mention whose key changed by one
/// character is no longer a mention, so the person is simply never notified.
/// The failure is silent, which is exactly why this exists.
List<TextRun> protectRuns(String text, RegExp protect) {
  if (text.isEmpty) return const [];
  final runs = <TextRun>[];
  var cursor = 0;
  for (final m in protect.allMatches(text)) {
    if (m.start < cursor) continue;
    if (m.start > cursor) {
      runs.add(TextRun(text.substring(cursor, m.start), translatable: true));
    }
    runs.add(TextRun(m.group(0)!, translatable: false));
    cursor = m.end;
  }
  if (cursor < text.length) {
    runs.add(TextRun(text.substring(cursor), translatable: true));
  }
  return runs;
}

class Translator {
  Translator({LanguageIdentifier? identifier})
      : _identifier = identifier ??
            LanguageIdentifier(confidenceThreshold: 0.5);

  final LanguageIdentifier _identifier;

  /// Languages offered as targets. Kept short on purpose — every entry is a
  /// model the user may end up downloading.
  static const targets = [
    TranslateLanguage.english,
    TranslateLanguage.french,
    TranslateLanguage.spanish,
    TranslateLanguage.german,
    TranslateLanguage.italian,
    TranslateLanguage.portuguese,
  ];

  /// Detected source language, or null when ML Kit is not confident enough.
  ///
  /// It answers the BCP-47 tag `und` for "undetermined" — treated as null
  /// rather than passed on, since it is not a language anyone can translate
  /// from.
  Future<TranslateLanguage?> detect(String text) async {
    if (text.trim().length < 8) return null; // too short to judge
    try {
      final code = await _identifier.identifyLanguage(text);
      if (code == 'und') return null;
      return BCP47Code.fromRawValue(code);
    } catch (_) {
      return null;
    }
  }

  /// Translates, downloading the models if needed.
  ///
  /// Returns the text unchanged when source and target are the same — calling
  /// ML Kit for that would download a model to do nothing.
  Future<String> translate(
    String text, {
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) async {
    if (from == to) return text;

    final translator =
        OnDeviceTranslator(sourceLanguage: from, targetLanguage: to);
    try {
      return await translator.translateText(text);
    } finally {
      // The plugin holds native resources: not closing it leaks them for the
      // lifetime of the process.
      await translator.close();
    }
  }

  /// Translates everything except what [protect] matches.
  ///
  /// Each translatable run goes through separately and is put back in place,
  /// so the protected fragments keep their exact position — not merely their
  /// presence. Splitting a sentence around a mention costs a little fluency;
  /// letting the translator rewrite a key costs the mention itself.
  Future<String> translateProtecting(
    String text, {
    required TranslateLanguage from,
    required TranslateLanguage to,
    required RegExp protect,
  }) async {
    if (from == to) return text;
    final runs = protectRuns(text, protect);
    if (runs.every((r) => !r.translatable)) return text;

    final out = StringBuffer();
    final translator =
        OnDeviceTranslator(sourceLanguage: from, targetLanguage: to);
    try {
      for (final run in runs) {
        if (!run.translatable || run.text.trim().isEmpty) {
          out.write(run.text);
          continue;
        }
        // Leading and trailing spaces are kept out of the call: some engines
        // drop them, which would weld a mention onto the previous word and
        // break the very match this protects.
        final lead = RegExp(r'^\s*').firstMatch(run.text)!.group(0)!;
        final tail = RegExp(r'\s*$').firstMatch(run.text)!.group(0)!;
        final body = run.text.substring(lead.length, run.text.length - tail.length);
        out
          ..write(lead)
          ..write(await translator.translateText(body))
          ..write(tail);
      }
    } finally {
      await translator.close();
    }
    return out.toString();
  }

  Future<void> close() => _identifier.close();
}

/// Human label for a language, in that language — so the list reads the same
/// whatever the interface language is.
String languageLabel(TranslateLanguage language) => switch (language) {
      TranslateLanguage.english => 'English',
      TranslateLanguage.french => 'Français',
      TranslateLanguage.spanish => 'Español',
      TranslateLanguage.german => 'Deutsch',
      TranslateLanguage.italian => 'Italiano',
      TranslateLanguage.portuguese => 'Português',
      _ => language.bcpCode.toUpperCase(),
    };
