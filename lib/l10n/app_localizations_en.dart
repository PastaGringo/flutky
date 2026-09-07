// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flutky';

  @override
  String get connectTagline =>
      'Proof of concept: sign in with your Pubky account through Pubky Ring, then see your profile.';

  @override
  String get connectButton => 'Sign in with Pubky Ring';

  @override
  String get connectAltLink => 'Try the other link format (session/)';

  @override
  String get connectLoadingProfile => 'Reading your profile from Nexus…';

  @override
  String get connectSessionReceived => 'Session received. Loading…';

  @override
  String get connectRetryProfile => 'Retry loading the profile';

  @override
  String get howItWorksTitle => 'What is about to happen';

  @override
  String get howItWorksStep1 =>
      'Flutky opens Pubky Ring through a pubkyring://session link.';

  @override
  String get howItWorksStep2 =>
      'Ring asks which pubky to use, then shows an approval screen.';

  @override
  String get howItWorksStep3 =>
      'Ring reopens Flutky, handing it your public key and a session secret.';

  @override
  String get howItWorksStep4 =>
      'Flutky reads your profile from Nexus, without authentication.';

  @override
  String get howItWorksSecret =>
      'The session secret stays on the device. It is never displayed nor logged.';

  @override
  String get exchangeTitle => 'EXCHANGE WITH RING';

  @override
  String get exchangeSent => 'SENT';

  @override
  String get exchangeReceived => 'RECEIVED';

  @override
  String get exchangeNothingYet => 'Nothing received from Ring yet.';

  @override
  String get exchangeCopied => 'Exchange copied';

  @override
  String errorLinkUnreadable(Object error) {
    return 'Unreadable incoming link: $error';
  }

  @override
  String errorRingRefused(Object code, Object message) {
    return 'Ring refused ($code): $message';
  }

  @override
  String get errorRingCancelled => 'Sign-in cancelled in Pubky Ring.';

  @override
  String get errorRingEmpty =>
      'Ring did come back to Flutky, but without a public key or session secret. That is the signature of a link handled by something other than the session flow. The full detail is below.';

  @override
  String get errorRingUnreachable =>
      'No app answered. Is Pubky Ring installed on this phone?';

  @override
  String errorRingOpenFailed(Object error) {
    return 'Could not open Pubky Ring: $error';
  }

  @override
  String get errorNotIndexed =>
      'Nexus does not know this key yet. The indexer only learns about an account once it is wired into the social graph: post something or follow someone from pubky.app, then try again.';

  @override
  String get tabFeed => 'Feed';

  @override
  String get tabProfile => 'Profile';

  @override
  String get tabNotifications => 'Notifications';

  @override
  String get titleFeed => 'Feed';

  @override
  String get titleProfile => 'My Pubky profile';

  @override
  String get titleNotifications => 'Notifications';

  @override
  String get titleDiagnostics => 'Diagnostics';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get actionDiagnostics => 'Diagnostics';

  @override
  String get actionReportBug => 'Report a bug';

  @override
  String get actionRequestFeature => 'Request a feature';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionSettings => 'Settings';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutBody =>
      'The stored session will be erased from this phone. You will have to go through Pubky Ring again to come back.';

  @override
  String get feedSourceFollowing => 'Following';

  @override
  String get feedSourceFriends => 'Friends';

  @override
  String get feedSourceAll => 'Global';

  @override
  String get feedSourceBookmarks => 'Bookmarks';

  @override
  String get feedEmptyFollowing =>
      'Nothing to show. This feed only covers accounts you follow — pull down to refresh, or switch to Global.';

  @override
  String get feedEmptyOther => 'Nothing to show in this feed.';

  @override
  String get feedComposeTooltip => 'Write a post';

  @override
  String get feedPublished =>
      'Published. The feed will show it once Nexus has indexed it.';

  @override
  String get postPending => 'posted just now · waiting to be indexed';

  @override
  String get postRepostedLabel => 'reposted';

  @override
  String get postQuotedUnavailable => 'Original post unavailable';

  @override
  String get postLoadingQuoted => 'Loading the original post…';

  @override
  String get postReplyingTo => 'replying to';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutes(int count) {
    return '$count min ago';
  }

  @override
  String timeHours(int count) {
    return '$count h ago';
  }

  @override
  String timeDays(int count) {
    return '$count d ago';
  }

  @override
  String get composeTitle => 'New post';

  @override
  String get composeHint => 'What\'s happening?';

  @override
  String composeCounter(int used, int max) {
    return '$used / $max';
  }

  @override
  String get composeTarget => 'Posted to your homeserver';

  @override
  String get composePublish => 'Publish';

  @override
  String get composeNote =>
      'The post reaches your homeserver immediately. When it shows up in the feed depends on the indexer, which always lags a little.';

  @override
  String get composeAccessChecking => 'checking…';

  @override
  String composeAccessOpen(Object kind) {
    return '$kind · writing allowed';
  }

  @override
  String composeAccessDenied(Object kind) {
    return '$kind · writing refused';
  }

  @override
  String get composeEmpty => 'An empty post cannot be published.';

  @override
  String composeTooLong(int max, int used) {
    return 'A short post is limited to $max characters ($used here).';
  }

  @override
  String get composeWrittenButMissing =>
      'written, but not found when read back';

  @override
  String get profileBio => 'Bio';

  @override
  String get profilePublicKey => 'Public key';

  @override
  String get profileActivity => 'Activity';

  @override
  String get profileLinks => 'Links';

  @override
  String get profileTags => 'Tags received';

  @override
  String get profileSession => 'Ring session';

  @override
  String get profileKeyCopied => 'Key copied';

  @override
  String get profileNoName => 'No name';

  @override
  String get profileSecretReceived => 'Secret received';

  @override
  String profileSecretLength(int count) {
    return '$count characters (not shown)';
  }

  @override
  String get profileCapabilities => 'Capabilities';

  @override
  String get profileNoCapabilities => 'none advertised';

  @override
  String get profileIndexedOn => 'Indexed on';

  @override
  String get profileSessionWarning =>
      'The session secret is as good as a password: this proof of concept keeps it in the platform keystore and never shows it.';

  @override
  String get countPosts => 'Posts';

  @override
  String get countReplies => 'Replies';

  @override
  String get countFollowers => 'Followers';

  @override
  String get countFollowing => 'Following';

  @override
  String get countFriends => 'Friends';

  @override
  String get countTagged => 'Times tagged';

  @override
  String get countUniqueTags => 'Distinct tags';

  @override
  String get countBookmarks => 'Bookmarks';

  @override
  String get countCollections => 'Collections';

  @override
  String notifFollow(Object who) {
    return '$who followed you';
  }

  @override
  String notifNewFriend(Object who) {
    return '$who follows you back — you are now friends';
  }

  @override
  String notifLostFriend(Object who) {
    return '$who unfollowed you';
  }

  @override
  String notifTagPost(Object who, Object label) {
    return '$who tagged your post “$label”';
  }

  @override
  String notifTagProfile(Object who, Object label) {
    return '$who tagged your profile “$label”';
  }

  @override
  String notifUntagPost(Object who, Object label) {
    return '$who removed the tag “$label” from your post';
  }

  @override
  String notifUntagProfile(Object who, Object label) {
    return '$who removed the tag “$label” from your profile';
  }

  @override
  String notifReply(Object who) {
    return '$who replied to your post';
  }

  @override
  String notifRepost(Object who) {
    return '$who reposted your post';
  }

  @override
  String notifMention(Object who) {
    return '$who mentioned you';
  }

  @override
  String notifPostDeleted(Object who) {
    return '$who deleted a post you were involved in';
  }

  @override
  String notifPostEdited(Object who) {
    return '$who edited a post you were involved in';
  }

  @override
  String notifUnknown(Object type) {
    return 'Notification of an unrecognised kind ($type)';
  }

  @override
  String get notifEmpty =>
      'No notifications. They arrive when someone follows you, tags you, replies to you or reposts you.';

  @override
  String get notifSomeone => 'Someone';

  @override
  String get diagSecretSection => 'SESSION SECRET';

  @override
  String get diagLength => 'Length';

  @override
  String get diagDetectedType => 'Detected type';

  @override
  String get diagShape => 'Shape';

  @override
  String get diagCookieValue => 'Cookie value';

  @override
  String get diagSegments => 'Segments (:)';

  @override
  String get diagNeverShown =>
      'The secret itself is never displayed nor copied.';

  @override
  String get diagCopied => 'Diagnostics copied';

  @override
  String get diagCopyReport => 'Copy the report';

  @override
  String get diagRerun => 'Run again';

  @override
  String get diagFootnote =>
      'The homeserver answers 401 even for a route that does not exist: authentication runs before routing. A lone 401 therefore proves nothing. The two controls at the top use no authentication at all — they are what give the others meaning: if they pass, the address and the network are fine, and a refusal below really is about the session.';

  @override
  String get diagFailed => 'failed';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsSourceCode => 'Source code';

  @override
  String get settingsLicense => 'MIT licence';

  @override
  String get articleUntitled => 'Untitled article';

  @override
  String get articleReadOn => 'Read the full article on pubky.app';

  @override
  String get actionFollow => 'Follow';

  @override
  String get actionUnfollow => 'Unfollow';

  @override
  String followFailed(Object error) {
    return 'Could not update the follow: $error';
  }

  @override
  String get settingsFeed => 'Feed';

  @override
  String get settingsIncludeOwnPosts => 'Include my own posts';

  @override
  String get settingsIncludeOwnPostsNote =>
      'The Following feed covers the accounts you follow, not you. Turn this on to see your own posts among theirs.';

  @override
  String get composeAskJeb => 'Ask Jeb';

  @override
  String get composeAskJebNote =>
      'Jeb is an AI account on Pubky. Mention it in a post and its reply shows up in your feed.';

  @override
  String get composeMention => 'Mention someone';

  @override
  String get composeMentionSearch => 'Search by name…';

  @override
  String get composeMentionNoResult => 'Nobody found';

  @override
  String get composeMentionAdded => 'Mention added';

  @override
  String get composeTranslate => 'Translate';

  @override
  String get composeTranslateTo => 'Translate into';

  @override
  String get composeTranslating => 'Translating…';

  @override
  String composeTranslateFailed(Object error) {
    return 'Translation failed: $error';
  }

  @override
  String get composeTranslateUndo => 'Undo';

  @override
  String get composeTranslateNothing => 'Nothing to translate yet';

  @override
  String get tabMessages => 'Messages';

  @override
  String get titleMessages => 'Messages';

  @override
  String get messagesWipTitle => 'Private messaging is not built yet';

  @override
  String get messagesWipBody =>
      'Pubky has an encrypted peer-to-peer protocol, pubky-noise: each side writes to their own homeserver and reads the other\'s, so no extra server is involved. It is still a release candidate and exists only as a Rust library, so it has to be ported before anything can be shown here.';

  @override
  String get messagesWipFollow => 'Follow the work';

  @override
  String get tabDiscover => 'Discover';

  @override
  String get titleDiscover => 'Discover';

  @override
  String get discoverPopular => 'Popular';

  @override
  String get discoverPeople => 'PEOPLE TO DISCOVER';

  @override
  String get discoverEmpty =>
      'Nothing to show right now. Pull down to try again.';

  @override
  String discoverEmptyTag(String tag) {
    return 'Nothing carries #$tag yet.';
  }

  @override
  String get composeTranslateFrom => 'From';

  @override
  String get composeTranslateTarget => 'To';

  @override
  String get composeTranslateSameLanguage => 'Pick two different languages';

  @override
  String get composeTranslateKeepsMentions =>
      'Mentions and links are left untouched — a translated key would no longer notify anyone.';

  @override
  String get composeTranslateAuto => 'Detect automatically';

  @override
  String get composeTranslateQuota =>
      'The DeepL key has spent its monthly allowance. It resets with the billing month.';

  @override
  String get settingsTranslation => 'Translation';

  @override
  String get composeTranslateWorking => 'Translating…';

  @override
  String get composeTranslateBadKey =>
      'DeepL refused the key. Check it in Settings, or clear it to fall back to the keyless service.';

  @override
  String get composeTranslateViaDeepL =>
      'Translated by DeepL with your key — the draft leaves the phone.';

  @override
  String get settingsDeepLKey => 'DeepL API key (optional)';

  @override
  String get settingsDeepLKeyHint => '…:fx for a free key';

  @override
  String get settingsDeepLKeyNote =>
      'Translation needs a key. DeepL\'s free plan covers 500,000 characters a month; a free key ends in “:fx”. Without one, the translate button says so instead of failing.';

  @override
  String get settingsDeepLChecking => 'Checking the key…';

  @override
  String settingsDeepLValid(String used, String limit) {
    return 'Key accepted — $used of $limit characters used.';
  }

  @override
  String get settingsDeepLInvalid => 'DeepL refused this key.';

  @override
  String get composeTranslateNoKey =>
      'Translation needs a DeepL key. Add one in Settings — the free plan covers 500,000 characters a month.';

  @override
  String get postTitle => 'Post';

  @override
  String get postLoading => 'Loading…';

  @override
  String get postGone =>
      'This post is not in the index — it may have been deleted.';

  @override
  String get postInReplyTo => 'IN REPLY TO';

  @override
  String get postNoReplies => 'NO REPLIES YET';

  @override
  String postReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count REPLIES',
      one: '1 REPLY',
    );
    return '$_temp0';
  }

  @override
  String get composeImage => 'Picture';

  @override
  String get composeImageRemove => 'Remove the picture';

  @override
  String get composeUploading => 'Sending the picture…';
}
