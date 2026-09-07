import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// A picture, full screen and zoomable.
///
/// The card shows the `feed` variant — 7 kB of WebP, sized for a thumbnail.
/// Opening it loads `main` instead (149 kB of JPEG measured), because a
/// thumbnail blown up to fill a phone screen is a blurred thumbnail, not a
/// picture.
Future<void> showImageViewer(
  BuildContext context, {
  required List<String> urls,
  int initial = 0,
}) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _ImageViewer(urls: urls, initial: initial),
      ),
    );

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.urls, required this.initial});

  final List<String> urls;
  final int initial;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// The card asks Nexus for the `feed` variant; this asks for `main`. Only
  /// three variants exist — `main`, `feed` and `small` — and anything else
  /// answers 400, so the swap is a substitution rather than a guess.
  String _full(String url) =>
      url.endsWith('/feed') ? '${url.substring(0, url.length - 5)}/main' : url;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  _full(widget.urls[i]),
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                  // Falling back to the thumbnail rather than to an error
                  // icon: a blurred picture beats no picture, and the full
                  // size can simply not have been generated yet.
                  errorBuilder: (_, _, _) => Image.network(
                    widget.urls[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: kTextMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              color: Colors.white,
              tooltip: l.actionClose,
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
