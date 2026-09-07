import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pubky/ring_session.dart';
import '../theme.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({
    super.key,
    required this.busy,
    required this.error,
    required this.awaitingProfile,
    required this.outbound,
    required this.inbound,
    required this.onConnect,
    this.onRetry,
  });

  final bool busy;
  final String? error;

  /// Ring already handed a session back; we are fetching the profile.
  final bool awaitingProfile;

  /// Last link sent to Ring, and every link received back.
  final Uri? outbound;
  final List<Uri> inbound;

  final void Function(SessionUrlVariant) onConnect;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final err = error;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kAccent.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.key_rounded, color: kAccent, size: 32),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Flutky',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Preuve de concept : se connecter avec son compte Pubky '
                    'via Pubky Ring, puis afficher son profil.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kTextMuted, height: 1.5, fontSize: 15),
                  ),
                  const SizedBox(height: 30),
                  if (busy || awaitingProfile) ...[
                    Panel(
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              busy
                                  ? 'Lecture du profil chez Nexus…'
                                  : 'Session reçue. Chargement…',
                              style: const TextStyle(color: kTextMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: () => onConnect(SessionUrlVariant.plain),
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      label: const Text('Se connecter avec Pubky Ring'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => onConnect(SessionUrlVariant.trailingSlash),
                      child: const Text(
                        "Essayer l'autre format de lien (session/)",
                        style: TextStyle(color: kTextMuted, fontSize: 13),
                      ),
                    ),
                  ],
                  if (err != null) ...[
                    const SizedBox(height: 8),
                    ErrorPanel(message: err),
                    if (onRetry != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: busy ? null : onRetry,
                        child: const Text('Réessayer la lecture du profil'),
                      ),
                    ],
                  ],
                  if (outbound != null || inbound.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _Exchange(outbound: outbound, inbound: inbound),
                  ],
                  const SizedBox(height: 22),
                  const _HowItWorks(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows both halves of the deep-link exchange verbatim. On a phone this is
/// the only way to see what Ring actually replied — a screenshot of it is
/// worth more than any guess about which handler ran.
class _Exchange extends StatelessWidget {
  const _Exchange({required this.outbound, required this.inbound});

  final Uri? outbound;
  final List<Uri> inbound;

  @override
  Widget build(BuildContext context) {
    final all = StringBuffer();
    if (outbound != null) all.writeln('ENVOYÉ : $outbound');
    for (var i = 0; i < inbound.length; i++) {
      all.writeln('REÇU ${i + 1} : ${inbound[i]}');
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ÉCHANGE AVEC RING',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: all.toString()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Échange copié')),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded, size: 17, color: kTextMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (outbound != null) _Line(tag: 'ENVOYÉ', value: '$outbound'),
          if (inbound.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Rien reçu de Ring pour l’instant.',
                style: TextStyle(color: kTextMuted, fontSize: 12.5),
              ),
            )
          else
            for (var i = 0; i < inbound.length; i++)
              _Line(
                tag: inbound.length == 1 ? 'REÇU' : 'REÇU ${i + 1}',
                value: '${inbound[i]}',
                highlight: true,
              ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.tag, required this.value, this.highlight = false});

  final String tag;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tag,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: highlight ? kAccent : kTextMuted,
              ),
            ),
            const SizedBox(height: 3),
            SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.45,
                color: kText,
              ),
            ),
          ],
        ),
      );
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ce qui va se passer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            const _Step(1, 'Flutky ouvre Pubky Ring par un lien '
                'pubkyring://session.'),
            const _Step(2, 'Ring demande quel pubky utiliser, puis affiche un '
                "écran d'approbation."),
            const _Step(3, 'Ring rouvre Flutky en lui passant la clé publique '
                'et un secret de session.'),
            const _Step(4, 'Flutky lit le profil chez Nexus, sans '
                'authentification.'),
            const SizedBox(height: 14),
            const Text(
              'Le secret de session reste en mémoire, il n’est ni affiché '
              'ni enregistré.',
              style: TextStyle(color: kTextMuted, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.text);

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1, right: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '$n',
                style: const TextStyle(
                  color: kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: kTextMuted, fontSize: 14, height: 1.45),
              ),
            ),
          ],
        ),
      );
}
