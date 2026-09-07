import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../main.dart' show LocalizedError;
import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../settings/feed_preferences.dart';
import '../settings/locale_controller.dart';
import '../theme.dart';
import 'diagnostics_screen.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Chrome around the tabs once a session exists.
///
/// The feed keeps its scroll position and loaded pages while another tab is
/// showing — hence IndexedStack rather than swapping the body.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.nexus,
    required this.session,
    required this.profile,
    required this.profileError,
    required this.locales,
    required this.preferences,
    required this.onRefreshProfile,
    required this.onDisconnect,
  });

  final NexusClient nexus;
  final RingSession session;
  final PubkyProfile profile;
  final LocalizedError? profileError;
  final LocaleController locales;
  final FeedPreferences preferences;
  final Future<void> Function() onRefreshProfile;
  final VoidCallback onDisconnect;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  Future<void> _confirmDisconnect() async {
    final l = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface,
        title: Text(l.signOutTitle),
        content: Text(l.signOutBody, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.actionSignOut, style: const TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
    if (ok ?? false) widget.onDisconnect();
  }

  /// Opens the issue form with its template already selected. GitHub reads the
  /// `template` parameter, so the person lands on a filled form rather than on
  /// an empty box — which is what makes a report usable.
  /// Notifications are a place you go to, not a place you live in — so they
  /// are a route rather than a tab. Pushing one also drops the badge problem:
  /// a tab you can see is a tab that has to say whether it has anything new.
  void _openNotifications() {
    final l = L10n.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: kBackground,
            title: Text(l.titleNotifications),
          ),
          body: SafeArea(
            child: NotificationsScreen(
              nexus: widget.nexus,
              pubky: widget.session.pubky,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openIssue(String template) => launchUrl(
        Uri.parse('$repositoryUrl/issues/new?template=$template'),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final titles = [
      l.titleFeed,
      l.titleDiscover,
      l.titleMessages,
      l.titleProfile,
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackground,
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: l.titleNotifications,
          ),
          IconButton(
            onPressed: () => _openIssue('bug_report.yml'),
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: l.actionReportBug,
          ),
          IconButton(
            onPressed: () => _openIssue('feature_request.yml'),
            icon: const Icon(Icons.lightbulb_outline_rounded),
            tooltip: l.actionRequestFeature,
          ),
          PopupMenuButton<String>(
            color: kSurface,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'diagnostics':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DiagnosticsScreen(session: widget.session),
                    ),
                  );
                case 'settings':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(
                        locales: widget.locales,
                        preferences: widget.preferences,
                      ),
                    ),
                  );
                case 'signout':
                  _confirmDisconnect();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'diagnostics',
                child: _MenuRow(Icons.biotech_rounded, l.actionDiagnostics),
              ),
              PopupMenuItem(
                value: 'settings',
                child: _MenuRow(Icons.settings_rounded, l.actionSettings),
              ),
              PopupMenuItem(
                value: 'signout',
                child: _MenuRow(Icons.logout_rounded, l.actionSignOut,
                    color: kDanger),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            FeedScreen(
              nexus: widget.nexus,
              session: widget.session,
              preferences: widget.preferences,
            ),
            DiscoverScreen(
              nexus: widget.nexus,
              session: widget.session,
            ),
            const MessagesScreen(),
            ProfileScreen(
              session: widget.session,
              profile: widget.profile,
              error: widget.profileError,
              onRefresh: widget.onRefreshProfile,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: kSurface,
        indicatorColor: kAccent.withValues(alpha: 0.16),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dynamic_feed_outlined),
            selectedIcon: const Icon(Icons.dynamic_feed_rounded, color: kAccent),
            label: l.tabFeed,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore_rounded, color: kAccent),
            label: l.tabDiscover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum_rounded, color: kAccent),
            // Named WIP rather than greyed out: a disabled tab invites tapping
            // to find out why, and answers nothing.
            label: '${l.tabMessages} (WIP)',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded, color: kAccent),
            label: l.tabProfile,
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: color ?? kTextMuted),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color ?? kText, fontSize: 14)),
        ],
      );
}
