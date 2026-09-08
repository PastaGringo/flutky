import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';

import '../pubky/grant_auth.dart';
import '../pubky/homeserver.dart';
import '../pubky/mentions.dart';
import '../pubky/nexus.dart';
import '../pubky/translation.dart';
import '../pubky/ring_session.dart';
import '../theme.dart';
import 'post_card.dart';

/// What a successful publish hands back: enough to render the post before the
/// indexer has seen it.
typedef PublishedPost = ({
  String id,
  String content,
  List<String> attachments,
});

/// Composes and publishes a short post.
///
/// Returns the new post when the write succeeded, null otherwise — the caller
/// shows it optimistically, since Nexus lags the homeserver and cannot confirm
/// a fresh write.
/// The AI account on Pubky: mentioning it makes it answer in the feed.
const jebPubky = '9o6xrx8wgqu48dmb47uep6w3dgbwdnf5jgw83gbeuxg9yi7x444y';

Future<PublishedPost?> showComposeSheet(
  BuildContext context, {
  required RingSession session,
  required NexusClient nexus,
  required String uiLanguage,
  String deepLKey = '',
  String initialContent = '',
  /// A mention to insert on opening, as `(key, name)`.
  ///
  /// Not folded into [initialContent]: that one is raw text, and a mention
  /// pasted as raw text shows its 52 characters instead of `@Name`. The
  /// shortcut from the feed did exactly that for a version.
  ({String pubky, String name})? initialMention,
  /// The `pubky://` URI this post answers, when it is a reply.
  String? parent,
  /// The `pubky://` URI this post shares, when it is a quote. A repost with
  /// words is exactly that: an ordinary post carrying an `embed`.
  String? quote,
  /// What is being quoted, so the sheet can show it. Passed in rather than
  /// fetched: the card that opened the sheet already has it, and a spinner
  /// over something already on screen would be absurd.
  PubkyPost? quotedPost,
  PubkyProfile? quotedAuthor,
}) =>
    showModalBottomSheet<PublishedPost>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ComposeSheet(
        session: session,
        nexus: nexus,
        uiLanguage: uiLanguage,
        deepLKey: deepLKey,
        initialContent: initialContent,
        initialMention: initialMention,
        parent: parent,
        quote: quote,
        quotedPost: quotedPost,
        quotedAuthor: quotedAuthor,
      ),
    );

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({
    required this.session,
    required this.nexus,
    required this.uiLanguage,
    required this.deepLKey,
    required this.initialContent,
    required this.initialMention,
    required this.parent,
    required this.quote,
    required this.quotedPost,
    required this.quotedAuthor,
  });

  final RingSession session;
  final NexusClient nexus;
  final String uiLanguage;
  final String deepLKey;
  final String initialContent;
  final ({String pubky, String name})? initialMention;
  final String? parent;
  final String? quote;
  final PubkyPost? quotedPost;
  final PubkyProfile? quotedAuthor;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  late final _controller = TextEditingController(text: widget.initialContent);
  bool _sending = false;
  String? _error;

  /// What the editor shows for a mention, mapped to the key it stands for.
  ///
  /// A mention on the wire is `pubky` plus 52 characters. Leaving that in the
  /// text field means writing around a 57-character blob, so the editor shows
  /// `@Name` and the substitution happens once, at publish. Edit or delete the
  /// alias and the mention simply does not happen — which is what deleting
  /// it meant.
  final _aliases = <String, String>{};

  /// The picture to publish with the post, already in memory.
  ///
  /// Held as bytes rather than as a path: the id of a blob **is** its BLAKE3
  /// hash, so the bytes have to be read before anything can be named — and
  /// reading them twice to hash then upload would be a waste on a phone.
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageType;
  double _uploadProgress = 0;

  /// Result of minting a token before the user types anything: publishing is
  /// worth attempting only if the homeserver already accepts our credentials.
  bool? _canWrite;
  String? _accessError;

  late final _translator = Translator(deepLKey: widget.deepLKey);
  bool _translating = false;

  /// Kept so a translation can be undone: replacing what someone wrote without
  /// a way back is a destructive edit, however good the translation is.
  String? _beforeTranslation;

  /// What actually gets published: aliases swapped back for their wire form.
  ///
  /// Longest first, so `@Jeb` cannot eat the start of `@Jeb-9o6x`. The
  /// replacement contains no `@`, so no substitution can feed another.
  String _wireContent() {
    var text = _controller.text;
    for (final alias in _aliasesLongestFirst()) {
      text = text.replaceAll(alias, 'pubky${_aliases[alias]}');
    }
    return text.trim();
  }

  List<String> _aliasesLongestFirst() => _aliases.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  /// Everything a translation must leave alone: the aliases on screen, any raw
  /// mention someone pasted in, and links.
  RegExp _protectedPattern() => RegExp([
        for (final alias in _aliasesLongestFirst()) RegExp.escape(alias),
        mentionPattern,
        linkPattern,
      ].join('|'));

  Future<void> _translate() async {
    final text = _controller.text.trim();
    final l = L10n.of(context);
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.composeTranslateNothing)),
      );
      return;
    }

    if (!_translator.ready) {
      // Not a failure: nothing has been set up yet. Saying where to go beats
      // showing an authentication error for a key that was never entered.
      setState(() => _error = l.composeTranslateNoKey);
      return;
    }

    final choice = await showModalBottomSheet<TranslationChoice>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LanguagePicker(defaultTarget: widget.uiLanguage),
    );
    if (choice == null || !mounted) return;

    setState(() => _translating = true);
    try {
      final translated = await _translator.translateProtecting(
        _controller.text,
        from: choice.from,
        to: choice.to,
        protect: _protectedPattern(),
      );
      if (!mounted) return;
      setState(() {
        _beforeTranslation = _controller.text;
        _controller.text = translated;
      });
      // No confirmation banner: the text visibly changed, and the Undo chip
      // that appears in the action row above says the same thing without
      // covering a third of the sheet.
    } on TranslationRefused catch (e) {
      // The two refusals a person can act on say what to do; anything else
      // shows the service's own wording, which at least names the cause.
      if (mounted) {
        setState(() => _error = switch (e) {
              _ when e.badKey => l.composeTranslateBadKey,
              _ when e.quotaExhausted => l.composeTranslateQuota,
              _ => l.composeTranslateFailed(e.message),
            });
      }
    } catch (e) {
      if (mounted) setState(() => _error = l.composeTranslateFailed('$e'));
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  void _undoTranslation() {
    final before = _beforeTranslation;
    if (before == null) return;
    setState(() {
      _controller.text = before;
      _beforeTranslation = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkAccess();
    final mention = widget.initialMention;
    if (mention != null) {
      _insertMention(mention.pubky, mention.name);
    }
  }

  Future<void> _checkAccess() async {
    final client = HomeserverClient(session: widget.session);
    try {
      await client.checkWriteAccess();
      if (mounted) setState(() => _canWrite = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _canWrite = false;
          _accessError = '$e';
        });
      }
    } finally {
      client.close();
    }
  }


  /// Inserts a mention at the caret, shown as `@Name`.
  ///
  /// Spaces are added around it so it never welds onto a neighbouring word: on
  /// the wire the match is anchored on exactly 52 characters, and here the
  /// substitution is on the exact alias — both break if it touches a word.
  void _insertMention(String pubky, String name) {
    final alias = aliasForMention(pubky, name, _aliases);
    final text = _controller.text;
    final sel = _controller.selection;
    final at = sel.isValid ? sel.start : text.length;

    final before = text.substring(0, at);
    final after = text.substring(at);
    final needsLeading = before.isNotEmpty && !before.endsWith(' ');
    final token = '${needsLeading ? ' ' : ''}$alias ';

    setState(() {
      _aliases[alias] = pubky;
      _controller.value = TextEditingValue(
        text: before + token + after,
        selection: TextSelection.collapsed(offset: (before + token).length),
      );
    });
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Resized by the picker rather than uploaded whole: a modern phone
        // photo is 6 to 10 MB, and Nexus serves it back at 1920 px anyway.
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _imageType = picked.mimeType ?? _typeFromName(picked.name);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// The picker leaves the type null on some Android versions, and the file
  /// record needs one — a blob with the wrong content type is served back with
  /// it, and the image never renders.
  static String _typeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _removeImage() => setState(() {
        _imageBytes = null;
        _imageName = null;
        _imageType = null;
      });

  Future<void> _pickMention() async {
    final picked = await showModalBottomSheet<PubkyProfile>(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MentionPicker(nexus: widget.nexus),
    );
    if (picked != null) _insertMention(picked.id, picked.name);
  }

  @override
  void dispose() {
    _translator.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final content = _wireContent();
    final image = _imageBytes;
    if ((content.isEmpty && image == null) || _sending) return;

    setState(() {
      _sending = true;
      _uploadProgress = 0;
      _error = null;
    });

    final client = HomeserverClient(session: widget.session);
    try {
      // The picture goes up first: the post has to point at a file that
      // already exists, and a post published before its image would render
      // broken for everyone who read it in between.
      final attachments = <String>[];
      if (image != null) {
        if (mounted) setState(() => _uploadProgress = 0.5);
        attachments.add(await client.uploadImage(
          image,
          name: _imageName ?? 'image.jpg',
          contentType: _imageType ?? 'image/jpeg',
        ));
      }
      if (mounted) setState(() => _uploadProgress = 1);

      final id = await client.createShortPost(
        content,
        attachments: attachments,
        parent: widget.parent,
        embed: widget.quote,
      );

      // The 201 alone is not proof: read it back from the homeserver, which
      // is the only source that answers immediately after a write.
      final stored = await client.readPost(id);
      if (stored == null) {
        throw const WriteFailed(0, 'écrit, mais introuvable à la relecture');
      }

      if (mounted) {
        Navigator.pop(
          context,
          (id: id, content: content, attachments: attachments),
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = e.message.toString());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      client.close();
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    // Counted on what will be published, not on what is displayed: an alias is
    // a handful of characters standing for fifty-seven.
    final length = _wireContent().length;
    final tooLong = length > maxShortPostLength;
    final err = _error;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                switch ((widget.parent, widget.quote)) {
                  (final String _, _) => l.composeReplyTitle,
                  (_, final String _) => l.composeQuoteTitle,
                  _ => l.composeTitle,
                },
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
              ),
              const Spacer(),
              _AccessBadge(
                kind: isGrantSecret(widget.session.grantSecret)
                    ? AuthKind.grant
                    : AuthKind.cookie,
                canWrite: _canWrite,
              ),
            ],
          ),
          if (_accessError != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(message: _accessError!),
          ],
          const SizedBox(height: 12),
          // A Wrap, not a Row: five actions do not fit across a phone, and a
          // Row silently pushes the last one off the edge rather than saying
          // so. The translate button spent a version invisible that way.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ComposeAction(
                icon: Icons.alternate_email_rounded,
                label: l.composeMention,
                onTap: _sending ? null : _pickMention,
              ),
              _ComposeAction(
                icon: Icons.smart_toy_outlined,
                label: l.composeAskJeb,
                onTap:
                    _sending ? null : () => _insertMention(jebPubky, 'Jeb'),
              ),
              _ComposeAction(
                icon: Icons.image_outlined,
                label: l.composeImage,
                onTap: (_sending || _imageBytes != null) ? null : _pickImage,
              ),
              _ComposeAction(
                icon: Icons.translate_rounded,
                label: _translating ? l.composeTranslating : l.composeTranslate,
                onTap: (_sending || _translating) ? null : _translate,
              ),
              if (_beforeTranslation != null)
                _ComposeAction(
                  icon: Icons.undo_rounded,
                  label: l.composeTranslateUndo,
                  onTap: _sending ? null : _undoTranslation,
                ),
            ],
          ),
          if (_imageBytes case final bytes?) ...[
            const SizedBox(height: 12),
            _ImagePreview(
              bytes: bytes,
              name: _imageName ?? '',
              onRemove: _sending ? null : _removeImage,
            ),
          ],
          if (_sending && _imageBytes != null) ...[
            const SizedBox(height: 10),
            // A picture takes seconds to travel, and a button that merely
            // spins says nothing about whether anything is happening.
            LinearProgressIndicator(
              value: _uploadProgress == 0 ? null : _uploadProgress,
              backgroundColor: kBackground,
              minHeight: 3,
            ),
            const SizedBox(height: 6),
            Text(
              l.composeUploading,
              style: const TextStyle(color: kTextMuted, fontSize: 12),
            ),
          ],
          if (widget.quotedPost case final quoted?) ...[
            const SizedBox(height: 12),
            _QuotedPreview(post: quoted, author: widget.quotedAuthor),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 7,
            minLines: 4,
            enabled: !_sending,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 15.5, height: 1.5),
            decoration: InputDecoration(
              hintText: switch ((widget.parent, widget.quote)) {
                (final String _, _) => l.composeReplyHint,
                (_, final String _) => l.composeQuoteHint,
                _ => l.composeHint,
              },
              hintStyle: const TextStyle(color: kTextMuted),
              filled: true,
              fillColor: kBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kAccent.withValues(alpha: 0.6)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                l.composeCounter(length, maxShortPostLength),
                style: TextStyle(
                  fontSize: 12,
                  color: tooLong ? kDanger : kTextMuted,
                ),
              ),
              const Spacer(),
              Text(
                l.composeTarget,
                style: const TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ],
          ),
          if (err != null) ...[
            const SizedBox(height: 14),
            ErrorPanel(message: err),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                (_sending || (length == 0 && _imageBytes == null) || tooLong)
                    ? null
                    : _publish,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(switch ((widget.parent, widget.quote)) {
                    (final String _, _) => l.composeReplyPublish,
                    (_, final String _) => l.composeQuotePublish,
                    _ => l.composePublish,
                  }),
          ),
          const SizedBox(height: 10),
          Text(
            l.composeNote,
            style: const TextStyle(color: kTextMuted, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// Says which authentication the session carries, and whether the homeserver
/// has already accepted it — checked before the user writes a word, so a
/// refusal never arrives after the effort of composing.
class _AccessBadge extends StatelessWidget {
  const _AccessBadge({required this.kind, required this.canWrite});

  final AuthKind kind;
  final bool? canWrite;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final (label, color) = switch (canWrite) {
      null => (l.composeAccessChecking, kTextMuted),
      true => (l.composeAccessOpen(kind.label), kAccent),
      false => (l.composeAccessDenied(kind.label), kDanger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11.5)),
    );
  }
}

/// What a quote is about to carry, shown while it is being written.
///
/// Deliberately flat — a name and the words, no images, no counters: the point
/// is to remember what you are answering, not to render the post twice.
class _QuotedPreview extends StatelessWidget {
  const _QuotedPreview({required this.post, required this.author});

  final PubkyPost post;
  final PubkyProfile? author;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final text = post.article?.title ?? post.content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.composeQuoting,
            style: const TextStyle(
              color: kTextMuted,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            PostCard.displayName(author, post.author, l),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          if (text.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: kTextMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposeAction extends StatelessWidget {
  const _ComposeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: kBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: onTap == null ? kTextMuted : kAccent),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: onTap == null ? kTextMuted : kText,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Search by display name, returning the chosen account key.
///
/// Nexus ranks the results and answers with keys only, so the profiles are
/// resolved in a second call — the list would otherwise show 52-character
/// strings, which nobody can pick from.
class _MentionPicker extends StatefulWidget {
  const _MentionPicker({required this.nexus});

  final NexusClient nexus;

  @override
  State<_MentionPicker> createState() => _MentionPickerState();
}

class _MentionPickerState extends State<_MentionPicker> {
  final _query = TextEditingController();
  List<PubkyProfile> _results = const [];
  bool _searching = false;
  int _generation = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String prefix) async {
    // Every keystroke starts a search; only the latest may paint. Otherwise a
    // slow early request lands after a fast later one and shows stale names.
    final generation = ++_generation;
    if (prefix.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final found = await widget.nexus.searchUsersByName(prefix);
      if (!mounted || generation != _generation) return;
      setState(() => _results = found);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _results = const []);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.composeMention,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            autofocus: true,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: l.composeMentionSearch,
              hintStyle: const TextStyle(color: kTextMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: kTextMuted),
              filled: true,
              fillColor: kBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_results.isEmpty && _query.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l.composeMentionNoResult,
                  style: const TextStyle(color: kTextMuted),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final profile = _results[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipOval(
                      child: Image.network(
                        profile.avatarUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person_rounded, color: kTextMuted),
                      ),
                    ),
                    title: Text(
                      profile.name.isEmpty ? l.profileNoName : profile.name,
                      style: const TextStyle(fontSize: 15),
                    ),
                    subtitle: Text(
                      profile.id.substring(0, 8) + String.fromCharCode(0x2026),
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 11.5,
                        fontFamily: "monospace",
                      ),
                    ),
                    onTap: () => Navigator.pop(context, profile),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Both languages, then an explicit button.
///
/// The first version translated the moment a target was tapped. Picking a
/// language from a list does not read as « go »: it reads as picking a
/// language, and nothing seemed to happen. So the sheet waits for a button.
class _LanguagePicker extends StatefulWidget {
  const _LanguagePicker({required this.defaultTarget});

  /// The interface language, offered as the target — the likeliest thing
  /// someone wants to translate a foreign draft into.
  final String defaultTarget;

  @override
  State<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<_LanguagePicker> {
  /// Detection happens server-side, so it costs nothing and is the default.
  String _from = autoDetect;
  late String _to = translationLanguages.containsKey(widget.defaultTarget)
      ? widget.defaultTarget
      : 'en';

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final same = _from == _to;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.composeTranslateTo,
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LanguageField(
                  label: l.composeTranslateFrom,
                  value: _from,
                  withAuto: true,
                  onChanged: (v) => setState(() => _from = v),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 18, color: kTextMuted),
              ),
              Expanded(
                child: _LanguageField(
                  label: l.composeTranslateTarget,
                  value: _to,
                  withAuto: false,
                  onChanged: (v) => setState(() => _to = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l.composeTranslateKeepsMentions,
            style: const TextStyle(
                color: kTextMuted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 8),
          Text(
            l.composeTranslateViaDeepL,
            style: const TextStyle(
                color: kTextMuted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: same
                ? null
                : () => Navigator.pop<TranslationChoice>(
                    context, (from: _from, to: _to)),
            icon: const Icon(Icons.translate_rounded, size: 18),
            label:
                Text(same ? l.composeTranslateSameLanguage : l.composeTranslate),
          ),
        ],
      ),
    );
  }
}

class _LanguageField extends StatelessWidget {
  const _LanguageField({
    required this.label,
    required this.value,
    required this.withAuto,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool withAuto;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kTextMuted, fontSize: 11.5)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: kBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: kSurface,
              style: const TextStyle(fontSize: 14.5, color: kText),
              items: [
                if (withAuto)
                  DropdownMenuItem(
                    value: autoDetect,
                    child: Text(l.composeTranslateAuto),
                  ),
                for (final entry in translationLanguages.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The chosen picture, with a way out.
///
/// Shown from the bytes already in memory rather than re-read from disk: they
/// are what will be hashed and uploaded, so this previews the actual thing
/// rather than a file that could differ.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.bytes,
    required this.name,
    required this.onRemove,
  });

  final Uint8List bytes;
  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final kb = (bytes.length / 1024).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Image.memory(
            bytes,
            width: double.infinity,
            height: 160,
            fit: BoxFit.cover,
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: Colors.white,
                tooltip: l.composeImageRemove,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$kb ko',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
