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

import 'package:http/http.dart' as http;

import 'package:flutky/pubky/grant_auth.dart';
import 'package:flutky/pubky/grant_flow.dart';
import 'package:flutky/pubky/endpoints.dart';
import 'package:flutky/pubky/z32.dart';

Future<void> main(List<String> args) async {
  // Second argument: the capabilities to ask for. Lets one run check what
  // Ring actually shows when an app asks for more than its own namespace.
  final flow = await GrantAuthFlow.begin(
    capabilities: args.length > 1 ? args[1] : flutkyCapabilities,
  );

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
    // --- second half: trade the grant for a bearer ------------------------
    stdout
      ..writeln()
      ..writeln('--- échange contre un porteur ---------------------------------');

    final claims = GrantClaims.fromJws(jws);
    stdout
      ..writeln('grant id   : ${claims.grantId}')
      ..writeln('émetteur   : ${claims.issuer}')
      ..writeln('expire le  : ${claims.expiresAt.toIso8601String()}')
      ..writeln('périmé ?   : ${claims.isExpired}');

    final client = http.Client();
    try {
      final bearer = await exchangeGrantForBearer(
        stored: StoredGrant(
          homeserverPublicKey: homeserverPublicKey,
          clientSecret: await flow.clientSeed(),
          grantJws: jws,
        ),
        claims: claims,
        baseUrl: homeserverBase,
        client: client,
      );
      stdout
        ..writeln('PORTEUR OBTENU — ${bearer.token.length} caractères')
        ..writeln('expire le  : ${bearer.expiresAt.toIso8601String()}')
        ..writeln('à rafraîchir ? ${bearer.needsRefresh}');

      // The proof that matters: do something only a session can do.
      //
      // Several shapes are tried rather than one, because this homeserver
      // answers **401 for a route that does not exist** — authentication runs
      // before routing. A single 401 would therefore not distinguish "the
      // bearer is refused" from "that path is not a path".
      stdout.writeln();
      final auth = {
        'Authorization': 'Bearer ${bearer.token}',
      };

      Future<void> probe(String label, Future<http.Response> call) async {
        try {
          final r = await call;
          final body = utf8.decode(r.bodyBytes, allowMalformed: true);
          stdout.writeln('  ${label.padRight(46)} ${r.statusCode}  '
              '${body.length > 60 ? '${body.substring(0, 60)}…' : body}');
        } catch (e) {
          stdout.writeln('  ${label.padRight(46)} ÉCHEC $e');
        }
      }

      final host = claims.issuer;
      await probe(
        'GET /session?pubky-host=',
        client.get(Uri.parse('$homeserverBase/session?pubky-host=$host'),
            headers: auth),
      );
      await probe(
        'GET /session  (en-tête pubky-host)',
        client.get(Uri.parse('$homeserverBase/session'),
            headers: {...auth, 'pubky-host': host}),
      );
      await probe(
        'GET /$host/session',
        client.get(Uri.parse('$homeserverBase/$host/session'), headers: auth),
      );
      // The negative control: the same call with no bearer at all. It must
      // fail, or a success above would prove nothing about the token.
      await probe(
        'témoin — la même, SANS porteur',
        client.get(Uri.parse('$homeserverBase/session?pubky-host=$host')),
      );
      // And a real write, which is the whole point of authenticating.
      // A path of its own: `last_read` is an existing FILE in pubky-app's
      // tree, and writing under it answers 409 "File/folder path collision" —
      // which is an authenticated refusal, not an authentication failure.
      final probePath = '/pub/pubky.app/flutky_probe/grant.json';
      await probe(
        'PUT une ressource jetable',
        client.put(
          Uri.parse('$homeserverBase$probePath?pubky-host=$host'),
          headers: {...auth, 'Content-Type': 'application/json'},
          body: '{"timestamp":${DateTime.now().millisecondsSinceEpoch}}',
        ),
      );
      await probe(
        'DELETE la même ressource',
        client.delete(
          Uri.parse('$homeserverBase$probePath?pubky-host=$host'),
          headers: auth,
        ),
      );
    } finally {
      client.close();
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
