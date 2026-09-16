/// Reading [eventky](https://github.com/gillohner/eventky), another Pubky app.
///
/// The point of this file is that it needs **no permission at all**. `/pub/` is
/// world-readable over plain HTTP, so an app can display another app's data
/// without asking anyone for anything — measured: `/pub/eventky.app/` answers
/// 200 to an anonymous request. Only writing would need a grant covering
/// `/pub/eventky.app/:rw`, and Ring lists such a folder on its own line in the
/// approval screen, beside the app's own.
///
/// The shape below is read from a real event on the live network, not from
/// eventky's source — its repository has not moved since May, and a format
/// that drifted would be a silent failure.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'endpoints.dart';
import 'nexus.dart' show nexusBase;

/// Where eventky keeps its things, under the owner's public namespace.
const eventkyNamespace = '/pub/eventky.app';

/// One event, as eventky writes it.
///
/// The vocabulary is iCalendar's — `summary`, `dtstart`, `rrule`, `partstat` —
/// which is why the field names read oddly for a social app. Keeping them is
/// deliberate: renaming them here would hide what is actually on the wire.
class EventkyEvent {
  const EventkyEvent({
    required this.uri,
    required this.owner,
    required this.id,
    required this.summary,
    this.description,
    this.start,
    this.timezone,
    this.duration,
    this.url,
    this.imageUri,
    this.status,
  });

  final String uri;
  final String owner;
  final String id;

  /// The title. iCalendar calls it a summary.
  final String summary;

  /// Plain text, extracted from `styled_description` when that is HTML.
  final String? description;

  /// Local wall-clock time, with [timezone] naming where. Deliberately not
  /// converted: an event at 18:00 in Zurich is at 18:00 in Zurich, and turning
  /// it into the reader's own zone would misstate what the organiser wrote.
  final DateTime? start;
  final String? timezone;

  /// ISO 8601, e.g. `PT1H30M`.
  final String? duration;

  final String? url;
  final String? imageUri;
  final String? status;

  /// The image, resolved to something a browser can fetch.
  ///
  /// eventky stores it as a `pubky://…/pub/pubky.app/files/<id>` URI — a
  /// pubky-app file — so the variants Nexus serves apply unchanged.
  String? imageUrl({String variant = 'feed'}) {
    final uri = imageUri;
    if (uri == null) return null;
    final m = RegExp(r'^pubky://([^/]+)/pub/pubky\.app/files/([^/?#]+)')
        .firstMatch(uri);
    if (m == null) return null;
    return '$nexusBase/static/files/${m.group(1)}/${m.group(2)}/$variant';
  }

  factory EventkyEvent.fromJson(
    Map<String, dynamic> json, {
    required String owner,
    required String id,
  }) {
    String? text(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty || s == 'null') ? null : s;
    }

    // `description` is often null while `styled_description` carries HTML.
    var description = text(json['description']);
    final styled = json['styled_description'];
    if (description == null && styled is Map<String, dynamic>) {
      final content = text(styled['content']);
      if (content != null) {
        description = styled['format'] == 'html' ? _stripHtml(content) : content;
      }
    }

    return EventkyEvent(
      uri: 'pubky://$owner$eventkyNamespace/events/$id',
      owner: owner,
      id: id,
      summary: text(json['summary']) ?? '(sans titre)',
      description: description,
      start: DateTime.tryParse(text(json['dtstart']) ?? ''),
      timezone: text(json['dtstart_tzid']),
      duration: text(json['duration']),
      url: text(json['url']),
      imageUri: text(json['image_uri']),
      status: text(json['status']),
    );
  }
}

/// Turns eventky's stored HTML into something a Text widget can show.
///
/// Not a general HTML renderer, and not trying to be: paragraph and list
/// boundaries become line breaks, entities are decoded, everything else is
/// dropped. A description shown as raw `<p>` tags would read worse than no
/// description at all.
String _stripHtml(String html) => html
    .replaceAll(RegExp(r'</(p|h[1-6]|li|div)>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// What the reader said about an event they are attending.
class EventkyAttendance {
  const EventkyAttendance({required this.eventUri, required this.partstat});

  final String eventUri;

  /// `ACCEPTED`, `DECLINED`, `TENTATIVE` — iCalendar's participation status.
  final String? partstat;
}

/// Reads eventky's public data. No session, no headers, no permission.
class EventkyClient {
  EventkyClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  /// Lists the entries of a folder.
  ///
  /// The homeserver answers a plain list of `pubky://` URIs, one per line, and
  /// **404 for a folder that does not exist** — which is the ordinary case for
  /// someone who has never used eventky, not an error worth surfacing.
  Future<List<String>> _list(String owner, String folder) async {
    final uri = Uri.parse(
      '$homeserverBase$eventkyNamespace/$folder/?pubky-host=$owner',
    );
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return const [];
    return utf8
        .decode(res.bodyBytes)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('pubky://'))
        .toList();
  }

  Future<Map<String, dynamic>?> _read(String pubkyUri) async {
    final m = RegExp(r'^pubky://([^/]+)(/pub/.+)$').firstMatch(pubkyUri);
    if (m == null) return null;
    try {
      final res = await _client
          .get(Uri.parse('$homeserverBase${m.group(2)}?pubky-host=${m.group(1)}'))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// One event, by its `pubky://` URI.
  Future<EventkyEvent?> fetchEvent(String uri) async {
    final m = RegExp(r'^pubky://([^/]+)/pub/eventky\.app/events/([^/?#]+)')
        .firstMatch(uri);
    if (m == null) return null;
    final json = await _read(uri);
    if (json == null) return null;
    return EventkyEvent.fromJson(json, owner: m.group(1)!, id: m.group(2)!);
  }

  /// The events this account created.
  Future<List<EventkyEvent>> fetchOwnEvents(String owner) async {
    final uris = await _list(owner, 'events');
    final out = <EventkyEvent>[];
    for (final uri in uris) {
      final event = await fetchEvent(uri);
      if (event != null) out.add(event);
    }
    return out;
  }

  /// What this account said it would attend.
  Future<List<EventkyAttendance>> fetchAttendance(String owner) async {
    final uris = await _list(owner, 'attendees');
    final out = <EventkyAttendance>[];
    for (final uri in uris) {
      final json = await _read(uri);
      final eventUri = json?['x_pubky_event_uri']?.toString();
      if (eventUri == null || eventUri.isEmpty) continue;
      out.add(EventkyAttendance(
        eventUri: eventUri,
        partstat: json?['partstat']?.toString(),
      ));
    }
    return out;
  }

  void close() => _client.close();
}
