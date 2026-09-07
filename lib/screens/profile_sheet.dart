import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';

import '../pubky/homeserver.dart';
import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';

/// Opens the profile of a mentioned account.
///
/// Takes whatever the feed already knows so the sheet paints immediately, then
/// refreshes in the background — a mention should not cost a spinner when the
/// author is already on screen.
Future<void> showProfileSheet(
  BuildContext context, {
  required NexusClient nexus,
  required String pubky,
  PubkyProfile? known,
  /// When given — and when the profile is not the user's own — the sheet
  /// offers to follow or unfollow.
  RingSession? session,
}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProfileSheet(
        nexus: nexus,
        pubky: pubky,
        known: known,
        session: session,
      ),
    );

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({
    required this.nexus,
    required this.pubky,
    this.known,
    this.session,
  });

  final NexusClient nexus;
  final String pubky;
  final PubkyProfile? known;
  final RingSession? session;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  PubkyProfile? _profile;
  String? _error;

  /// null while unknown, then the state we believe the server is in.
  bool? _following;
  bool _updatingFollow = false;

  bool get _isSelf => widget.session?.pubky == widget.pubky;

  Future<void> _toggleFollow() async {
    final session = widget.session;
    if (session == null || _updatingFollow) return;

    final target = !(_following ?? false);
    setState(() {
      _updatingFollow = true;
      // Optimistic: the button answers now, and reverts if the server refuses.
      _following = target;
    });

    final client = HomeserverClient(session: session);
    try {
      if (target) {
        await client.follow(widget.pubky);
      } else {
        await client.unfollow(widget.pubky);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _following = !target;
          _error = L10n.of(context).followFailed('$e');
        });
      }
    } finally {
      client.close();
      if (mounted) setState(() => _updatingFollow = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _profile = widget.known;
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.nexus.fetchProfile(widget.pubky, viewerId: widget.session?.pubky);
      if (mounted) {
        setState(() {
          _profile = profile;
          _following ??= profile.followedByViewer;
        });
      }
    } on ProfileNotIndexed {
      if (mounted && _profile == null) {
        setState(() => _error =
            L10n.of(context).errorNotIndexed);
      }
    } catch (e) {
      if (mounted && _profile == null) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final err = _error;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile == null && err == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ErrorPanel(message: err),
            )
          else
            ..._body(context, profile!),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, PubkyProfile profile) => [
        Row(
          children: [
            ClipOval(
              child: Image.network(
                profile.avatarUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 56,
                  height: 56,
                  color: kBackground,
                  alignment: Alignment.center,
                  child: Text(
                    (profile.name.isEmpty ? '?' : profile.name)
                        .characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: kAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name.isEmpty
                        ? L10n.of(context).profileNoName
                        : profile.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (profile.status != null)
                    Text(
                      profile.status!,
                      style: const TextStyle(color: kTextMuted, fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (widget.session != null && !_isSelf) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: (_following ?? false)
                ? OutlinedButton(
                    onPressed: _updatingFollow ? null : _toggleFollow,
                    child: Text(L10n.of(context).actionUnfollow),
                  )
                : FilledButton(
                    onPressed: _updatingFollow ? null : _toggleFollow,
                    child: Text(L10n.of(context).actionFollow),
                  ),
          ),
        ],
        if (profile.bio != null) ...[
          const SizedBox(height: 16),
          Text(
            profile.bio!,
            style: const TextStyle(height: 1.5, fontSize: 14.5),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in {
              'posts': L10n.of(context).countPosts,
              'followers': L10n.of(context).countFollowers,
              'following': L10n.of(context).countFollowing,
              'tagged': L10n.of(context).countTagged,
            }.entries)
              if (profile.counts.containsKey(entry.key))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kBorder),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${profile.counts[entry.key]}',
                          style: const TextStyle(
                            color: kAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ' ${entry.value.toLowerCase()}',
                          style: const TextStyle(color: kTextMuted),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: profile.id));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(L10n.of(context).profileKeyCopied)),
              );
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.key_rounded, size: 15, color: kTextMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profile.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: kTextMuted,
                    ),
                  ),
                ),
                const Icon(Icons.copy_rounded, size: 15, color: kTextMuted),
              ],
            ),
          ),
        ),
      ];
}
