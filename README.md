# Flutky

A Flutter client for [Pubky](https://pubky.org), built to answer one question:
**how far can a Flutter app go on Pubky without any Rust?**

Further than expected — including publishing. See [Status](#status).

**Android only.** There is no iOS build: the project is developed on Windows,
and building for iOS needs macOS.

- **Install and try it →** [INSTALL.md](INSTALL.md)
- **Publish a release →** [RELEASING.md](RELEASING.md)

## Status

### Working

| | |
|---|---|
| ✅ | Sign in through **Pubky Ring**, app-to-app, no QR code and nothing to type |
| ✅ | Session kept in the Android keystore — one trip through Ring, not one per launch |
| ✅ | Profile: avatar, name, status, bio, links, counters, tags |
| ✅ | Feed: following, friends, global, bookmarks — paginated, with images |
| ✅ | Reposts and quotes, showing the original post inline |
| ✅ | `@mentions` rendered as names, tap to open that person's profile |
| ✅ | Notifications: follows, tags, replies, reposts, mentions — the twelve kinds Nexus emits |
| ✅ | **Publishing** a short post to your homeserver |
| ✅ | French and English, switchable in-app |
| ✅ | Long-form posts, whose content is JSON rather than text |
| ✅ | Follow and unfollow from a profile |
| ✅ | Mentioning people when composing, searched by display name |
| ✅ | An "Ask Jeb" shortcut — mention the AI account and its reply lands in your feed |
| ✅ | Optionally folding your own posts into the Following feed |
| ✅ | Translating a draft before posting — on-device, no key, no account |
| ✅ | Built-in diagnostics for the authentication path |

### Not there yet

| | |
|---|---|
| ❌ | Tagging, bookmarking, replying — the tag id needs Blake3, not yet ported |
| ❌ | Attaching an image to a post (needs binary upload) |
| ❌ | Deleting or editing your own posts |
| ❌ | Opening a post to read its replies |
| ❌ | Search |
| ❌ | Push notifications (the tab polls; there is no background delivery) |
| ❌ | Choosing your own homeserver — `homeserver.pubky.app` is assumed |
| ❌ | Private messages — the tab is there, deliberately inert |
| ❌ | iOS |

Missing features are listed rather than reported: no need to open an issue for
them. [Feature requests](https://github.com/PastaGringo/flutky/issues/new?template=feature_request.yml)
about what to build next are welcome.

## No Rust — including for writing

Reading goes through **Nexus**, the public indexer behind pubky.app, whose v0
API needs no authentication at all.

Writing was supposed to need the Rust SDK. It does not:

- a **cookie** session authenticates with a plain `Cookie` header;
- a **grant** session needs a Proof-of-Possession JWS signed with Ed25519,
  exchanged at `/auth/grant/session` for a short-lived bearer — reimplemented
  in [`lib/pubky/grant_auth.dart`](lib/pubky/grant_auth.dart).

Both paths are in the app, and which one applies is read from the secret's own
format rather than guessed.

## Three traps this codebase documents

**The exported secret is not the cookie value.** `export_secret()` in the Pubky
SDK returns `<key>:<secret>`; sending the whole string yields
`No authenticated session found`, which reads exactly like an expired session.
Measured: 79 characters = 52 + 1 + 26.
See [`cookie_auth.dart`](lib/pubky/cookie_auth.dart).

**Resource ids are byte-oriented Crockford base32.** The obvious arithmetic
conversion produces thirteen perfectly valid characters that decode to a
different instant; the homeserver accepts the post and the indexer silently
drops it. The test decodes *real* pubky.app ids and checks they land near their
indexing date — a round trip through our own encoder would stay green with a
wrong formula. See [`crockford.dart`](lib/pubky/crockford.dart).

**A 401 from the homeserver is not diagnostic.** It answers 401 for a bad
session, a forbidden path and a route that does not exist alike. Hence the
in-app diagnostics page: eight probes side by side, two of which use no
authentication and must succeed — they are what give the others meaning.

## Layout

```
lib/
  main.dart                    state machine: restore, wait, run
  l10n/                        ARB translation templates (en, fr)
  settings/locale_controller.dart
  pubky/
    ring_session.dart          deep link out, callback in
    cookie_auth.dart           splitting the exported secret
    grant_auth.dart            PoP signing and bearer exchange
    session_store.dart         session in the platform keystore
    crockford.dart             timestamp ids
    mentions.dart              content into text, mentions and links
    nexus.dart                 indexer client and models
    homeserver.dart            writing
    diagnostics.dart           authentication probes
  screens/                     connect, feed, notifications, profile,
                               compose, diagnostics, settings
test/                          67 tests, offline and against the live network
  fixtures/                    untouched Nexus responses
```

## Translating

Translations are ARB templates — the Flutter standard. Adding a language means
copying `lib/l10n/app_en.arb`, translating the values, and adding the locale to
`LocaleController.supported`. Keys and placeholders stay as they are.

```bash
cp lib/l10n/app_en.arb lib/l10n/app_es.arb   # then translate the values
flutter gen-l10n
```

## Developing

```bash
flutter pub get
flutter analyze
flutter test test/pubky_test.dart      # offline, deterministic
flutter test test/network_test.dart    # hits nexus.pubky.app
flutter build apk --release
```

The release APK is signed with the project key when `android/key.properties`
and the keystore are present, and falls back to the debug key otherwise.

## Measured, not assumed

Everything below was checked against the live network rather than read from
documentation:

- `limit` on the feed is capped at 50; `skip` paginates.
- `observer_id` is what personalises a stream — `following` and `bookmarks`
  answer **400** without it, which is how the app knows it is honoured.
- Feed images live at `/static/files/<author>/<id>/<variant>`, with three
  variants only: `main` (149 kB JPEG measured), `feed` (7.7 kB WebP) and
  `small` (2.9 kB). Anything else answers 400.
- The documented `/storage/<key>/<path>` write form answers **500** on the
  official homeserver; only the legacy `?pubky-host=` form works.
- A mention is the literal `pubky` followed by the 52-character key, with no
  separator — verified against the list Nexus itself publishes in
  `relationships.mentioned`.

## Licence

MIT.

---

Built by [Delvops](https://delvops.fr).
