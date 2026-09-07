import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Flutky'**
  String get appTitle;

  /// No description provided for @connectTagline.
  ///
  /// In en, this message translates to:
  /// **'Proof of concept: sign in with your Pubky account through Pubky Ring, then see your profile.'**
  String get connectTagline;

  /// No description provided for @connectButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Pubky Ring'**
  String get connectButton;

  /// No description provided for @connectAltLink.
  ///
  /// In en, this message translates to:
  /// **'Try the other link format (session/)'**
  String get connectAltLink;

  /// No description provided for @connectLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Reading your profile from Nexus…'**
  String get connectLoadingProfile;

  /// No description provided for @connectSessionReceived.
  ///
  /// In en, this message translates to:
  /// **'Session received. Loading…'**
  String get connectSessionReceived;

  /// No description provided for @connectRetryProfile.
  ///
  /// In en, this message translates to:
  /// **'Retry loading the profile'**
  String get connectRetryProfile;

  /// No description provided for @howItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'What is about to happen'**
  String get howItWorksTitle;

  /// No description provided for @howItWorksStep1.
  ///
  /// In en, this message translates to:
  /// **'Flutky opens Pubky Ring through a pubkyring://session link.'**
  String get howItWorksStep1;

  /// No description provided for @howItWorksStep2.
  ///
  /// In en, this message translates to:
  /// **'Ring asks which pubky to use, then shows an approval screen.'**
  String get howItWorksStep2;

  /// No description provided for @howItWorksStep3.
  ///
  /// In en, this message translates to:
  /// **'Ring reopens Flutky, handing it your public key and a session secret.'**
  String get howItWorksStep3;

  /// No description provided for @howItWorksStep4.
  ///
  /// In en, this message translates to:
  /// **'Flutky reads your profile from Nexus, without authentication.'**
  String get howItWorksStep4;

  /// No description provided for @howItWorksSecret.
  ///
  /// In en, this message translates to:
  /// **'The session secret stays on the device. It is never displayed nor logged.'**
  String get howItWorksSecret;

  /// No description provided for @exchangeTitle.
  ///
  /// In en, this message translates to:
  /// **'EXCHANGE WITH RING'**
  String get exchangeTitle;

  /// No description provided for @exchangeSent.
  ///
  /// In en, this message translates to:
  /// **'SENT'**
  String get exchangeSent;

  /// No description provided for @exchangeReceived.
  ///
  /// In en, this message translates to:
  /// **'RECEIVED'**
  String get exchangeReceived;

  /// No description provided for @exchangeNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing received from Ring yet.'**
  String get exchangeNothingYet;

  /// No description provided for @exchangeCopied.
  ///
  /// In en, this message translates to:
  /// **'Exchange copied'**
  String get exchangeCopied;

  /// No description provided for @errorLinkUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Unreadable incoming link: {error}'**
  String errorLinkUnreadable(Object error);

  /// No description provided for @errorRingRefused.
  ///
  /// In en, this message translates to:
  /// **'Ring refused ({code}): {message}'**
  String errorRingRefused(Object code, Object message);

  /// No description provided for @errorRingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled in Pubky Ring.'**
  String get errorRingCancelled;

  /// No description provided for @errorRingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Ring did come back to Flutky, but without a public key or session secret. That is the signature of a link handled by something other than the session flow. The full detail is below.'**
  String get errorRingEmpty;

  /// No description provided for @errorRingUnreachable.
  ///
  /// In en, this message translates to:
  /// **'No app answered. Is Pubky Ring installed on this phone?'**
  String get errorRingUnreachable;

  /// No description provided for @errorRingOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Pubky Ring: {error}'**
  String errorRingOpenFailed(Object error);

  /// No description provided for @errorNotIndexed.
  ///
  /// In en, this message translates to:
  /// **'Nexus does not know this key yet. The indexer only learns about an account once it is wired into the social graph: post something or follow someone from pubky.app, then try again.'**
  String get errorNotIndexed;

  /// No description provided for @tabFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get tabFeed;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @tabNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get tabNotifications;

  /// No description provided for @titleFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get titleFeed;

  /// No description provided for @titleProfile.
  ///
  /// In en, this message translates to:
  /// **'My Pubky profile'**
  String get titleProfile;

  /// No description provided for @titleNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get titleNotifications;

  /// No description provided for @titleDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get titleDiagnostics;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// No description provided for @actionDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get actionDiagnostics;

  /// No description provided for @actionReportBug.
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get actionReportBug;

  /// No description provided for @actionRequestFeature.
  ///
  /// In en, this message translates to:
  /// **'Request a feature'**
  String get actionRequestFeature;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionSettings;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'The stored session will be erased from this phone. You will have to go through Pubky Ring again to come back.'**
  String get signOutBody;

  /// No description provided for @feedSourceFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get feedSourceFollowing;

  /// No description provided for @feedSourceFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get feedSourceFriends;

  /// No description provided for @feedSourceAll.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get feedSourceAll;

  /// No description provided for @feedSourceBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get feedSourceBookmarks;

  /// No description provided for @feedEmptyFollowing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show. This feed only covers accounts you follow — pull down to refresh, or switch to Global.'**
  String get feedEmptyFollowing;

  /// No description provided for @feedEmptyOther.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show in this feed.'**
  String get feedEmptyOther;

  /// No description provided for @feedComposeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Write a post'**
  String get feedComposeTooltip;

  /// No description provided for @feedPublished.
  ///
  /// In en, this message translates to:
  /// **'Published. The feed will show it once Nexus has indexed it.'**
  String get feedPublished;

  /// No description provided for @postPending.
  ///
  /// In en, this message translates to:
  /// **'posted just now · waiting to be indexed'**
  String get postPending;

  /// No description provided for @postRepostedLabel.
  ///
  /// In en, this message translates to:
  /// **'reposted'**
  String get postRepostedLabel;

  /// No description provided for @postQuotedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Original post unavailable'**
  String get postQuotedUnavailable;

  /// No description provided for @postLoadingQuoted.
  ///
  /// In en, this message translates to:
  /// **'Loading the original post…'**
  String get postLoadingQuoted;

  /// No description provided for @postReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'replying to'**
  String get postReplyingTo;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String timeMinutes(int count);

  /// No description provided for @timeHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String timeHours(int count);

  /// No description provided for @timeDays.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String timeDays(int count);

  /// No description provided for @composeTitle.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get composeTitle;

  /// No description provided for @composeHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening?'**
  String get composeHint;

  /// No description provided for @composeCounter.
  ///
  /// In en, this message translates to:
  /// **'{used} / {max}'**
  String composeCounter(int used, int max);

  /// No description provided for @composeTarget.
  ///
  /// In en, this message translates to:
  /// **'Posted to your homeserver'**
  String get composeTarget;

  /// No description provided for @composePublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get composePublish;

  /// No description provided for @composeNote.
  ///
  /// In en, this message translates to:
  /// **'The post reaches your homeserver immediately. When it shows up in the feed depends on the indexer, which always lags a little.'**
  String get composeNote;

  /// No description provided for @composeAccessChecking.
  ///
  /// In en, this message translates to:
  /// **'checking…'**
  String get composeAccessChecking;

  /// No description provided for @composeAccessOpen.
  ///
  /// In en, this message translates to:
  /// **'{kind} · writing allowed'**
  String composeAccessOpen(Object kind);

  /// No description provided for @composeAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'{kind} · writing refused'**
  String composeAccessDenied(Object kind);

  /// No description provided for @composeEmpty.
  ///
  /// In en, this message translates to:
  /// **'An empty post cannot be published.'**
  String get composeEmpty;

  /// No description provided for @composeTooLong.
  ///
  /// In en, this message translates to:
  /// **'A short post is limited to {max} characters ({used} here).'**
  String composeTooLong(int max, int used);

  /// No description provided for @composeWrittenButMissing.
  ///
  /// In en, this message translates to:
  /// **'written, but not found when read back'**
  String get composeWrittenButMissing;

  /// No description provided for @profileBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBio;

  /// No description provided for @profilePublicKey.
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get profilePublicKey;

  /// No description provided for @profileActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get profileActivity;

  /// No description provided for @profileLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get profileLinks;

  /// No description provided for @profileTags.
  ///
  /// In en, this message translates to:
  /// **'Tags received'**
  String get profileTags;

  /// No description provided for @profileSession.
  ///
  /// In en, this message translates to:
  /// **'Ring session'**
  String get profileSession;

  /// No description provided for @profileKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Key copied'**
  String get profileKeyCopied;

  /// No description provided for @profileNoName.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get profileNoName;

  /// No description provided for @profileSecretReceived.
  ///
  /// In en, this message translates to:
  /// **'Secret received'**
  String get profileSecretReceived;

  /// No description provided for @profileSecretLength.
  ///
  /// In en, this message translates to:
  /// **'{count} characters (not shown)'**
  String profileSecretLength(int count);

  /// No description provided for @profileCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get profileCapabilities;

  /// No description provided for @profileNoCapabilities.
  ///
  /// In en, this message translates to:
  /// **'none advertised'**
  String get profileNoCapabilities;

  /// No description provided for @profileIndexedOn.
  ///
  /// In en, this message translates to:
  /// **'Indexed on'**
  String get profileIndexedOn;

  /// No description provided for @profileSessionWarning.
  ///
  /// In en, this message translates to:
  /// **'The session secret is as good as a password: this proof of concept keeps it in the platform keystore and never shows it.'**
  String get profileSessionWarning;

  /// No description provided for @countPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get countPosts;

  /// No description provided for @countReplies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get countReplies;

  /// No description provided for @countFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get countFollowers;

  /// No description provided for @countFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get countFollowing;

  /// No description provided for @countFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get countFriends;

  /// No description provided for @countTagged.
  ///
  /// In en, this message translates to:
  /// **'Times tagged'**
  String get countTagged;

  /// No description provided for @countUniqueTags.
  ///
  /// In en, this message translates to:
  /// **'Distinct tags'**
  String get countUniqueTags;

  /// No description provided for @countBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get countBookmarks;

  /// No description provided for @countCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get countCollections;

  /// No description provided for @notifFollow.
  ///
  /// In en, this message translates to:
  /// **'{who} followed you'**
  String notifFollow(Object who);

  /// No description provided for @notifNewFriend.
  ///
  /// In en, this message translates to:
  /// **'{who} follows you back — you are now friends'**
  String notifNewFriend(Object who);

  /// No description provided for @notifLostFriend.
  ///
  /// In en, this message translates to:
  /// **'{who} unfollowed you'**
  String notifLostFriend(Object who);

  /// No description provided for @notifTagPost.
  ///
  /// In en, this message translates to:
  /// **'{who} tagged your post “{label}”'**
  String notifTagPost(Object who, Object label);

  /// No description provided for @notifTagProfile.
  ///
  /// In en, this message translates to:
  /// **'{who} tagged your profile “{label}”'**
  String notifTagProfile(Object who, Object label);

  /// No description provided for @notifUntagPost.
  ///
  /// In en, this message translates to:
  /// **'{who} removed the tag “{label}” from your post'**
  String notifUntagPost(Object who, Object label);

  /// No description provided for @notifUntagProfile.
  ///
  /// In en, this message translates to:
  /// **'{who} removed the tag “{label}” from your profile'**
  String notifUntagProfile(Object who, Object label);

  /// No description provided for @notifReply.
  ///
  /// In en, this message translates to:
  /// **'{who} replied to your post'**
  String notifReply(Object who);

  /// No description provided for @notifRepost.
  ///
  /// In en, this message translates to:
  /// **'{who} reposted your post'**
  String notifRepost(Object who);

  /// No description provided for @notifMention.
  ///
  /// In en, this message translates to:
  /// **'{who} mentioned you'**
  String notifMention(Object who);

  /// No description provided for @notifPostDeleted.
  ///
  /// In en, this message translates to:
  /// **'{who} deleted a post you were involved in'**
  String notifPostDeleted(Object who);

  /// No description provided for @notifPostEdited.
  ///
  /// In en, this message translates to:
  /// **'{who} edited a post you were involved in'**
  String notifPostEdited(Object who);

  /// No description provided for @notifUnknown.
  ///
  /// In en, this message translates to:
  /// **'Notification of an unrecognised kind ({type})'**
  String notifUnknown(Object type);

  /// No description provided for @notifEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications. They arrive when someone follows you, tags you, replies to you or reposts you.'**
  String get notifEmpty;

  /// No description provided for @notifSomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get notifSomeone;

  /// No description provided for @diagSecretSection.
  ///
  /// In en, this message translates to:
  /// **'SESSION SECRET'**
  String get diagSecretSection;

  /// No description provided for @diagLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get diagLength;

  /// No description provided for @diagDetectedType.
  ///
  /// In en, this message translates to:
  /// **'Detected type'**
  String get diagDetectedType;

  /// No description provided for @diagShape.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get diagShape;

  /// No description provided for @diagCookieValue.
  ///
  /// In en, this message translates to:
  /// **'Cookie value'**
  String get diagCookieValue;

  /// No description provided for @diagSegments.
  ///
  /// In en, this message translates to:
  /// **'Segments (:)'**
  String get diagSegments;

  /// No description provided for @diagNeverShown.
  ///
  /// In en, this message translates to:
  /// **'The secret itself is never displayed nor copied.'**
  String get diagNeverShown;

  /// No description provided for @diagCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied'**
  String get diagCopied;

  /// No description provided for @diagCopyReport.
  ///
  /// In en, this message translates to:
  /// **'Copy the report'**
  String get diagCopyReport;

  /// No description provided for @diagRerun.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get diagRerun;

  /// No description provided for @diagFootnote.
  ///
  /// In en, this message translates to:
  /// **'The homeserver answers 401 even for a route that does not exist: authentication runs before routing. A lone 401 therefore proves nothing. The two controls at the top use no authentication at all — they are what give the others meaning: if they pass, the address and the network are fine, and a refusal below really is about the session.'**
  String get diagFootnote;

  /// No description provided for @diagFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get diagFailed;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get settingsLanguageFrench;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get settingsSourceCode;

  /// No description provided for @settingsLicense.
  ///
  /// In en, this message translates to:
  /// **'MIT licence'**
  String get settingsLicense;

  /// No description provided for @articleUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled article'**
  String get articleUntitled;

  /// No description provided for @articleReadOn.
  ///
  /// In en, this message translates to:
  /// **'Read the full article on pubky.app'**
  String get articleReadOn;

  /// No description provided for @actionFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get actionFollow;

  /// No description provided for @actionUnfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get actionUnfollow;

  /// No description provided for @followFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the follow: {error}'**
  String followFailed(Object error);

  /// No description provided for @settingsFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get settingsFeed;

  /// No description provided for @settingsIncludeOwnPosts.
  ///
  /// In en, this message translates to:
  /// **'Include my own posts'**
  String get settingsIncludeOwnPosts;

  /// No description provided for @settingsIncludeOwnPostsNote.
  ///
  /// In en, this message translates to:
  /// **'The Following feed covers the accounts you follow, not you. Turn this on to see your own posts among theirs.'**
  String get settingsIncludeOwnPostsNote;

  /// No description provided for @composeAskJeb.
  ///
  /// In en, this message translates to:
  /// **'Ask Jeb'**
  String get composeAskJeb;

  /// No description provided for @composeAskJebNote.
  ///
  /// In en, this message translates to:
  /// **'Jeb is an AI account on Pubky. Mention it in a post and its reply shows up in your feed.'**
  String get composeAskJebNote;

  /// No description provided for @composeMention.
  ///
  /// In en, this message translates to:
  /// **'Mention someone'**
  String get composeMention;

  /// No description provided for @composeMentionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name…'**
  String get composeMentionSearch;

  /// No description provided for @composeMentionNoResult.
  ///
  /// In en, this message translates to:
  /// **'Nobody found'**
  String get composeMentionNoResult;

  /// No description provided for @composeMentionAdded.
  ///
  /// In en, this message translates to:
  /// **'Mention added'**
  String get composeMentionAdded;

  /// No description provided for @composeTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get composeTranslate;

  /// No description provided for @composeTranslateTo.
  ///
  /// In en, this message translates to:
  /// **'Translate into'**
  String get composeTranslateTo;

  /// No description provided for @composeTranslating.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get composeTranslating;

  /// No description provided for @composeTranslateFirstUse.
  ///
  /// In en, this message translates to:
  /// **'The first translation into a language downloads its model, about 30 MB. It then works offline.'**
  String get composeTranslateFirstUse;

  /// No description provided for @composeTranslateFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation failed: {error}'**
  String composeTranslateFailed(Object error);

  /// No description provided for @composeTranslateUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get composeTranslateUndo;

  /// No description provided for @composeTranslateDone.
  ///
  /// In en, this message translates to:
  /// **'Translated — tap Undo to get your text back'**
  String get composeTranslateDone;

  /// No description provided for @composeTranslateNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to translate yet'**
  String get composeTranslateNothing;

  /// No description provided for @tabMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get tabMessages;

  /// No description provided for @titleMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get titleMessages;

  /// No description provided for @messagesWipTitle.
  ///
  /// In en, this message translates to:
  /// **'Private messaging is not built yet'**
  String get messagesWipTitle;

  /// No description provided for @messagesWipBody.
  ///
  /// In en, this message translates to:
  /// **'Pubky has an encrypted peer-to-peer protocol, pubky-noise: each side writes to their own homeserver and reads the other\'s, so no extra server is involved. It is still a release candidate and exists only as a Rust library, so it has to be ported before anything can be shown here.'**
  String get messagesWipBody;

  /// No description provided for @messagesWipFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow the work'**
  String get messagesWipFollow;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'fr':
      return L10nFr();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
