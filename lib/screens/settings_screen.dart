import 'dart:async';

import 'package:flutter/material.dart';

import '../pubky/translation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../settings/feed_preferences.dart';
import '../settings/locale_controller.dart';
import '../theme.dart';

const repositoryUrl = 'https://github.com/PastaGringo/flutky';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.locales,
    required this.preferences,
  });

  final LocaleController locales;
  final FeedPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackground,
        title: Text(l.actionSettings),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(l.settingsLanguage.toUpperCase()),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<Locale?>(
                    valueListenable: locales,
                    builder: (context, current, _) => Column(
                      children: [
                        _LanguageTile(
                          label: l.settingsLanguageSystem,
                          selected: current == null,
                          onTap: () => locales.set(null),
                        ),
                        for (final locale in LocaleController.supported)
                          _LanguageTile(
                            label: switch (locale.languageCode) {
                              'fr' => l.settingsLanguageFrench,
                              _ => l.settingsLanguageEnglish,
                            },
                            selected: current?.languageCode == locale.languageCode,
                            onTap: () => locales.set(locale),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(l.settingsFeed.toUpperCase()),
                  const SizedBox(height: 4),
                  ListenableBuilder(
                    listenable: preferences,
                    builder: (context, _) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: preferences.includeOwnPosts,
                      onChanged: preferences.setIncludeOwnPosts,
                      activeThumbColor: kAccent,
                      title: Text(
                        l.settingsIncludeOwnPosts,
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        l.settingsIncludeOwnPostsNote,
                        style: const TextStyle(
                            color: kTextMuted, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(l.settingsTranslation.toUpperCase()),
                  const SizedBox(height: 10),
                  _DeepLKeyField(preferences: preferences),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(l.settingsAbout.toUpperCase()),
                  const SizedBox(height: 12),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snap) => _Row(
                      label: l.settingsVersion,
                      value: snap.hasData
                          ? '${snap.data!.version} (${snap.data!.buildNumber})'
                          : '…',
                    ),
                  ),
                  _Row(label: l.settingsLicense, value: 'MIT'),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => launchUrl(
                      Uri.parse(repositoryUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.code_rounded, size: 17, color: kAccent),
                          const SizedBox(width: 10),
                          Text(
                            l.settingsSourceCode,
                            style: const TextStyle(color: kAccent, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 19,
                color: selected ? kAccent : kTextMuted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? kText : kTextMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(color: kTextMuted, fontSize: 13),
              ),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: kTextMuted,
        ),
      );
}


/// The DeepL key, checked against DeepL the moment typing stops.
///
/// A key field that only stores what it is given is a trap: the mistake shows
/// up much later, in the middle of composing, as a refusal that looks like the
/// feature being broken. Asking DeepL for the key's own usage answers two
/// questions at once — whether it works, and how much of the month is left.
class _DeepLKeyField extends StatefulWidget {
  const _DeepLKeyField({required this.preferences});

  final FeedPreferences preferences;

  @override
  State<_DeepLKeyField> createState() => _DeepLKeyFieldState();
}

class _DeepLKeyFieldState extends State<_DeepLKeyField> {
  late final _controller =
      TextEditingController(text: widget.preferences.deepLKey);

  Timer? _debounce;
  bool _checking = false;
  DeepLUsage? _usage;
  bool _refused = false;

  /// Only the latest check may paint: typing a key character by character
  /// starts several, and a slow early one must not overwrite a fast later one.
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.preferences.setDeepLKey(value);
    _debounce?.cancel();
    setState(() {
      _usage = null;
      _refused = false;
    });
    if (value.trim().isEmpty) return;
    // Long enough that a check does not fire on every keystroke of a key being
    // pasted or typed.
    _debounce = Timer(const Duration(milliseconds: 700), _check);
  }

  Future<void> _check() async {
    final generation = ++_generation;
    final key = _controller.text.trim();
    if (key.isEmpty) return;

    setState(() => _checking = true);
    final translator = Translator(deepLKey: key);
    try {
      final usage = await translator.checkUsage();
      if (!mounted || generation != _generation) return;
      setState(() {
        _usage = usage;
        _refused = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _usage = null;
        _refused = true;
      });
    } finally {
      translator.close();
      if (mounted && generation == _generation) {
        setState(() => _checking = false);
      }
    }
  }

  Widget? _status(L10n l) {
    if (_checking) return _note(l.settingsDeepLChecking, kTextMuted);
    if (_refused) return _note(l.settingsDeepLInvalid, kDanger);
    final usage = _usage;
    if (usage == null) return null;
    return _note(
      l.settingsDeepLValid('${usage.used}', '${usage.limit}'),
      kAccent,
    );
  }

  Widget _note(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 12.5, height: 1.4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final status = _status(l);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: _onChanged,
          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: l.settingsDeepLKey,
            labelStyle: const TextStyle(color: kTextMuted, fontSize: 13.5),
            hintText: l.settingsDeepLKeyHint,
            hintStyle: const TextStyle(color: kTextMuted),
            filled: true,
            fillColor: kBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: kAccent.withValues(alpha: 0.6)),
            ),
          ),
        ),
        ?status,
        const SizedBox(height: 8),
        Text(
          l.settingsDeepLKeyNote,
          style: const TextStyle(
              color: kTextMuted, fontSize: 12.5, height: 1.45),
        ),
      ],
    );
  }
}
