import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../pubky/endpoints.dart';
import '../pubky/grant_flow.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';

/// Asks Ring for a grant covering more than the one already held.
///
/// A grant's capabilities are fixed when it is issued: there is no endpoint
/// that widens one in place. So this is a fresh authorization, approved in
/// Ring like the first — which is why it is asked for at the moment writing
/// is actually wanted, and not piled onto the sign-in screen for features
/// most readers will never use.
///
/// Returns the new session, or null when it was refused, cancelled, or
/// approved under a different key.
Future<RingSession?> requestWiderGrant(
  BuildContext context, {
  required RingSession current,
  required List<String> extraCapabilities,
  required String reason,
}) async {
  final l = L10n.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final wanted = <String>{...current.capabilities, ...extraCapabilities};

  final go = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: kSurface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.grantWidenTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(reason,
              style: const TextStyle(color: kTextMuted, height: 1.5)),
          const SizedBox(height: 14),
          for (final cap in wanted)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    extraCapabilities.contains(cap)
                        ? Icons.add_circle_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 15,
                    color: extraCapabilities.contains(cap)
                        ? kAccent
                        : kTextMuted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      cap,
                      style: const TextStyle(
                          fontSize: 12.5, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Text(
            l.grantWidenNote,
            style: const TextStyle(
                color: kTextMuted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.grantWidenOpenRing),
            ),
          ),
        ],
      ),
    ),
  );
  if (go != true || !context.mounted) return null;

  final flow = await GrantAuthFlow.begin(capabilities: wanted.join(','));
  try {
    await openInRing(flow.authorizationUrl);
    final result = await flow.completeAndPack(homeserverPublicKey);
    // Approving under another pubky would quietly swap the account under a
    // screen that still says it is editing this one. Refused rather than
    // accepted: the mistake is easy to make with several keys in Ring.
    if (result.pubky != current.pubky) {
      messenger.showSnackBar(SnackBar(content: Text(l.grantWidenWrongKey)));
      return null;
    }
    return RingSession(
      pubky: result.pubky,
      grantSecret: result.credential,
      capabilities: wanted.toList(),
    );
  } on RingNotReachable {
    messenger.showSnackBar(SnackBar(content: Text(l.errorRingUnreachable)));
  } on GrantFlowError catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(e.timedOut ? l.errorGrantUnsupported : '$e'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  } finally {
    flow.close();
  }
  return null;
}
