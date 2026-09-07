import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../pubky/nexus.dart';
import '../theme.dart';
import 'profile_sheet.dart';

/// Notifications, read from `GET /v0/user/{id}/notifications`.
///
/// Nexus reports twelve kinds; each is phrased in the user's language rather
/// than shown as a raw type. A kind we do not know about is displayed as such
/// instead of being dropped — Nexus can add one at any time, and silently
/// hiding it would look like nothing ever happened.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.nexus,
    required this.pubky,
  });

  final NexusClient nexus;
  final String pubky;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<PubkyNotification>? _items;
  Map<String, PubkyProfile> _actors = const {};
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.nexus.fetchNotifications(pubky: widget.pubky);

      // Resolve the people involved in one batch, so each line can show a name
      // instead of a 52-character key.
      final keys = items
          .map((n) => n.actor)
          .whereType<String>()
          .where((k) => k.length == 52)
          .toSet();
      Map<String, PubkyProfile> actors = const {};
      if (keys.isNotEmpty) {
        try {
          actors = await widget.nexus.fetchUsersByIds(keys);
        } catch (_) {
          actors = const {};
        }
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _actors = actors;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final items = _items;

    if (items == null && _loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_error != null) ...[
            ErrorPanel(message: _error!),
            const SizedBox(height: 14),
          ],
          if (items != null && items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
              child: Column(
                children: [
                  const Icon(Icons.notifications_none_rounded,
                      size: 40, color: kTextMuted),
                  const SizedBox(height: 16),
                  Text(
                    l.notifEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kTextMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          for (final item in items ?? const <PubkyNotification>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NotificationTile(
                item: item,
                actor: item.actor == null ? null : _actors[item.actor],
                nexus: widget.nexus,
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.actor,
    required this.nexus,
  });

  final PubkyNotification item;
  final PubkyProfile? actor;
  final NexusClient nexus;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final who = _who(l);
    final key = item.actor;

    return Panel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (key != null && key.length == 52)
            InkWell(
              onTap: () => showProfileSheet(
                context,
                nexus: nexus,
                pubky: key,
                known: actor,
              ),
              borderRadius: BorderRadius.circular(999),
              child: ClipOval(
                child: Image.network(
                  '$nexusBase/static/avatar/$key',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallbackAvatar(who),
                ),
              ),
            )
          else
            Icon(_icon, size: 20, color: kAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(l, who),
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 3),
                Text(
                  _relative(l, item.timestamp),
                  style: const TextStyle(color: kTextMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Icon(_icon, size: 16, color: kTextMuted),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(String who) => Container(
        width: 32,
        height: 32,
        color: kBackground,
        alignment: Alignment.center,
        child: Text(
          who.characters.first.toUpperCase(),
          style: const TextStyle(color: kAccent, fontWeight: FontWeight.w700),
        ),
      );

  String _who(L10n l) {
    final name = actor?.name;
    if (name != null && name.isNotEmpty) return name;
    final key = item.actor;
    if (key == null || key.length < 12) return l.notifSomeone;
    return '${key.substring(0, 6)}…${key.substring(key.length - 4)}';
  }

  String _text(L10n l, String who) => switch (item.kind) {
        NotificationKind.follow => l.notifFollow(who),
        NotificationKind.newFriend => l.notifNewFriend(who),
        NotificationKind.lostFriend => l.notifLostFriend(who),
        NotificationKind.tagPost => l.notifTagPost(who, item.label ?? ''),
        NotificationKind.tagProfile => l.notifTagProfile(who, item.label ?? ''),
        NotificationKind.untagPost => l.notifUntagPost(who, item.label ?? ''),
        NotificationKind.untagProfile =>
          l.notifUntagProfile(who, item.label ?? ''),
        NotificationKind.reply => l.notifReply(who),
        NotificationKind.repost => l.notifRepost(who),
        NotificationKind.mention => l.notifMention(who),
        NotificationKind.postDeleted => l.notifPostDeleted(who),
        NotificationKind.postEdited => l.notifPostEdited(who),
        NotificationKind.unknown => l.notifUnknown(item.rawKind),
      };

  IconData get _icon => switch (item.kind) {
        NotificationKind.follow ||
        NotificationKind.newFriend =>
          Icons.person_add_alt_1_rounded,
        NotificationKind.lostFriend => Icons.person_remove_alt_1_rounded,
        NotificationKind.tagPost ||
        NotificationKind.tagProfile =>
          Icons.sell_rounded,
        NotificationKind.untagPost ||
        NotificationKind.untagProfile =>
          Icons.sell_outlined,
        NotificationKind.reply => Icons.mode_comment_rounded,
        NotificationKind.repost => Icons.repeat_rounded,
        NotificationKind.mention => Icons.alternate_email_rounded,
        NotificationKind.postDeleted => Icons.delete_outline_rounded,
        NotificationKind.postEdited => Icons.edit_outlined,
        NotificationKind.unknown => Icons.help_outline_rounded,
      };

  static String _relative(L10n l, DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return l.timeJustNow;
    if (diff.inMinutes < 60) return l.timeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l.timeHours(diff.inHours);
    if (diff.inDays < 30) return l.timeDays(diff.inDays);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
