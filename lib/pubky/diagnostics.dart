import 'dart:convert';

import 'package:http/http.dart' as http;

import 'grant_auth.dart';
import 'homeserver.dart';
import 'ring_session.dart';

/// One probe and what the server answered.
class ProbeResult {
  ProbeResult({
    required this.name,
    required this.detail,
    this.status,
    this.body,
    this.error,
    this.expectation,
  });

  final String name;

  /// What is being sent — method, path, which header. Never the secret.
  final String detail;

  final int? status;
  final String? body;
  final String? error;

  /// What a healthy server should answer, when we know it in advance. This is
  /// what turns a status code into a verdict.
  final String? expectation;

  bool get ok => status != null && status! >= 200 && status! < 300;
}

/// Runs the checks that tell apart "the session is wrong" from "the address is
/// wrong" from "the network is down".
///
/// The homeserver answers 401 even for routes that do not exist —
/// authentication runs before routing — so a lone 401 proves nothing. The
/// anonymous controls below are what give the other probes meaning: if a public
/// read succeeds, the host and the path shape are fine, and a 401 on an
/// authenticated call really is about the session.
class SessionDiagnostics {
  SessionDiagnostics({required this.session, http.Client? client})
      : _client = client ?? http.Client();

  final RingSession session;
  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  void close() => _client.close();

  /// Everything we can say about the secret without revealing it.
  Map<String, String> describeSecret() {
    final secret = session.grantSecret;
    final isCrockford = RegExp(r'^[0-9A-HJKMNP-TV-Z]+$').hasMatch(secret);

    return {
      'Longueur': '${secret.length} caractères',
      'Type détecté': isGrantSecret(secret) ? 'grant' : 'cookie',
      'Forme': switch (secret) {
        _ when isGrantSecret(secret) => 'préfixe pubky-grant-credential-',
        _ when secret.length == 26 && isCrockford =>
          'base32 Crockford sur 26 caractères — la forme documentée '
              "d'un secret de session cookie",
        _ when isCrockford => 'base32 Crockford, mais pas 26 caractères',
        _ => 'ni grant, ni base32 Crockford',
      },
      'Segments (:)': '${secret.split(':').length}',
      'Capacités': session.capabilities.isEmpty
          ? 'aucune annoncée'
          : session.capabilities.join(', '),
    };
  }

  Future<List<ProbeResult>> run() async {
    final pubky = session.pubky;
    final secret = session.grantSecret;
    final cookie = '$pubky=$secret';

    return [
      // --- Controls: no authentication involved. If these fail, nothing below
      // means anything.
      await _probe(
        name: 'Témoin — lecture publique existante',
        detail: 'GET /pub/pubky.app/profile.json?pubky-host=<clé>',
        expectation: '200 attendu — prouve que le serveur et le chemin sont bons',
        request: () => _client.get(
          Uri.parse('$homeserverBase/pub/pubky.app/profile.json'
              '?pubky-host=$pubky'),
        ),
      ),
      await _probe(
        name: 'Témoin — lecture publique inexistante',
        detail: 'GET /pub/flutky.invalid/nope?pubky-host=<clé>',
        expectation: '404 attendu — prouve que le serveur distingue les chemins',
        request: () => _client.get(
          Uri.parse('$homeserverBase/pub/flutky.invalid/nope'
              '?pubky-host=$pubky'),
        ),
      ),

      // --- Session checks. GET /session validates a cookie without writing.
      await _probe(
        name: 'Session — cookie, hôte en paramètre',
        detail: 'GET /session?pubky-host=<clé> · en-tête Cookie',
        expectation: '200 si le cookie est accepté',
        request: () => _client.get(
          Uri.parse('$homeserverBase/session?pubky-host=$pubky'),
          headers: {'Cookie': cookie},
        ),
      ),
      await _probe(
        name: 'Session — cookie, hôte en en-tête',
        detail: 'GET /session · en-têtes Cookie + pubky-host',
        expectation: '200 si le cookie est accepté',
        request: () => _client.get(
          Uri.parse('$homeserverBase/session'),
          headers: {'Cookie': cookie, 'pubky-host': pubky},
        ),
      ),
      await _probe(
        name: 'Session — cookie nommé « session »',
        detail: 'GET /session?pubky-host=<clé> · Cookie: session=<secret>',
        expectation: "au cas où le nom du cookie ne serait pas la clé",
        request: () => _client.get(
          Uri.parse('$homeserverBase/session?pubky-host=$pubky'),
          headers: {'Cookie': 'session=$secret'},
        ),
      ),
      await _probe(
        name: 'Session — secret en Bearer',
        detail: 'GET /session?pubky-host=<clé> · Authorization: Bearer',
        expectation: 'au cas où le secret serait déjà un jeton porteur',
        request: () => _client.get(
          Uri.parse('$homeserverBase/session?pubky-host=$pubky'),
          headers: {'Authorization': 'Bearer $secret'},
        ),
      ),
      await _probe(
        name: 'Session — forme locataire',
        detail: 'GET /<clé>/session · en-tête Cookie',
        // Measured 2026-09-07 without any auth: this shape answers 500 on the
        // official homeserver, exactly like /storage/<key>/. Listed so a 500
        // here reads as "route cassée", not as a clue about the session.
        expectation: '500 attendu même sans session — cette forme est cassée '
            'sur le homeserver officiel',
        request: () => _client.get(
          Uri.parse('$homeserverBase/$pubky/session'),
          headers: {'Cookie': cookie},
        ),
      ),

      // --- The write itself, on a path that is not pubky.app so a stray
      // success cannot pollute the real feed.
      await _probe(
        name: 'Écriture — cookie',
        detail: 'PUT /pub/flutky.probe/ping?pubky-host=<clé> · Cookie',
        expectation: '201 si le serveur accepte, 401 sinon',
        request: () => _client.put(
          Uri.parse('$homeserverBase/pub/flutky.probe/ping?pubky-host=$pubky'),
          headers: {'Cookie': cookie, 'Content-Type': 'text/plain'},
          body: utf8.encode('flutky probe'),
        ),
      ),
    ];
  }

  Future<ProbeResult> _probe({
    required String name,
    required String detail,
    required Future<http.Response> Function() request,
    String? expectation,
  }) async {
    try {
      final res = await request().timeout(_timeout);
      return ProbeResult(
        name: name,
        detail: detail,
        expectation: expectation,
        status: res.statusCode,
        body: _preview(res),
      );
    } catch (e) {
      return ProbeResult(
        name: name,
        detail: detail,
        expectation: expectation,
        error: '$e',
      );
    }
  }

  /// Bodies can be binary (the session route serves postcard), so show a byte
  /// count rather than mojibake when the payload is not text.
  static String _preview(http.Response res) {
    if (res.bodyBytes.isEmpty) return '(vide)';
    try {
      final text = utf8.decode(res.bodyBytes);
      if (!RegExp(r'^[\x09\x0a\x0d\x20-\x7e -￿]*$').hasMatch(text)) {
        return '${res.bodyBytes.length} octets binaires';
      }
      return text.length <= 300 ? text : '${text.substring(0, 300)}…';
    } catch (_) {
      return '${res.bodyBytes.length} octets binaires';
    }
  }
}
