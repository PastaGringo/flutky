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
| ✅ | Notifications with an unread badge: follows, tags, replies, reposts, mentions — the twelve kinds Nexus emits, each opening its post |
| ✅ | **Publishing** a short post to your homeserver |
| ✅ | French and English, switchable in-app |
| ✅ | Long-form posts, whose content is JSON rather than text |
| ✅ | Follow and unfollow from a profile |
| ✅ | Mentioning people when composing — shown as `@Name`, not as fifty-seven characters |
| ✅ | An "Ask Jeb" shortcut — mention the AI account and its reply lands in your feed |
| ✅ | Optionally folding your own posts into the Following feed |
| ✅ | **Discover**: what the network tags most, ranked by engagement, plus accounts to follow |
| ✅ | Translating a draft before posting, with your own DeepL key — mentions and links left intact |
| ✅ | **Attaching a picture** to a post — BLAKE3 blob id computed in Dart |
| ✅ | Opening a post: its labels in full, its replies, and **replying** |
| ✅ | **Tagging** a post — tap a label to add or remove yours, long-press to see who else applied it |
| ✅ | **Reposting**, as-is or as a quote with your own words on top |
| ✅ | Reply, repost and tag on every card, each carrying its own counter |
| ✅ | Replies drawn as a thread: the post being answered sits above, whole, joined by a rail down the left and foldable |
| ✅ | Translating **any** post, not only your own draft |
| ✅ | Tapping a picture to see it full screen, zoomable |
| ✅ | Built-in diagnostics for the authentication path |

### Not there yet

| | |
|---|---|
| ❌ | Bookmarking — same content-addressed id as a tag, so it is a short step |
| ❌ | Deleting or editing your own posts |
| ❌ | Search |
| ❌ | Push notifications — the badge polls every two minutes; nothing is delivered in the background |
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

## Translation: two attempts that did not survive contact

**Google ML Kit, on the device.** The best idea on paper — nothing left the
phone, it worked offline. On a signed release where the plugin was
demonstrably packaged (its channel name and method names are in `classes.dex`,
its `.so` in the APK), the translator channel answered
`MissingPluginException`. It also cost 19 MB and made the first translation
into each language wait for a model download.

Note the shape of that failure, because it is easy to misread: the exception
named `closeLanguageTranslator`, which runs in a `finally`. An exception
thrown there **replaces** the one that caused it, so the message named the
cleanup rather than the call that actually failed.

**MyMemory, keyless.** It translated well, needed no account at all, and its
limits were measured rather than assumed: 500 characters per request (600
answers `QUERY LENGTH LIMIT EXCEEDED`), 5 000 a day, and a refusal delivered
inside an **HTTP 200** with `responseStatus: 403` in the body. It also
answered 504 repeatedly under test. A feature that works when the service
feels like it is worse than one that plainly asks for a key.

**So: DeepL, with your own key.** 500 000 characters a month on the free plan,
128 KiB per request so a whole draft goes in one call, and the source language
detected server-side by omitting `source_lang`. The free host is deduced from
the key: DeepL states that free keys "can be identified easily by the suffix
`:fx`". Without a key the translate button says where to add one instead of
failing.

Measured, and worth knowing: `/v2/translate`, `/v2/usage` and a path that does
not exist all answer **403** to a bad key. DeepL authenticates before routing,
exactly like the Pubky homeserver — so a 403 proves nothing about whether a
path exists.

## BLAKE3, written out rather than depended on

A blob is addressed by the Crockford base32 of the **first half** of the
BLAKE3 hash of its bytes — the id is not a name a client gets to choose. Both
Dart packages offering BLAKE3 are FFI bindings, and this project has already
lost that bet once: ML Kit answered `MissingPluginException` on a signed
release where the plugin was demonstrably packaged. So it is two hundred lines
of pure Dart in [`blake3.dart`](lib/pubky/blake3.dart), which cannot fail to
register.

It is proven against three independent sources, because a hash that agrees
only with itself is a hash nobody else can read:

1. the fourteen official BLAKE3 vectors, **fetched** from the reference
   repository (the first version of that list was written from memory, and
   three entries were wrong — sending me to look for a bug in correct code);
2. pubky-app-specs' own test: `PubkyAppBlob(vec![1, 2])` →
   `PZBQ010FF079VVZPQG1RNFN6DR`;
3. a blob published by another client, downloaded and re-hashed against the
   id it is stored under.

Note for anyone reading the Rust: `blob.rs` comments say "Z-base32 alphabet"
while the line beneath calls `Alphabet::Crockford`. The code is what the
network agrees on, and an upper-case real id settles it.

## A tag is named by what it says

A tag lives at `/pub/pubky.app/tags/<id>` where the id is
`Crockford(BLAKE3("<uri>:<label>")[..16])` — the same derivation as a blob id,
applied to a string rather than to bytes. Nothing about it is a name a client
chooses, and that is what makes it work: tagging the same post twice writes the
same resource rather than two, and removing a tag is a `DELETE` on a path both
sides recompute from the pair.

Wrong ids fail the pubky way — the homeserver stores the file, the indexer
ignores it, nobody says anything. So the derivation is checked against
pubky-app-specs' own vector (`"cool"` on a canonical post URI →
`CBYS8P6VJPHC5XXT4WDW26662W`) and, before a line of UI existed, against three
tags published by other clients: computing the id from the pair Nexus reports
and fetching it from the tagger's homeserver answered 200 for all three.

The label is trimmed and lower-cased *before* hashing — `Cool` and `cool` are
one tag to everyone else — and refused here if it is over 20 characters or
carries a space, a comma or a colon.

## A repost is a post with an embed

No dedicated resource either: a repost is an ordinary post carrying
`embed: {kind, uri}`. With content of its own it reads as a quote, without it
as a plain share — the same write, told apart by whether it has words.

Measured on sixteen real reposts rather than guessed: pubky.app writes
`kind: "short"` inside the embed **whatever the original is**. An article, a
video and an image all came back as `short`. Copying the real kind would be
more accurate and less compatible, so this follows the network.

## Showing what an answer answers

Three attempts, and only the third works. First a framed copy of the parent
*under* the reply, which doubled the height of a feed where half the cards are
answers — and announced "original post unavailable" whenever it had not been
fetched, which was false and alarming. Then a line of text naming the author,
`↳ In reply to Someone`: honest, compact, and still making the reader hold two
cards in their head to connect them.

What works is the shape pubky.app uses: the parent above, in a **dashed** frame
so it cannot be mistaken for a card of its own, joined to the answer by a rail
down the left gutter that curves into it. The link is seen rather than read.

The parent is shown **whole**. An answer to a truncated question is as good as
an answer to nothing — so it folds away instead, from the ⊖ on the rail, for
when the feed gets long.

The same block, flat and capped at six lines, now sits in the compose sheet
while a reply is being written. It was missing: the sheet covered the post it
was answering, and one wrote from memory.

## A thread is a tree, one level at a time

A reply needs no hash at all — it is an ordinary post carrying a `parent`
URI, with the same timestamp id as any other. This README said the opposite
for several versions, lumping replies in with tags as "blocked on BLAKE3".
They never were.

Measured on a post announcing sixteen replies: `source=post_replies` returned
exactly those sixteen, all pointing at the root — while five of them had a
reply of their own that did not come back. So `counts.replies` and
`post_replies` are about **direct children**, not a subtree, and the app walks
down one screen at a time.

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
    translation.dart           DeepL, protecting mentions and links
    blake3.dart                BLAKE3 in Dart, for blob ids
  screens/                     connect, feed, discover, post, notifications,
                               profile, compose, diagnostics, settings
test/                          106 tests, offline and against the live network
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
- Discovery rests on three parameters that are all checked to actually do
  something: `sorting=total_engagement` returns a page sharing **no post at
  all** with `timeline`; `tags=<label>` returns only posts carrying that
  label, and an unknown label returns **nothing** rather than the unfiltered
  stream; `most_followed` and `influencers` are genuinely different rankings.
  A label over 20 characters is rejected outright, before any filtering.
- `tags/hot` caps its list of taggers at twenty, so `taggers_count` reads 20
  for every popular label. `tagged_count` is the number that orders anything.

## Licence

MIT.

---

Built by [Delvops](https://delvops.fr).
