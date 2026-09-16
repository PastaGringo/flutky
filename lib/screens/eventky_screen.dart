import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../pubky/eventky.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';

/// The reader's eventky calendar, read straight off the homeserver.
///
/// Two sources, both public: what they created, and what they said they would
/// attend. There is no index for eventky — Nexus only knows pubky.app — so
/// discovery beyond one's own account would mean walking the social graph and
/// asking every followed key. That is a later question; this screen answers
/// the one that needs no guessing.
class EventkyScreen extends StatefulWidget {
  const EventkyScreen({super.key, required this.session});

  final RingSession session;

  @override
  State<EventkyScreen> createState() => _EventkyScreenState();
}

class _EventkyScreenState extends State<EventkyScreen> {
  final _client = EventkyClient();

  final _events = <EventkyEvent>[];
  final _partstat = <String, String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mine = await _client.fetchOwnEvents(widget.session.pubky);
      final going = await _client.fetchAttendance(widget.session.pubky);

      final byUri = {for (final e in mine) e.uri: e};
      final status = <String, String>{};
      for (final a in going) {
        if (a.partstat != null) status[a.eventUri] = a.partstat!;
        if (byUri.containsKey(a.eventUri)) continue;
        final event = await _client.fetchEvent(a.eventUri);
        if (event != null) byUri[event.uri] = event;
      }

      // Soonest first, and anything undated last — an event without a start is
      // a draft, not something to put at the top of a calendar.
      final all = byUri.values.toList()
        ..sort((a, b) {
          if (a.start == null) return b.start == null ? 0 : 1;
          if (b.start == null) return -1;
          return a.start!.compareTo(b.start!);
        });

      if (!mounted) return;
      setState(() {
        _events
          ..clear()
          ..addAll(all);
        _partstat
          ..clear()
          ..addAll(status);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final empty = _events.isEmpty && !_loading && _error == null;

    return Scaffold(
      appBar: AppBar(backgroundColor: kBackground, title: const Text('Eventky')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (_error != null) ...[
                ErrorPanel(message: _error!),
                const SizedBox(height: 14),
              ],
              if (_loading && _events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              if (empty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 50, 12, 12),
                  child: Text(
                    l.eventkyEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kTextMuted, height: 1.5),
                  ),
                ),
              for (final event in _events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EventCard(
                    event: event,
                    partstat: _partstat[event.uri],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.partstat});

  final EventkyEvent event;
  final String? partstat;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final image = event.imageUrl();

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                image,
                width: double.infinity,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.summary,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: kTextMuted),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _when(l),
                        style: const TextStyle(
                            color: kTextMuted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                if (partstat != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: kAccent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _partstatLabel(l),
                      style: const TextStyle(color: kAccent, fontSize: 11.5),
                    ),
                  ),
                ],
                if (event.description case final text?) ...[
                  const SizedBox(height: 11),
                  Text(
                    text,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                ],
                if (event.url case final url?) ...[
                  const SizedBox(height: 11),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication),
                    child: Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kAccent, fontSize: 12.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The organiser's wall clock, with its zone named.
  ///
  /// Deliberately not converted to the reader's own: an event at 18:00 in
  /// Zurich is at 18:00 in Zurich, and silently shifting it would misstate
  /// what was written — the more so as eventky stores the zone beside the
  /// time precisely so it can be shown.
  String _when(L10n l) {
    final start = event.start;
    if (start == null) return l.eventkyNoDate;
    String two(int n) => n.toString().padLeft(2, '0');
    final date =
        '${two(start.day)}/${two(start.month)}/${start.year} · ${two(start.hour)}:${two(start.minute)}';
    final zone = event.timezone;
    final duration = event.duration;
    return [date, ?zone, ?_humanDuration(duration)].join('  ');
  }

  /// `PT1H30M` into `1 h 30`.
  ///
  /// eventky stores an ISO 8601 duration because iCalendar does. Shown raw it
  /// reads as a serial number; the parts that are zero are dropped so a plain
  /// two-hour meeting says `2 h` rather than `2 h 0`.
  static String? _humanDuration(String? iso) {
    if (iso == null) return null;
    final m = RegExp(r'^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?$').firstMatch(iso);
    if (m == null) return iso;
    final days = int.tryParse(m.group(1) ?? '') ?? 0;
    final hours = int.tryParse(m.group(2) ?? '') ?? 0;
    final minutes = int.tryParse(m.group(3) ?? '') ?? 0;
    if (days == 0 && hours == 0 && minutes == 0) return null;
    return [
      if (days > 0) '$days j',
      if (hours > 0) '$hours h',
      if (minutes > 0) (hours > 0 ? '$minutes' : '$minutes min'),
    ].join(' ');
  }

  String _partstatLabel(L10n l) => switch (partstat) {
        'ACCEPTED' => l.eventkyGoing,
        'DECLINED' => l.eventkyNotGoing,
        'TENTATIVE' => l.eventkyMaybe,
        _ => partstat ?? '',
      };
}
