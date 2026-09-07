import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pubky/diagnostics.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';

/// In-app diagnostics for the write path.
///
/// Exists because a 401 from the homeserver is not diagnostic on its own: it
/// answers 401 for a bad session, a wrong path, and a route that does not
/// exist alike. Running several probes side by side — including anonymous
/// controls that must succeed — is what turns the wall of 401s into an answer.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key, required this.session});

  final RingSession session;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<ProbeResult>? _results;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _running = true);
    final diagnostics = SessionDiagnostics(session: widget.session);
    try {
      final results = await diagnostics.run();
      if (mounted) setState(() => _results = results);
    } finally {
      diagnostics.close();
      if (mounted) setState(() => _running = false);
    }
  }

  String _asText() {
    final diagnostics = SessionDiagnostics(session: widget.session);
    final out = StringBuffer('FLUTKY — diagnostic session\n\n');
    diagnostics.describeSecret().forEach((k, v) => out.writeln('$k : $v'));
    diagnostics.close();

    out.writeln();
    for (final r in _results ?? const <ProbeResult>[]) {
      out
        ..writeln('— ${r.name}')
        ..writeln('  ${r.detail}')
        ..writeln('  ${r.error != null ? "ERREUR ${r.error}" : "HTTP ${r.status} · ${r.body}"}')
        ..writeln();
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = SessionDiagnostics(session: widget.session);
    final description = diagnostics.describeSecret();
    diagnostics.close();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackground,
        title: const Text('Diagnostic'),
        actions: [
          IconButton(
            onPressed: _running ? null : _run,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Relancer',
          ),
          IconButton(
            onPressed: _results == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: _asText()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Diagnostic copié')),
                      );
                    }
                  },
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copier le rapport',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Title('SECRET DE SESSION'),
                  const SizedBox(height: 12),
                  for (final entry in description.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 104,
                            child: Text(
                              entry.key,
                              style: const TextStyle(color: kTextMuted, fontSize: 12.5),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 12.5, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'La valeur du secret n’est jamais affichée ni copiée.',
                    style: TextStyle(color: kTextMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_running && _results == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              for (final result in _results ?? const <ProbeResult>[]) ...[
                _ProbeTile(result: result),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 6),
            const Panel(
              child: Text(
                'Le homeserver répond 401 même sur une route inexistante : '
                'l’authentification passe avant le routage. Un 401 isolé ne '
                'prouve donc rien. Ce sont les deux témoins du haut — qui '
                'n’utilisent aucune authentification — qui donnent leur sens '
                'aux autres : s’ils passent, l’adresse et le réseau sont bons, '
                'et un refus plus bas concerne bien la session.',
                style: TextStyle(color: kTextMuted, fontSize: 12.5, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProbeTile extends StatelessWidget {
  const _ProbeTile({required this.result});

  final ProbeResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.error != null
        ? kDanger
        : result.ok
            ? kAccent
            : kTextMuted;

    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.name,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.45)),
                ),
                child: Text(
                  result.error != null ? 'échec' : '${result.status}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.detail,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: kTextMuted,
              height: 1.4,
            ),
          ),
          if (result.expectation != null) ...[
            const SizedBox(height: 4),
            Text(
              result.expectation!,
              style: const TextStyle(fontSize: 11, color: kTextMuted, height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          SelectableText(
            result.error ?? result.body ?? '',
            style: const TextStyle(fontSize: 11.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: kTextMuted,
        ),
      );
}
