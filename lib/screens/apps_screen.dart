import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';
import 'eventky_screen.dart';
import 'mypubky_screen.dart';

/// Other Pubky applications, seen from inside Flutky.
///
/// Not a launcher. Opening someone else's web app in a browser would carry
/// nothing across — it runs on its own origin and would start its own sign-in,
/// and Flutky could not hand over its session anyway: the grant is bound to a
/// client key that never leaves the device.
///
/// So these are **native views onto other apps' namespaces**. `/pub/` is
/// world-readable, which means reading costs no permission at all. Writing
/// would need the grant widened to that app's folder — Ring shows each folder
/// on its own line — and that is asked for when it is needed, not at sign-in.
class AppsScreen extends StatelessWidget {
  const AppsScreen({
    super.key,
    required this.session,
    required this.onSessionChanged,
  });

  final RingSession session;

  /// A widened grant, when one of these screens asks for it. It has to travel
  /// back to the top: a credential kept where it was obtained would be lost
  /// on the way back out of the screen.
  final void Function(RingSession) onSessionChanged;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          l.appsIntro,
          style: const TextStyle(color: kTextMuted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        _AppTile(
          icon: Icons.event_rounded,
          name: 'Eventky',
          summary: l.appsEventkySummary,
          namespace: '/pub/eventky.app/',
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EventkyScreen(session: session),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _AppTile(
          icon: Icons.badge_outlined,
          name: 'mypubky',
          summary: l.appsMypubkySummary,
          namespace: '/pub/mypubky.com/',
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MypubkyScreen(
                session: session,
                onSessionChanged: onSessionChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_open_rounded, size: 16, color: kAccent),
                  const SizedBox(width: 9),
                  Text(
                    l.appsReadOnlyTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l.appsReadOnlyBody,
                style: const TextStyle(
                    color: kTextMuted, fontSize: 12.5, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.icon,
    required this.name,
    required this.summary,
    required this.namespace,
    required this.onOpen,
  });

  final IconData icon;
  final String name;
  final String summary;
  final String namespace;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Panel(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kAccent, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(summary,
                        style: const TextStyle(
                            color: kTextMuted, fontSize: 12.5, height: 1.35)),
                    const SizedBox(height: 5),
                    Text(
                      namespace,
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kTextMuted),
            ],
          ),
        ),
      );
}
