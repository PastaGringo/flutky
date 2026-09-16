/// Exercises the grant handshake against a real Pubky Ring, without the app.
///
/// The point is to prove the protocol before any screen is written. If this
/// fails, a login screen built on top would fail for reasons impossible to
/// tell apart from a UI bug — so the handshake gets measured on its own first.
///
/// Run it, then hand the printed link to Ring:
///
/// ```
/// dart run tool/grant_probe.dart
/// adb shell am start -a android.intent.action.VIEW -d "<the link>"
/// ```
///
/// It then polls the relay and prints what came back. Nothing here writes to
/// a homeserver: it stops at the grant, which is exactly the step that has
/// never been proven.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutky/pubky/grant_flow.dart';
import 'package:flutky/pubky/z32.dart';

Future<void> main(List<String> args) async {
  final flow = await GrantAuthFlow.begin();

  stdout
    ..writeln('--- demande d\'autorisation -----------------------------------')
    ..writeln('client id  : ${flow.clientId}')
    ..writeln('capacités  : ${flow.capabilities}')
    ..writeln('clé client : ${z32Encode(flow.clientPublicKey)}')
    ..writeln('canal      : ${flow.channelId}')
    ..writeln('url canal  : ${flow.channelUrl}')
    ..writeln()
    ..writeln('lien à ouvrir dans Ring :')
    ..writeln(flow.authorizationUrl.toString())
    ..writeln()
    ..writeln('--- attente de l\'approbation ---------------------------------');

  try {
    final jws = await flow.awaitGrant(
      timeout: Duration(seconds: int.tryParse(args.firstOrNull ?? '') ?? 180),
    );

    stdout
      ..writeln('GRANT REÇU — ${jws.length} caractères')
      ..writeln();

    // A JWS is three base64url segments. Decoding the first two shows what the
    // signer actually granted, which is the whole point of the measurement.
    final parts = jws.split('.');
    stdout.writeln('segments : ${parts.length}');
    for (var i = 0; i < parts.length && i < 2; i++) {
      stdout.writeln(
        '  [$i] ${utf8.decode(base64Url.decode(_pad(parts[i])))}',
      );
    }
    exitCode = 0;
  } catch (e) {
    stdout.writeln('ÉCHEC : $e');
    exitCode = 1;
  } finally {
    flow.close();
  }
}

/// base64url in a JWS carries no padding; the Dart decoder insists on it.
String _pad(String s) => s.padRight((s.length + 3) & ~3, '=');
