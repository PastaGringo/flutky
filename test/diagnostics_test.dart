import 'package:flutky/pubky/diagnostics.dart';
import 'package:flutky/pubky/ring_session.dart';
import 'package:flutter_test/flutter_test.dart';

SessionDiagnostics forSecret(String secret) => SessionDiagnostics(
      session: RingSession(
        pubky: 'gujx6qd8ksydh1makdphd3bxu351d9b8waqka8hfg6q7hnqkxexo',
        grantSecret: secret,
        capabilities: const ['/pub/pubky.app/:rw'],
      ),
    );

void main() {
  group('Secret description', () {
    test('names a 26-character Crockford secret as the documented cookie form', () {
      final d = forSecret('ABCDEFGHJKMNPQRSTVWXYZ0123');
      final out = d.describeSecret();
      d.close();

      expect(out['Longueur'], '26 caractères');
      expect(out['Type détecté'], 'cookie');
      expect(out['Forme'], contains('26 caractères'));
    });

    test('names grant material by its prefix', () {
      final d = forSecret('pubky-grant-credential-v1:hs:secret:a.b.c');
      final out = d.describeSecret();
      d.close();

      expect(out['Type détecté'], 'grant');
      expect(out['Forme'], contains('pubky-grant-credential-'));
      expect(out['Segments (:)'], '4');
    });

    test('flags a Crockford secret of the wrong length rather than assuming', () {
      final d = forSecret('ABCDEF');
      final out = d.describeSecret();
      d.close();

      expect(out['Type détecté'], 'cookie');
      expect(out['Forme'], contains('pas 26'));
    });

    test('flags a secret that is neither shape', () {
      final d = forSecret('lower-case-and-dashes');
      final out = d.describeSecret();
      d.close();

      expect(out['Forme'], contains('ni grant, ni base32'));
    });

    test('never puts the secret itself in the description', () {
      const secret = 'ABCDEFGHJKMNPQRSTVWXYZ0123';
      final d = forSecret(secret);
      final out = d.describeSecret();
      d.close();

      expect(out.values.join(' '), isNot(contains(secret)));
    });
  });

  group('Probe verdict', () {
    test('counts 2xx as ok and nothing else', () {
      expect(ProbeResult(name: 'x', detail: 'y', status: 200).ok, isTrue);
      expect(ProbeResult(name: 'x', detail: 'y', status: 201).ok, isTrue);
      expect(ProbeResult(name: 'x', detail: 'y', status: 401).ok, isFalse);
      expect(ProbeResult(name: 'x', detail: 'y', status: 500).ok, isFalse);
      expect(ProbeResult(name: 'x', detail: 'y', error: 'boom').ok, isFalse);
    });
  });
}
