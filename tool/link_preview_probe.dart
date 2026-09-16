// Probe: what a preview actually looks like, against the live web.
//
//   dart run tool/link_preview_probe.dart [url ...]
//
// Prints the fields and the number of bytes the fetch cost, because the whole
// design of the client is a size trade-off and a regression there would be
// invisible otherwise.
import 'dart:io';

import 'package:flutky/pubky/link_preview.dart';

const _defaults = [
  'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  'https://youtu.be/dQw4w9WgXcQ',
  'https://x.com/elonmusk/status/1585841080431321088',
  'https://github.com/PastaGringo/flutky',
  'https://www.lemonde.fr',
  'https://pubky.app',
  'https://example.invalid/nope',
];

Future<void> main(List<String> args) async {
  final urls = args.isEmpty ? _defaults : args;
  final client = LinkPreviewClient();
  for (final url in urls) {
    final started = DateTime.now();
    final preview = await client.fetch(url);
    final ms = DateTime.now().difference(started).inMilliseconds;
    stdout.writeln('=== $url  (${ms}ms)');
    if (preview == null) {
      stdout.writeln('    aucune preview');
      continue;
    }
    stdout.writeln('    site  : ${preview.siteName ?? preview.host}');
    stdout.writeln('    titre : ${preview.title}');
    stdout.writeln('    desc  : ${preview.description ?? '—'}');
    stdout.writeln('    image : ${preview.imageUrl ?? '—'}');
  }
  client.close();
}
