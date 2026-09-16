import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pubky/link_preview.dart';
import '../theme.dart';

/// The card a link turns into, under the post that carries it.
///
/// Nothing is drawn while the lookup is in flight, and nothing is drawn if it
/// comes back empty: a placeholder that may never fill in is worse than the
/// link on its own, which is still right there in the text above.
class LinkPreviewCard extends StatefulWidget {
  const LinkPreviewCard({super.key, required this.url});

  final String url;

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  static final _client = LinkPreviewClient();

  LinkPreview? _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LinkPreviewCard old) {
    super.didUpdateWidget(old);
    // A recycled list row can be handed a different post entirely.
    if (old.url != widget.url) {
      setState(() => _preview = null);
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.url;
    final found = await _client.fetch(url);
    // The row may have been reused for another link while this was in flight.
    if (mounted && url == widget.url) setState(() => _preview = found);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    if (preview == null) return const SizedBox.shrink();

    final image = preview.imageUrl;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () => launchUrl(
          Uri.parse(preview.url),
          mode: LaunchMode.externalApplication,
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null)
                AspectRatio(
                  aspectRatio: preview.imageAspect,
                  child: Image.network(
                    image,
                    fit: BoxFit.cover,
                    // A thumbnail that 404s must not leave a grey box where a
                    // picture was promised.
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const ColoredBox(color: kSurface),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.siteName ?? preview.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 11.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      preview.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (preview.description case final text?
                        when text.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
