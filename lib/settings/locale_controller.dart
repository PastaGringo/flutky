import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the language the user picked, and remembers it across launches.
///
/// `null` means "follow the system", which is the default: an app that ignores
/// the phone's language on first launch is more surprising than one that
/// follows it.
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController() : super(null);

  static const _key = 'locale_v1';

  /// Every language the app ships. Keep in step with `lib/l10n/*.arb`.
  static const supported = [Locale('fr'), Locale('en')];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code != null && supported.any((l) => l.languageCode == code)) {
        value = Locale(code);
      }
    } catch (_) {
      // A preference that cannot be read is not worth failing over: the app
      // simply falls back to the system language.
    }
  }

  Future<void> set(Locale? locale) async {
    value = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, locale.languageCode);
      }
    } catch (_) {
      // The choice still applies for this run.
    }
  }
}
