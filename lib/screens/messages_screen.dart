import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// Placeholder for private messaging.
///
/// The tab is present but inert, on purpose: it says what the feature will
/// rest on and why it is not there, rather than pretending it does not exist.
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  static const _repository = 'https://github.com/pubky/pubky-noise';

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 28),
      children: [
        const Icon(Icons.lock_outline_rounded, size: 40, color: kTextMuted),
        const SizedBox(height: 20),
        Text(
          l.messagesWipTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l.messagesWipBody,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kTextMuted, height: 1.55, fontSize: 14),
        ),
        const SizedBox(height: 22),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(_repository),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: Text(l.messagesWipFollow),
          ),
        ),
      ],
    );
  }
}
