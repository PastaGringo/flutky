import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../pubky/homeserver.dart';
import '../pubky/mypubky.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';
import 'grant_upgrade.dart';

/// The reader's mypubky card: what `mypubky.com/<key>` shows, edited here.
///
/// Reading takes no authorization — the card is a JSON file under `/pub/`.
/// Saving does, and it is a capability the sign-in grant does not carry, so
/// the first save asks Ring for a wider one.
class MypubkyScreen extends StatefulWidget {
  const MypubkyScreen({
    super.key,
    required this.session,
    required this.onSessionChanged,
  });

  final RingSession session;

  /// Hands a widened grant back up, so it is stored and the rest of the app
  /// uses it too — a credential that lives only on this screen would be lost
  /// the moment it closes.
  final void Function(RingSession) onSessionChanged;

  @override
  State<MypubkyScreen> createState() => _MypubkyScreenState();
}

class _MypubkyScreenState extends State<MypubkyScreen> {
  final _client = MypubkyClient();

  late RingSession _session = widget.session;
  MypubkyCard? _card;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  /// True when this account has no card yet. Worth distinguishing from an
  /// empty one: saving creates it, and the screen says so rather than
  /// pretending to edit something that exists.
  bool _fresh = false;

  bool get _canWrite => _session.capabilities.any(
        (c) => c.startsWith('/pub/mypubky.com/'),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final card = await _client.fetchCard(_session.pubky);
      if (!mounted) return;
      setState(() {
        _fresh = card == null;
        _card = card ?? MypubkyCard.empty(_session.pubky);
        _dirty = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _change(MypubkyCard next) => setState(() {
        _card = next;
        _dirty = true;
      });

  Future<void> _save() async {
    final card = _card;
    if (card == null || _saving) return;
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!_canWrite) {
      final wider = await requestWiderGrant(
        context,
        current: _session,
        extraCapabilities: const [mypubkyCapability],
        reason: l.mypubkyGrantReason,
      );
      if (wider == null || !mounted) return;
      setState(() => _session = wider);
      widget.onSessionChanged(wider);
    }

    setState(() => _saving = true);
    final client = HomeserverClient(session: _session);
    try {
      await client.putJson(mypubkyCardPath, card.toJson());
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _fresh = false;
      });
      messenger.showSnackBar(SnackBar(content: Text(l.mypubkySaved)));
    } on WriteUnauthorized {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.mypubkyRefused)),
        );
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      client.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editLink([int? index]) async {
    final card = _card;
    if (card == null) return;
    final existing = index == null ? null : card.links[index];
    final result = await showModalBottomSheet<MypubkyLink?>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LinkSheet(link: existing),
    );
    if (result == null || !mounted) return;
    final links = [...card.links];
    if (index == null) {
      links.add(result);
    } else {
      links[index] = result;
    }
    _change(card.copyWith(links: links));
  }

  Future<void> _editSocial([int? index]) async {
    final card = _card;
    if (card == null) return;
    final existing = index == null ? null : card.socials[index];
    final result = await showModalBottomSheet<MypubkySocial?>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SocialSheet(social: existing),
    );
    if (result == null || !mounted) return;
    final socials = [...card.socials];
    if (index == null) {
      socials.add(result);
    } else {
      socials[index] = result;
    }
    _change(card.copyWith(socials: socials));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final card = _card;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackground,
        title: const Text('mypubky'),
        actions: [
          if (card != null)
            IconButton(
              tooltip: l.mypubkyOpenPublic,
              onPressed: () => launchUrl(
                Uri.parse(card.publicUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
            ),
        ],
      ),
      floatingActionButton: card == null || !_dirty
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              backgroundColor: kAccent,
              foregroundColor: kBackground,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kBackground),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_fresh ? l.mypubkyCreate : l.mypubkySave),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              if (_error != null) ...[
                ErrorPanel(message: _error!),
                const SizedBox(height: 14),
              ],
              if (_loading && card == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              if (card != null) ...[
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fresh ? l.mypubkyNoCardTitle : l.mypubkyIntroTitle,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _fresh ? l.mypubkyNoCardBody : l.mypubkyIntroBody,
                        style: const TextStyle(
                            color: kTextMuted, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Section(
                  title: l.mypubkyLinks,
                  onAdd: () => unawaited(_editLink()),
                  children: [
                    for (final (i, link) in card.links.indexed)
                      _RowTile(
                        icon: link.mailto != null && link.mailto!.isNotEmpty
                            ? Icons.mail_outline_rounded
                            : Icons.link_rounded,
                        title: link.title,
                        subtitle: link.target ?? '',
                        onTap: () => unawaited(_editLink(i)),
                        onRemove: () => _change(card.copyWith(
                          links: [...card.links]..removeAt(i),
                        )),
                      ),
                    if (card.links.isEmpty) _EmptyLine(l.mypubkyNoLinks),
                  ],
                ),
                const SizedBox(height: 14),
                _Section(
                  title: l.mypubkySocials,
                  onAdd: () => unawaited(_editSocial()),
                  children: [
                    for (final (i, social) in card.socials.indexed)
                      _RowTile(
                        icon: Icons.alternate_email_rounded,
                        title: social.title.isEmpty ? social.key : social.title,
                        subtitle: social.url,
                        onTap: () => unawaited(_editSocial(i)),
                        onRemove: () => _change(card.copyWith(
                          socials: [...card.socials]..removeAt(i),
                        )),
                      ),
                    if (card.socials.isEmpty) _EmptyLine(l.mypubkyNoSocials),
                  ],
                ),
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(l.mypubkyAppearance),
                      const SizedBox(height: 10),
                      _Choice(
                        label: l.mypubkyBackground,
                        value: card.backgroundId,
                        // `custom` stays selectable only when it is already
                        // set: Flutky cannot produce one, and offering it
                        // would be a button that undoes an upload.
                        options: [
                          ...MypubkyCard.builtInBackgrounds,
                          if (!MypubkyCard.builtInBackgrounds
                              .contains(card.backgroundId))
                            card.backgroundId,
                        ],
                        onPick: (v) => _change(
                          MypubkyCard.builtInBackgrounds.contains(v)
                              ? card.withBuiltInBackground(v)
                              // `custom` is only ever re-selected, never
                              // chosen: Flutky cannot upload the file it
                              // stands for, so its URL is left alone.
                              : card.copyWith(changes: {'backgroundId': v}),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Choice(
                        label: l.mypubkyCardPosition,
                        value: card.cardPosition,
                        options: MypubkyCard.positions,
                        onPick: (v) =>
                            _change(card.copyWith(changes: {'cardPosition': v})),
                      ),
                      const SizedBox(height: 10),
                      _Choice(
                        label: l.mypubkyCardMode,
                        value: card.cardBackgroundMode,
                        options: MypubkyCard.backgroundModes,
                        onPick: (v) => _change(
                            card.copyWith(changes: {'cardBackgroundMode': v})),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(l.mypubkyShown),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: kAccent,
                        value: card.showLatestPost,
                        onChanged: (v) => _change(
                            card.copyWith(changes: {'showLatestPost': v})),
                        title: Text(l.mypubkyShowPosts,
                            style: const TextStyle(fontSize: 14.5)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: kAccent,
                        value: card.showTags,
                        onChanged: (v) =>
                            _change(card.copyWith(changes: {'showTags': v})),
                        title: Text(l.mypubkyShowTags,
                            style: const TextStyle(fontSize: 14.5)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: kAccent,
                        value: card.donateEnabled,
                        onChanged: (v) => _change(
                            card.copyWith(changes: {'donateEnabled': v})),
                        title: Text(l.mypubkyDonate,
                            style: const TextStyle(fontSize: 14.5)),
                        subtitle: Text(
                          l.mypubkyDonateNote,
                          style: const TextStyle(
                              color: kTextMuted, fontSize: 12.5, height: 1.4),
                        ),
                      ),
                      if (card.donateEnabled) ...[
                        const SizedBox(height: 6),
                        TextFormField(
                          initialValue: card.bitcoinAddress,
                          decoration: InputDecoration(
                            labelText: l.mypubkyBitcoinAddress,
                            hintText: 'bc1…',
                          ),
                          onChanged: (v) => _change(card.copyWith(
                              changes: {'bitcoinAddress': v.trim()})),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Panel(
                  child: Row(
                    children: [
                      Icon(
                        _canWrite
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        size: 17,
                        color: _canWrite ? kAccent : kTextMuted,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          _canWrite ? l.mypubkyGrantHeld : l.mypubkyGrantNeeded,
                          style: const TextStyle(
                              color: kTextMuted, fontSize: 12.5, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.onAdd,
    required this.children,
  });

  final String title;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _SectionTitle(title)),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  color: kAccent,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: kTextMuted,
          fontSize: 11.5,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: const TextStyle(color: kTextMuted, fontSize: 13)),
      );
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onRemove,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 17, color: kTextMuted),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5)),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: kTextMuted, fontSize: 12.5),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 17),
                color: kTextMuted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.options,
    required this.onPick,
  });

  final String label;
  final String value;
  final List<String> options;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13.5)),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(
                    option,
                    // Set explicitly: left to the theme, a selected chip takes
                    // `onSecondaryContainer`, which came out dark on this dark
                    // fill and made the chosen value the hardest to read.
                    style: TextStyle(
                      fontSize: 12.5,
                      color: option == value ? kAccent : kText,
                    ),
                  ),
                  selected: option == value,
                  onSelected: (_) => onPick(option),
                  showCheckmark: false,
                  selectedColor: kAccent.withValues(alpha: 0.18),
                  side: BorderSide(
                    color: option == value ? kAccent : kBorder,
                  ),
                ),
            ],
          ),
        ],
      );
}

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({required this.link});
  final MypubkyLink? link;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final _title = TextEditingController(text: widget.link?.title ?? '');
  late final _target = TextEditingController(
    text: widget.link?.mailto?.isNotEmpty == true
        ? widget.link!.mailto!
        : widget.link?.url ?? '',
  );

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.mypubkyLinkTitle,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: l.mypubkyLinkLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l.mypubkyLinkTarget,
              hintText: 'https://…  ·  nom@domaine',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final title = _title.text.trim();
                final target = _target.text.trim();
                if (title.isEmpty || target.isEmpty) return;
                // A target with an @ and no scheme is an address, not a page.
                final isMail = !target.contains('://') && target.contains('@');
                Navigator.pop(
                  context,
                  MypubkyLink(
                    title: title,
                    url: isMail ? null : target,
                    mailto: isMail ? target : null,
                  ),
                );
              },
              child: Text(l.actionSave),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialSheet extends StatefulWidget {
  const _SocialSheet({required this.social});
  final MypubkySocial? social;

  @override
  State<_SocialSheet> createState() => _SocialSheetState();
}

class _SocialSheetState extends State<_SocialSheet> {
  /// The platform names mypubky.com has an icon for. A key it does not know
  /// renders as a blank circle on the public card, so they are offered as
  /// chips rather than typed.
  static const platforms = [
    'github',
    'x',
    'telegram',
    'nostr',
    'youtube',
    'linkedin',
    'instagram',
    'website',
  ];

  late String _key = widget.social?.key ?? platforms.first;
  late final _url = TextEditingController(text: widget.social?.url ?? '');

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.mypubkySocialTitle,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in {...platforms, _key})
                ChoiceChip(
                  label: Text(
                    p,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: p == _key ? kAccent : kText,
                    ),
                  ),
                  selected: p == _key,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _key = p),
                  selectedColor: kAccent.withValues(alpha: 0.18),
                  side: BorderSide(color: p == _key ? kAccent : kBorder),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l.mypubkySocialUrl,
              hintText: 'https://…',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final url = _url.text.trim();
                if (url.isEmpty) return;
                Navigator.pop(
                  context,
                  MypubkySocial(
                    key: _key,
                    title: _key[0].toUpperCase() + _key.substring(1),
                    url: url,
                  ),
                );
              },
              child: Text(l.actionSave),
            ),
          ),
        ],
      ),
    );
  }
}
