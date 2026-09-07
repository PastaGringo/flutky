import 'package:flutter/material.dart';

import '../pubky/grant_auth.dart';
import '../pubky/homeserver.dart';
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
Future<PublishedPost?> showComposeSheet(
  BuildContext context, {
  required RingSession session,
}) =>
    showModalBottomSheet<PublishedPost>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ComposeSheet(session: session),
    );

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.session});

  final RingSession session;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _controller = TextEditingController();
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
                'Nouveau post',
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
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 7,
            minLines: 4,
            enabled: !_sending,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 15.5, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Quoi de neuf ?',
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
                '$length / $maxShortPostLength',
                style: TextStyle(
                  fontSize: 12,
                  color: tooLong ? kDanger : kTextMuted,
                ),
              ),
              const Spacer(),
              const Text(
                'Publié sur ton homeserver',
                style: TextStyle(fontSize: 12, color: kTextMuted),
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
                : const Text('Publier'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Le post part sur le homeserver tout de suite. Son apparition dans '
            "le flux dépend de l'indexeur, qui a toujours un peu de retard.",
            style: TextStyle(color: kTextMuted, fontSize: 12, height: 1.45),
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
    final (label, color) = switch (canWrite) {
      null => ('vérification…', kTextMuted),
      true => ('${kind.label} · écriture ouverte', kAccent),
      false => ('${kind.label} · écriture refusée', kDanger),
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
