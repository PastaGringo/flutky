import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutky/l10n/app_localizations.dart';
import 'package:flutky/pubky/nexus.dart';
import 'package:flutky/pubky/ring_session.dart';
import 'package:flutky/screens/post_card.dart';
import 'package:flutky/theme.dart';

/// What a card looks like, without a phone and without the network.
///
/// These are about layout decisions that are easy to get backwards and
/// impossible to notice in a diff: whether a reply repeats the post it answers,
/// whether the buttons that write are offered to a reader with no session.
/// Nothing here writes: the tests stop at the sheet that would.
void main() {
  const me = 'gujx6qd8ksydh1makdphd3bxu351d9b8waqka8hfg6q7hnqkxexo';
  const other = 'w3ase343kdnbtp4y3x69qd1qyt8peyrdtkhf671ujucc9i8fge6y';
  const session = RingSession(
    pubky: me,
    grantSecret: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    capabilities: ['/pub/pubky.app/:rw'],
  );

  PubkyPost post({
    String id = '0035NTEYSDGPT',
    String author = other,
    String content = 'Hello World',
    String? repliedUri,
    String? repostedUri,
    Map<String, int> counts = const {},
    List<ProfileTag> tags = const [],
  }) =>
      PubkyPost(
        id: id,
        author: author,
        content: content,
        kind: 'short',
        attachments: const [],
        counts: counts,
        tags: tags,
        indexedAt: DateTime.now(),
        repliedUri: repliedUri,
        repostedUri: repostedUri,
      );

  Widget host(Widget child) => MaterialApp(
        theme: flutkyTheme,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  final nexus = NexusClient();
  final parent = post(id: '0035NTF47R7C0', author: me, content: 'Le post visé');

  const profiles = {
    me: PubkyProfile(
      id: me,
      name: 'Pasta',
      bio: null,
      status: null,
      links: [],
      counts: {},
      tags: [],
      indexedAt: null,
    ),
  };

  Widget card({
    required PubkyPost subject,
    PubkyPost? quoted,
    bool hideQuote = false,
    RingSession? withSession = session,
  }) =>
      host(PostCard(
        post: subject,
        nexus: nexus,
        profiles: profiles,
        session: withSession,
        quoted: quoted,
        quotedAuthor: quoted == null ? null : profiles[quoted.author],
        hideQuote: hideQuote,
      ));

  group('A reply', () {
    testWidgets('says what it answers with an arrow, not with a copy of it',
        (tester) async {
      await tester.pumpWidget(card(
        subject: post(
          content: 'Ma réponse',
          repliedUri: 'pubky://$me/pub/pubky.app/posts/0035NTF47R7C0',
        ),
        quoted: parent,
      ));

      expect(find.text('En réponse à Pasta'), findsOneWidget);
      expect(find.byIcon(Icons.subdirectory_arrow_right_rounded),
          findsOneWidget);
      // The framed block is what the arrow replaced: repeating the parent
      // under every answer doubled the height of the feed.
      expect(find.text('Le post visé'), findsNothing);
    });

    testWidgets('names the post even when the parent could not be loaded',
        (tester) async {
      await tester.pumpWidget(card(
        subject: post(
          repliedUri: 'pubky://$me/pub/pubky.app/posts/0035NTF47R7C0',
        ),
      ));

      // Never « original post unavailable », which was both false and
      // alarming: the post exists, this card simply has not fetched it.
      expect(find.text('En réponse à un post'), findsOneWidget);
      expect(find.textContaining('indisponible'), findsNothing);
    });

    testWidgets('drops the arrow inside a thread, where the parent is above',
        (tester) async {
      await tester.pumpWidget(card(
        subject: post(
          repliedUri: 'pubky://$me/pub/pubky.app/posts/0035NTF47R7C0',
        ),
        quoted: parent,
        hideQuote: true,
      ));

      expect(find.byIcon(Icons.subdirectory_arrow_right_rounded), findsNothing);
    });
  });

  group('A repost', () {
    testWidgets('keeps the quoted post in its frame', (tester) async {
      await tester.pumpWidget(card(
        subject: post(
          content: 'Regardez ça',
          repostedUri: 'pubky://$me/pub/pubky.app/posts/0035NTF47R7C0',
        ),
        quoted: parent,
      ));

      // A quote is about the post it carries, so that one stays on screen.
      expect(find.text('Le post visé'), findsOneWidget);
      expect(find.byIcon(Icons.subdirectory_arrow_right_rounded), findsNothing);
    });
  });

  group('The action row', () {
    testWidgets('carries reply, repost and tag, with their counters',
        (tester) async {
      await tester.pumpWidget(card(
        subject: post(counts: {'replies': 2, 'reposts': 1}),
      ));

      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sell_outlined), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('offers repost and quote behind the same button',
        (tester) async {
      await tester.pumpWidget(card(subject: post()));
      await tester.tap(find.byIcon(Icons.repeat_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Partager ce post'), findsOneWidget);
      expect(find.text('Reposter'), findsOneWidget);
      expect(find.text('Citer'), findsOneWidget);
    });

    testWidgets('writes nothing without a session', (tester) async {
      await tester.pumpWidget(card(subject: post(), withSession: null));
      await tester.tap(find.byIcon(Icons.repeat_rounded));
      await tester.pumpAndSettle();

      // The counters still read; the sheet that would publish never opens.
      expect(find.text('Partager ce post'), findsNothing);
    });
  });

  group('Tags', () {
    testWidgets('are shown as chips, with the count of who applied them',
        (tester) async {
      await tester.pumpWidget(card(
        subject: post(tags: const [
          ProfileTag(label: 'pubky', taggersCount: 3, taggers: [me]),
          ProfileTag(label: 'flutter', taggersCount: 1, appliedByViewer: true),
        ]),
      ));

      expect(find.text('pubky'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('flutter'), findsOneWidget);
    });

    testWidgets('refuse a label the network would drop in silence',
        (tester) async {
      await tester.pumpWidget(card(subject: post()));
      await tester.tap(find.byIcon(Icons.sell_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Ajouter un tag'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'deux mots');
      await tester.pump();
      expect(find.textContaining('ni espace'), findsOneWidget);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull, reason: 'a refused label cannot be sent');

      await tester.enterText(find.byType(TextField), 'bitcoin');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });
  });
}
