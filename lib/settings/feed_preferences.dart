import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reading preferences that change what the feed shows.
class FeedPreferences extends ChangeNotifier {
  static const _includeOwnKey = 'feed_include_own_v1';

  /// Nexus's `following` stream covers the accounts you follow — not you.
  /// Off by default, because that is what the source actually means; turning
  /// it on merges your own posts in, sorted with the rest.
  bool _includeOwnPosts = false;
  bool get includeOwnPosts => _includeOwnPosts;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _includeOwnPosts = prefs.getBool(_includeOwnKey) ?? false;
      notifyListeners();
    } catch (_) {
      // Unreadable preferences fall back to the defaults above.
    }
  }

  Future<void> setIncludeOwnPosts(bool value) async {
    _includeOwnPosts = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_includeOwnKey, value);
    } catch (_) {
      // The choice still applies for this run.
    }
  }
}
