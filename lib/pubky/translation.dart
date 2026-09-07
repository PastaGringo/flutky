/// Translating a draft before publishing it, through DeepL.
///
/// Two earlier attempts are worth recording, because both looked better than
/// this one until they met reality.
///
/// **Google ML Kit, on the device.** The best idea on paper: nothing left the
/// phone and it worked offline. It threw `MissingPluginException` on the
/// translator channel of a signed release where the plugin was demonstrably
/// packaged, cost 19 MB of APK, and made the first translation into each
/// language wait for a model download.
///
/// **MyMemory, keyless.** It translated well and needed no account at all,
/// which made the feature work on first launch. It also answered 504 several
/// times in a row while being tested, capped a request at 500 characters, and
/// allowed 5 000 a day. A feature that works when the service feels like it is
/// worse than one that plainly asks for a key.
///
/// So: a key, and DeepL. 500 000 characters a month on its free plan, 128 KiB
/// per request — so a whole draft goes in a single call — and the source
/// language detected server-side. Without a key the button says what to do
/// rather than failing.
///
/// **The draft leaves the device.** It is text on its way to a public post,
/// which softens that, but it is not the same promise as on-device
/// translation, and the interface says so.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// The two languages a translation runs between, once settled.
typedef TranslationChoice = ({String from, String to});

/// How much of the monthly allowance a key has spent.
typedef DeepLUsage = ({int used, int limit});

/// Stands for "let DeepL work it out", which it does when `source_lang` is
/// omitted: "If this parameter is omitted, the API will attempt to detect the
/// language of the text and translate it."
const autoDetect = 'auto';

/// DeepL publishes two hosts, and a free key is recognisable on sight: "DeepL
/// API Free authentication keys can be identified easily by the suffix `:fx`".
/// So the right host is deduced rather than asked for — one fewer setting to
/// leave wrong.
String deepLBase(String key) => key.trim().endsWith(':fx')
    ? 'https://api-free.deepl.com'
    : 'https://api.deepl.com';

/// The languages offered, by their DeepL code.
const translationLanguages = <String, String>{
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'de': 'Deutsch',
  'it': 'Italiano',
  'pt': 'Português',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'ru': 'Русский',
  'ja': '日本語',
  'zh': '中文',
};

String languageLabel(String code) =>
    translationLanguages[code] ?? code.toUpperCase();

/// DeepL wants upper case, and refuses a bare `EN` or `PT` as a *target*: it
/// asks for the variant, because the two spellings genuinely differ.
String deepLTarget(String code) => switch (code) {
      'en' => 'EN-GB',
      'pt' => 'PT-PT',
      _ => code.toUpperCase(),
    };

/// The service refused the translation.
class TranslationRefused implements Exception {
  const TranslationRefused(
    this.code,
    this.message, {
    this.quotaExhausted = false,
    this.badKey = false,
  });

  final int code;
  final String message;

  /// DeepL answers **456** for this, not a generic 4xx. Singled out because it
  /// is a failure the person can act on rather than retry.
  final bool quotaExhausted;

  /// The key itself was rejected, which no amount of retrying fixes.
  final bool badKey;

  @override
  String toString() => message;
}

/// No key has been entered yet.
///
/// Its own type so the interface can point at the setting instead of showing
/// an HTTP error for something that is not a failure at all.
class TranslationKeyMissing implements Exception {
  const TranslationKeyMissing();
  @override
  String toString() => 'aucune clé DeepL';
}

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
  Translator({http.Client? client, String? deepLKey})
      : _client = client ?? http.Client(),
        deepLKey = (deepLKey ?? '').trim();

  final http.Client _client;

  /// The key, or empty. Empty is not an error state — it is the state the app
  /// starts in, and the compose sheet says so.
  final String deepLKey;

  bool get ready => deepLKey.isNotEmpty;

  static const _timeout = Duration(seconds: 25);

  /// Translates everything except what [protect] matches.
  ///
  /// The protected fragments keep their exact position, not merely their
  /// presence. Splitting a sentence around a mention costs a little fluency;
  /// letting the translator rewrite a key costs the mention itself.
  ///
  /// DeepL takes an array of texts within a 128 KiB request, so however many
  /// pieces a draft breaks into, they all travel in one round trip.
  Future<String> translateProtecting(
    String text, {
    required String from,
    required String to,
    required RegExp protect,
  }) async {
    if (!ready) throw const TranslationKeyMissing();
    if (from == to) return text;

    final runs = protectRuns(text, protect);
    final indexes = <int>[
      for (var i = 0; i < runs.length; i++)
        if (runs[i].translatable && runs[i].text.trim().isNotEmpty) i,
    ];
    if (indexes.isEmpty) return text;

    // Leading and trailing spaces never go to the service: they carry nothing
    // to translate, and losing one would weld a mention onto the previous word
    // — breaking the very match this protects.
    final trimmed = {for (final i in indexes) i: _trim(runs[i].text)};
    final translated = await _translate(
      [for (final i in indexes) trimmed[i]!.body],
      from: from,
      to: to,
    );

    final byIndex = {
      for (var n = 0; n < indexes.length; n++) indexes[n]: translated[n],
    };

    final out = StringBuffer();
    for (var i = 0; i < runs.length; i++) {
      final piece = byIndex[i];
      if (piece == null) {
        out.write(runs[i].text);
        continue;
      }
      out
        ..write(trimmed[i]!.lead)
        ..write(piece)
        ..write(trimmed[i]!.tail);
    }
    return out.toString();
  }

  ({String lead, String body, String tail}) _trim(String text) {
    final lead = RegExp(r'^\s*').firstMatch(text)!.group(0)!;
    final tail = RegExp(r'\s*$').firstMatch(text)!.group(0)!;
    return (
      lead: lead,
      body: text.substring(lead.length, text.length - tail.length),
      tail: tail,
    );
  }

  Future<List<String>> _translate(
    List<String> texts, {
    required String from,
    required String to,
  }) async {
    final res = await _client
        .post(
          Uri.parse('${deepLBase(deepLKey)}/v2/translate'),
          headers: {
            'Authorization': 'DeepL-Auth-Key $deepLKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'text': texts,
            'target_lang': deepLTarget(to),
            // Omitting the source is what asks DeepL to detect it.
            if (from != autoDetect) 'source_lang': from.toUpperCase(),
          }),
        )
        .timeout(_timeout);

    _check(res.statusCode);

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final list =
        decoded is Map<String, dynamic> ? decoded['translations'] : null;
    if (list is! List || list.length != texts.length) {
      throw const TranslationRefused(0, 'réponse DeepL inattendue');
    }
    return [
      for (final entry in list)
        entry is Map<String, dynamic> ? '${entry['text'] ?? ''}' : '',
    ];
  }

  /// Reads what the key has spent this month.
  ///
  /// Used to check a key the moment it is typed: a key that cannot answer this
  /// will not translate either, and learning that in the settings beats
  /// learning it halfway through composing a post.
  Future<DeepLUsage> checkUsage() async {
    if (!ready) throw const TranslationKeyMissing();
    final res = await _client.get(
      Uri.parse('${deepLBase(deepLKey)}/v2/usage'),
      headers: {'Authorization': 'DeepL-Auth-Key $deepLKey'},
    ).timeout(_timeout);

    _check(res.statusCode);

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const TranslationRefused(0, 'réponse DeepL inattendue');
    }
    return (
      used: (decoded['character_count'] as num?)?.toInt() ?? 0,
      limit: (decoded['character_limit'] as num?)?.toInt() ?? 0,
    );
  }

  /// Turns a status code into the failure it actually means.
  ///
  /// 403 and 456 are the two a person can do something about, and they are
  /// the two worth telling apart: one says the key is wrong, the other says
  /// the month is spent.
  ///
  /// ⚠️ A 403 is **not** diagnostic of anything else. Measured against the
  /// live host: `/v2/translate`, `/v2/usage` and `/v2/zzz` all answer 403 to a
  /// bad key, so authentication runs before routing — exactly like the Pubky
  /// homeserver. A 403 therefore cannot be read as proof that a path exists.
  void _check(int status) {
    switch (status) {
      case 200:
        return;
      case 401:
      case 403:
        throw const TranslationRefused(403, 'clé refusée', badKey: true);
      case 456:
        throw const TranslationRefused(456, 'quota épuisé',
            quotaExhausted: true);
      default:
        throw TranslationRefused(status, 'HTTP $status');
    }
  }

  void close() => _client.close();
}
