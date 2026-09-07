import 'package:flutter/material.dart';

import 'feed_preferences.dart';

/// Puts the preferences within reach of any widget below.
///
/// The translate button lives on every post card, and a card is built by the
/// feed, by discovery and by the thread screen alike. Threading a DeepL key
/// through five constructors would mean five places to forget it — and the
/// forgetting would be silent, showing a button that does nothing.
///
/// An InheritedNotifier rather than an InheritedWidget: the key can change in
/// the settings while a feed is on screen, and the cards should follow.
class PreferencesScope extends InheritedNotifier<FeedPreferences> {
  const PreferencesScope({
    super.key,
    required FeedPreferences preferences,
    required super.child,
  }) : super(notifier: preferences);

  /// The preferences, or null outside a scope — which is what a widget test
  /// building a card on its own will see, and it must not crash there.
  static FeedPreferences? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PreferencesScope>()
      ?.notifier;
}
