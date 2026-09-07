import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../pubky/grant_auth.dart';
import '../pubky/homeserver.dart';
import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';

/// What a successful publish hands back: enough to render the post before the
/// indexer has seen it.
typedef PublishedPost = ({String id, String content});

/// Composes and publishes a short post.
///
/// Returns the new post when the write succeeded, null otherwise — the caller
/// shows it optimistically, since Nexus lags the homeserver and cannot confirm
/// a fresh write.
/// The AI account on Pubky: mentioning it makes it answer in the feed.
const jebPubky = '9o6xrx8wgqu48dmb47uep6w3dgbwdnf5jgw83gbeuxg9yi7x444y';

Future<PublishedPost?> showComposeSheet(
  BuildContext context, {
  required RingSession session,
  required NexusClient nexus,
  String initialContent = '',
}) =>
    showModalBottomSheet<PublishedPost>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ComposeSheet(
        session: session,
        nexus: nexus,
        initialContent: initialContent,
      ),
    );

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({
    required this.session,
    required this.nexus,
    required this.initialContent,
  });

  final RingSession session;
  final NexusClient nexus;
  final String initialContent;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  late final _controller = TextEditingController(text: widget.initialContent);
  bool _sending = false;
  String? _error;

  /// Result of minting a token before the user types anything: publishing is
  /// worth attempting only if the homeserver already accepts our credentials.
  bool? _canWrite;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final client = HomeserverClient(session: widget.session);
    try {
      await client.checkWriteAccess();
      if (mounted) setState(() => _canWrite = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _canWrite = false;
          _accessError = '$e';
        });
      }
    } finally {
      client.close();
    }
  }


  /// Inserts a mention at the caret.
  ///
  /// The wire format is the literal `pubky` followed by the key, with no
  /// separator — the @Name a reader sees is a rendering, not what is stored.
  /// Spaces are added around it so it never welds onto a neighbouring word,
  /// which would break the 52-character match.
  void _insertMention(String pubky) {
    final text = _controller.text;
    final sel = _controller.selection;
    final at = sel.isValid ? sel.start : text.length;

    final before = text.substring(0, at);
    final after = text.substring(at);
    final needsLeading = before.isNotEmpty && !before.endsWith(" ");
    final token = '${needsLeading ? ' ' : ''}pubky$pubky ';

    setState(() {
      _controller.value = TextEditingValue(
        text: before + token + after,
        selection: TextSelection.collapsed(offset: (before + token).length),
      );
    });
  }

  Future<void> _pickMention() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MentionPicker(nexus: widget.nexus),
    );
    if (picked != null) _insertMention(picked);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    final client = HomeserverClient(session: widget.session);
    try {
      final id = await client.createShortPost(content);

      // The 201 alone is not proof: read it back from the homeserver, which
      // is the only source that answers immediately after a write.
      final stored = await client.readPost(id);
      if (stored == null) {
        throw const WriteFailed(0, 'écrit, mais introuvable à la relecture');
      }

      if (mounted) Navigator.pop(context, (id: id, content: content));
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = e.message.toString());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      client.close();
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final length = _controller.text.trim().length;
    final tooLong = length > maxShortPostLength;
    final err = _error;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.composeTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
              ),
              const Spacer(),
              _AccessBadge(
                kind: isGrantSecret(widget.session.grantSecret)
                    ? AuthKind.grant
                    : AuthKind.cookie,
                canWrite: _canWrite,
              ),
            ],
          ),
          if (_accessError != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(message: _accessError!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _ComposeAction(
                icon: Icons.alternate_email_rounded,
                label: l.composeMention,
                onTap: _sending ? null : _pickMention,
              ),
              const SizedBox(width: 8),
              _ComposeAction(
                icon: Icons.smart_toy_outlined,
                label: l.composeAskJeb,
                onTap: _sending ? null : () => _insertMention(jebPubky),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 7,
            minLines: 4,
            enabled: !_sending,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 15.5, height: 1.5),
            decoration: InputDecoration(
              hintText: l.composeHint,
              hintStyle: const TextStyle(color: kTextMuted),
              filled: true,
              fillColor: kBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kAccent.withValues(alpha: 0.6)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                l.composeCounter(length, maxShortPostLength),
                style: TextStyle(
                  fontSize: 12,
                  color: tooLong ? kDanger : kTextMuted,
                ),
              ),
              const Spacer(),
              Text(
                l.composeTarget,
                style: const TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ],
          ),
          if (err != null) ...[
            const SizedBox(height: 14),
            ErrorPanel(message: err),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_sending || length == 0 || tooLong) ? null : _publish,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.composePublish),
          ),
          const SizedBox(height: 10),
          Text(
            l.composeNote,
            style: const TextStyle(color: kTextMuted, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// Says which authentication the session carries, and whether the homeserver
/// has already accepted it — checked before the user writes a word, so a
/// refusal never arrives after the effort of composing.
class _AccessBadge extends StatelessWidget {
  const _AccessBadge({required this.kind, required this.canWrite});

  final AuthKind kind;
  final bool? canWrite;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final (label, color) = switch (canWrite) {
      null => (l.composeAccessChecking, kTextMuted),
      true => (l.composeAccessOpen(kind.label), kAccent),
      false => (l.composeAccessDenied(kind.label), kDanger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11.5)),
    );
  }
}

class _ComposeAction extends StatelessWidget {
  const _ComposeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: kBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: onTap == null ? kTextMuted : kAccent),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: onTap == null ? kTextMuted : kText,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Search by display name, returning the chosen account key.
///
/// Nexus ranks the results and answers with keys only, so the profiles are
/// resolved in a second call — the list would otherwise show 52-character
/// strings, which nobody can pick from.
class _MentionPicker extends StatefulWidget {
  const _MentionPicker({required this.nexus});

  final NexusClient nexus;

  @override
  State<_MentionPicker> createState() => _MentionPickerState();
}

class _MentionPickerState extends State<_MentionPicker> {
  final _query = TextEditingController();
  List<PubkyProfile> _results = const [];
  bool _searching = false;
  int _generation = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String prefix) async {
    // Every keystroke starts a search; only the latest may paint. Otherwise a
    // slow early request lands after a fast later one and shows stale names.
    final generation = ++_generation;
    if (prefix.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final found = await widget.nexus.searchUsersByName(prefix);
      if (!mounted || generation != _generation) return;
      setState(() => _results = found);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _results = const []);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.composeMention,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            autofocus: true,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: l.composeMentionSearch,
              hintStyle: const TextStyle(color: kTextMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: kTextMuted),
              filled: true,
              fillColor: kBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_results.isEmpty && _query.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l.composeMentionNoResult,
                  style: const TextStyle(color: kTextMuted),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final profile = _results[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipOval(
                      child: Image.network(
                        profile.avatarUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person_rounded, color: kTextMuted),
                      ),
                    ),
                    title: Text(
                      profile.name.isEmpty ? l.profileNoName : profile.name,
                      style: const TextStyle(fontSize: 15),
                    ),
                    subtitle: Text(
                      profile.id.substring(0, 8) + String.fromCharCode(0x2026),
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 11.5,
                        fontFamily: "monospace",
                      ),
                    ),
                    onTap: () => Navigator.pop(context, profile.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
