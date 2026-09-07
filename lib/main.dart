import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'pubky/nexus.dart';
import 'pubky/ring_session.dart';
import 'pubky/session_store.dart';
import 'screens/connect_screen.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

void main() => runApp(const FlutkyApp());

class FlutkyApp extends StatelessWidget {
  const FlutkyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Flutky',
        debugShowCheckedModeBanner: false,
        theme: flutkyTheme,
        home: const SessionGate(),
      );
}

/// Holds the whole state machine: restoring a stored session, waiting for
/// Ring, loading the profile, showing the app, or reporting what went wrong.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final _appLinks = AppLinks();
  final _nexus = NexusClient();
  final _store = SessionStore();
  StreamSubscription<Uri>? _linkSub;

  /// Guards against handling the same callback twice: depending on whether the
  /// process was alive when Ring re-opened us, the link can arrive through the
  /// stream, through getInitialLink(), or both.
  String? _handledUri;

  /// Every inbound link, in order — including the ones we could not use. This
  /// is the only way to see what Ring actually sends back from a phone.
  final _inbound = <Uri>[];

  /// The outgoing link of the last attempt, shown next to the inbound one so
  /// both halves of the exchange can be compared.
  Uri? _lastOutbound;

  RingSession? _session;
  PubkyProfile? _profile;
  String? _error;
  bool _busy = false;

  /// True until the keystore has been consulted — without it the connect
  /// screen would flash before a stored session restores.
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _linkSub = _appLinks.uriLinkStream.listen(_onLink, onError: (Object e) {
      if (mounted) setState(() => _error = 'Lien entrant illisible : $e');
    });
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _nexus.close();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final stored = await _store.read();
    if (stored != null && mounted) {
      setState(() => _session = stored);
      await _loadProfile(stored.pubky);
    }
    if (mounted) setState(() => _restoring = false);

    // A cold start triggered by Ring carries its link here rather than on the
    // stream; handled after the restore so a fresh session wins over the old.
    final uri = await _appLinks.getInitialLink();
    if (uri != null) _onLink(uri);
  }

  void _onLink(Uri uri) {
    if (uri.toString() == _handledUri) return;
    _handledUri = uri.toString();

    final callback = RingCallback.tryParse(uri);
    // Record even the links we cannot use — an unrecognised one is a finding.
    setState(() => _inbound.add(uri));
    if (callback == null) return;

    switch (callback) {
      case RingApproved(:final session):
        setState(() {
          _session = session;
          _error = null;
        });
        unawaited(_store.save(session));
        unawaited(_loadProfile(session.pubky));
      case RingCancelled():
        setState(() => _error = 'Connexion annulée dans Pubky Ring.');
      case RingFailed(:final code, :final message):
        setState(() => _error = 'Ring a refusé ($code) : $message');
      case RingEmpty():
        setState(() => _error =
            'Ring est bien revenu vers Flutky, mais sans clé publique ni '
            "secret de session. C'est la signature d'un lien traité par un "
            'autre chemin que celui de la session. Le détail complet est '
            'ci-dessous.');
    }
  }

  Future<void> _loadProfile(String pubky) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await _nexus.fetchProfile(pubky);
      if (mounted) setState(() => _profile = profile);
    } on ProfileNotIndexed {
      if (mounted) {
        setState(() => _error =
            "Nexus ne connaît pas encore cette clé. L'indexeur n'apprend "
            "l'existence d'un compte qu'une fois relié au graphe social : "
            "publie un message ou suis quelqu'un depuis pubky.app, puis "
            'réessaie.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(SessionUrlVariant variant) async {
    setState(() {
      _error = null;
      _lastOutbound = buildSessionUrl(variant);
    });
    try {
      await requestSession(variant);
    } on RingNotReachable {
      setState(() => _error =
          "Aucune application n'a répondu. Pubky Ring est-il installé "
          'sur ce téléphone ?');
    } catch (e) {
      setState(() => _error = "Impossible d'ouvrir Pubky Ring : $e");
    }
  }

  void _disconnect() {
    unawaited(_store.clear());
    setState(() {
      _session = null;
      _profile = null;
      _error = null;
      _handledUri = null;
      _inbound.clear();
      _lastOutbound = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final session = _session;
    final profile = _profile;

    if (session != null && profile != null) {
      return HomeShell(
        nexus: _nexus,
        session: session,
        profile: profile,
        profileError: _error,
        onRefreshProfile: () => _loadProfile(session.pubky),
        onDisconnect: _disconnect,
      );
    }

    return ConnectScreen(
      busy: _busy,
      error: _error,
      awaitingProfile: session != null,
      outbound: _lastOutbound,
      inbound: _inbound,
      onConnect: _connect,
      onRetry: session == null ? null : () => _loadProfile(session.pubky),
    );
  }
}
