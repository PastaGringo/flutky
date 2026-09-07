import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pubky/mentions.dart';
import '../pubky/nexus.dart';
import '../theme.dart';
import 'profile_sheet.dart';

/// Renders post content with mentions and links picked out.
///
/// A mention shows the person's display name when we have it, and falls back
/// to a shortened key otherwise — never the raw 57-character blob.
class PostContent extends StatelessWidget {
  const PostContent({
    super.key,
    required this.content,
    required this.nexus,
    required this.knownProfiles,
  });

  final String content;
  final NexusClient nexus;

  /// Profiles already loaded by the feed, so a mention renders without waiting
  /// on its own request.
  final Map<String, PubkyProfile> knownProfiles;

  @override
  Widget build(BuildContext context) {
    final spans = parseContent(content);
    if (spans.isEmpty) return const SizedBox.shrink();

    // Recognisers are created per build and disposed with the render object;
    // Text.rich handles that for us as long as we do not cache them.
    return Text.rich(
      TextSpan(
        children: [
          for (final span in spans)
            switch (span) {
              TextSpanPart(:final text) => TextSpan(text: text),
              MentionSpan(:final pubky) => TextSpan(
                  text: '@${_label(pubky)}',
                  style: const TextStyle(
                    color: kAccent,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => showProfileSheet(
                          context,
                          nexus: nexus,
                          pubky: pubky,
                          known: knownProfiles[pubky],
                        ),
                ),
              LinkSpan(:final url) => TextSpan(
                  text: url,
                  style: const TextStyle(
                    color: kAccent,
                    decoration: TextDecoration.underline,
                    decorationColor: kAccent,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        ),
                ),
            },
        ],
      ),
      style: const TextStyle(height: 1.5, fontSize: 14.5, color: kText),
    );
  }

  String _label(String pubky) {
    final name = knownProfiles[pubky]?.name;
    if (name != null && name.isNotEmpty && name != 'Sans nom') return name;
    return '${pubky.substring(0, 6)}…${pubky.substring(pubky.length - 4)}';
  }
}
