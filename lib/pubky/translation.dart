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
