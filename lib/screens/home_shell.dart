import 'package:flutter/material.dart';

import '../pubky/nexus.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';
import 'feed_screen.dart';
import 'profile_screen.dart';

/// Chrome around the two tabs once a session exists.
///
/// The feed keeps its scroll position and loaded pages while the profile tab
/// is showing — hence IndexedStack rather than swapping the body.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.nexus,
    required this.session,
    required this.profile,
    required this.profileError,
    required this.onRefreshProfile,
    required this.onDisconnect,
  });

  final NexusClient nexus;
  final RingSession session;
  final PubkyProfile profile;
  final String? profileError;
  final Future<void> Function() onRefreshProfile;
  final VoidCallback onDisconnect;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _titles = ['Flux', 'Mon profil Pubky'];

  Future<void> _confirmDisconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'La session enregistrée sera effacée de ce téléphone. Il faudra '
          'repasser par Pubky Ring pour revenir.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter', style: TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
    if (ok ?? false) widget.onDisconnect();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: kBackground,
          title: Text(_titles[_tab]),
          actions: [
            IconButton(
              onPressed: _confirmDisconnect,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Se déconnecter',
            ),
          ],
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _tab,
            children: [
              FeedScreen(
                nexus: widget.nexus,
                observerId: widget.session.pubky,
              ),
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dynamic_feed_outlined),
              selectedIcon: Icon(Icons.dynamic_feed_rounded, color: kAccent),
              label: 'Flux',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: kAccent),
              label: 'Profil',
            ),
          ],
        ),
      );
}
