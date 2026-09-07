// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Flutky';

  @override
  String get connectTagline =>
      'Preuve de concept : se connecter avec son compte Pubky via Pubky Ring, puis afficher son profil.';

  @override
  String get connectButton => 'Se connecter avec Pubky Ring';

  @override
  String get connectAltLink => 'Essayer l\'autre format de lien (session/)';

  @override
  String get connectLoadingProfile => 'Lecture du profil chez Nexus…';

  @override
  String get connectSessionReceived => 'Session reçue. Chargement…';

  @override
  String get connectRetryProfile => 'Réessayer la lecture du profil';

  @override
  String get howItWorksTitle => 'Ce qui va se passer';

  @override
  String get howItWorksStep1 =>
      'Flutky ouvre Pubky Ring par un lien pubkyring://session.';

  @override
  String get howItWorksStep2 =>
      'Ring demande quel pubky utiliser, puis affiche un écran d\'approbation.';

  @override
  String get howItWorksStep3 =>
      'Ring rouvre Flutky en lui passant la clé publique et un secret de session.';

  @override
  String get howItWorksStep4 =>
      'Flutky lit le profil chez Nexus, sans authentification.';

  @override
  String get howItWorksSecret =>
      'Le secret de session reste sur l\'appareil. Il n\'est ni affiché ni journalisé.';

  @override
  String get exchangeTitle => 'ÉCHANGE AVEC RING';

  @override
  String get exchangeSent => 'ENVOYÉ';

  @override
  String get exchangeReceived => 'REÇU';

  @override
  String get exchangeNothingYet => 'Rien reçu de Ring pour l\'instant.';

  @override
  String get exchangeCopied => 'Échange copié';

  @override
  String errorLinkUnreadable(Object error) {
    return 'Lien entrant illisible : $error';
  }

  @override
  String errorRingRefused(Object code, Object message) {
    return 'Ring a refusé ($code) : $message';
  }

  @override
  String get errorRingCancelled => 'Connexion annulée dans Pubky Ring.';

  @override
  String get errorRingEmpty =>
      'Ring est bien revenu vers Flutky, mais sans clé publique ni secret de session. C\'est la signature d\'un lien traité par un autre chemin que celui de la session. Le détail complet est ci-dessous.';

  @override
  String get errorRingUnreachable =>
      'Aucune application n\'a répondu. Pubky Ring est-il installé sur ce téléphone ?';

  @override
  String errorRingOpenFailed(Object error) {
    return 'Impossible d\'ouvrir Pubky Ring : $error';
  }

  @override
  String get errorNotIndexed =>
      'Nexus ne connaît pas encore cette clé. L\'indexeur n\'apprend l\'existence d\'un compte qu\'une fois relié au graphe social : publie un message ou suis quelqu\'un depuis pubky.app, puis réessaie.';

  @override
  String get tabFeed => 'Flux';

  @override
  String get tabProfile => 'Profil';

  @override
  String get tabNotifications => 'Notifications';

  @override
  String get titleFeed => 'Flux';

  @override
  String get titleProfile => 'Mon profil Pubky';

  @override
  String get titleNotifications => 'Notifications';

  @override
  String get titleDiagnostics => 'Diagnostic';

  @override
  String get actionRefresh => 'Recharger';

  @override
  String get actionSignOut => 'Se déconnecter';

  @override
  String get actionDiagnostics => 'Diagnostic';

  @override
  String get actionReportBug => 'Signaler un bug';

  @override
  String get actionRequestFeature => 'Proposer une fonctionnalité';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get actionCopy => 'Copier';

  @override
  String get actionSettings => 'Réglages';

  @override
  String get signOutTitle => 'Se déconnecter ?';

  @override
  String get signOutBody =>
      'La session enregistrée sera effacée de ce téléphone. Il faudra repasser par Pubky Ring pour revenir.';

  @override
  String get feedSourceFollowing => 'Abonnements';

  @override
  String get feedSourceFriends => 'Amis';

  @override
  String get feedSourceAll => 'Global';

  @override
  String get feedSourceBookmarks => 'Favoris';

  @override
  String get feedEmptyFollowing =>
      'Rien à afficher. Ce flux ne montre que les comptes que tu suis — tire vers le bas pour recharger, ou passe sur « Global ».';

  @override
  String get feedEmptyOther => 'Rien à afficher pour ce flux.';

  @override
  String get feedComposeTooltip => 'Écrire un post';

  @override
  String get feedPublished =>
      'Publié. Le flux le montrera dès que Nexus aura indexé.';

  @override
  String get postPending => 'publié à l\'instant · en attente d\'indexation';

  @override
  String get postRepostedLabel => 'a repartagé';

  @override
  String get postQuotedUnavailable => 'Post d\'origine indisponible';

  @override
  String get postLoadingQuoted => 'Chargement du post d\'origine…';

  @override
  String get postReplyingTo => 'en réponse à';

  @override
  String get timeJustNow => 'à l\'instant';

  @override
  String timeMinutes(int count) {
    return 'il y a $count min';
  }

  @override
  String timeHours(int count) {
    return 'il y a $count h';
  }

  @override
  String timeDays(int count) {
    return 'il y a $count j';
  }

  @override
  String get composeTitle => 'Nouveau post';

  @override
  String get composeHint => 'Quoi de neuf ?';

  @override
  String composeCounter(int used, int max) {
    return '$used / $max';
  }

  @override
  String get composeTarget => 'Publié sur ton homeserver';

  @override
  String get composePublish => 'Publier';

  @override
  String get composeNote =>
      'Le post part sur le homeserver tout de suite. Son apparition dans le flux dépend de l\'indexeur, qui a toujours un peu de retard.';

  @override
  String get composeAccessChecking => 'vérification…';

  @override
  String composeAccessOpen(Object kind) {
    return '$kind · écriture ouverte';
  }

  @override
  String composeAccessDenied(Object kind) {
    return '$kind · écriture refusée';
  }

  @override
  String get composeEmpty => 'Un post vide ne peut pas être publié.';

  @override
  String composeTooLong(int max, int used) {
    return 'Un post court est limité à $max caractères ($used ici).';
  }

  @override
  String get composeWrittenButMissing =>
      'écrit, mais introuvable à la relecture';

  @override
  String get profileBio => 'Bio';

  @override
  String get profilePublicKey => 'Clé publique';

  @override
  String get profileActivity => 'Activité';

  @override
  String get profileLinks => 'Liens';

  @override
  String get profileTags => 'Tags reçus';

  @override
  String get profileSession => 'Session Ring';

  @override
  String get profileKeyCopied => 'Clé copiée';

  @override
  String get profileNoName => 'Sans nom';

  @override
  String get profileSecretReceived => 'Secret reçu';

  @override
  String profileSecretLength(int count) {
    return '$count caractères (non affiché)';
  }

  @override
  String get profileCapabilities => 'Capacités';

  @override
  String get profileNoCapabilities => 'aucune annoncée';

  @override
  String get profileIndexedOn => 'Indexé le';

  @override
  String get profileSessionWarning =>
      'Le secret de session vaut mot de passe : cette preuve de concept le garde dans le keystore de la plateforme et ne l\'affiche jamais.';

  @override
  String get countPosts => 'Publications';

  @override
  String get countReplies => 'Réponses';

  @override
  String get countFollowers => 'Abonnés';

  @override
  String get countFollowing => 'Abonnements';

  @override
  String get countFriends => 'Amis';

  @override
  String get countTagged => 'Fois taggé';

  @override
  String get countUniqueTags => 'Tags distincts';

  @override
  String get countBookmarks => 'Favoris';

  @override
  String get countCollections => 'Collections';

  @override
  String notifFollow(Object who) {
    return '$who s\'est abonné à toi';
  }

  @override
  String notifNewFriend(Object who) {
    return '$who s\'est abonné en retour — vous êtes amis';
  }

  @override
  String notifLostFriend(Object who) {
    return '$who s\'est désabonné';
  }

  @override
  String notifTagPost(Object who, Object label) {
    return '$who a taggé ton post « $label »';
  }

  @override
  String notifTagProfile(Object who, Object label) {
    return '$who a taggé ton profil « $label »';
  }

  @override
  String notifUntagPost(Object who, Object label) {
    return '$who a retiré le tag « $label » de ton post';
  }

  @override
  String notifUntagProfile(Object who, Object label) {
    return '$who a retiré le tag « $label » de ton profil';
  }

  @override
  String notifReply(Object who) {
    return '$who a répondu à ton post';
  }

  @override
  String notifRepost(Object who) {
    return '$who a repartagé ton post';
  }

  @override
  String notifMention(Object who) {
    return '$who t\'a mentionné';
  }

  @override
  String notifPostDeleted(Object who) {
    return '$who a supprimé un post qui te concernait';
  }

  @override
  String notifPostEdited(Object who) {
    return '$who a modifié un post qui te concernait';
  }

  @override
  String notifUnknown(Object type) {
    return 'Notification d\'un type non reconnu ($type)';
  }

  @override
  String get notifEmpty =>
      'Aucune notification. Elles arrivent quand quelqu\'un s\'abonne, te tague, te répond ou te repartage.';

  @override
  String get notifSomeone => 'Quelqu\'un';

  @override
  String get diagSecretSection => 'SECRET DE SESSION';

  @override
  String get diagLength => 'Longueur';

  @override
  String get diagDetectedType => 'Type détecté';

  @override
  String get diagShape => 'Forme';

  @override
  String get diagCookieValue => 'Valeur du cookie';

  @override
  String get diagSegments => 'Segments (:)';

  @override
  String get diagNeverShown =>
      'La valeur du secret n\'est jamais affichée ni copiée.';

  @override
  String get diagCopied => 'Diagnostic copié';

  @override
  String get diagCopyReport => 'Copier le rapport';

  @override
  String get diagRerun => 'Relancer';

  @override
  String get diagFootnote =>
      'Le homeserver répond 401 même sur une route inexistante : l\'authentification passe avant le routage. Un 401 isolé ne prouve donc rien. Ce sont les deux témoins du haut — qui n\'utilisent aucune authentification — qui donnent leur sens aux autres : s\'ils passent, l\'adresse et le réseau sont bons, et un refus plus bas concerne bien la session.';

  @override
  String get diagFailed => 'échec';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Système';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsSourceCode => 'Code source';

  @override
  String get settingsLicense => 'Licence MIT';

  @override
  String get articleUntitled => 'Article sans titre';

  @override
  String get articleReadOn => 'Lire l\'article entier sur pubky.app';

  @override
  String get actionFollow => 'Suivre';

  @override
  String get actionUnfollow => 'Ne plus suivre';

  @override
  String followFailed(Object error) {
    return 'Impossible de modifier l\'abonnement : $error';
  }

  @override
  String get settingsFeed => 'Flux';

  @override
  String get settingsIncludeOwnPosts => 'Inclure mes propres posts';

  @override
  String get settingsIncludeOwnPostsNote =>
      'Le flux Abonnements montre les comptes que tu suis, pas toi. Active ceci pour voir tes posts parmi les leurs.';

  @override
  String get composeAskJeb => 'Demander à Jeb';

  @override
  String get composeAskJebNote =>
      'Jeb est un compte IA sur Pubky. Mentionne-le dans un post et sa réponse apparaîtra dans ton flux.';

  @override
  String get composeMention => 'Mentionner quelqu\'un';

  @override
  String get composeMentionSearch => 'Chercher par nom…';

  @override
  String get composeMentionNoResult => 'Personne trouvée';

  @override
  String get composeMentionAdded => 'Mention ajoutée';

  @override
  String get composeTranslate => 'Traduire';

  @override
  String get composeTranslateTo => 'Traduire en';

  @override
  String get composeTranslating => 'Traduction…';

  @override
  String composeTranslateFailed(Object error) {
    return 'Échec de la traduction : $error';
  }

  @override
  String get composeTranslateUndo => 'Annuler';

  @override
  String get composeTranslateNothing => 'Rien à traduire pour l\'instant';

  @override
  String get tabMessages => 'Messages';

  @override
  String get titleMessages => 'Messages';

  @override
  String get messagesWipTitle => 'La messagerie privée n\'est pas encore faite';

  @override
  String get messagesWipBody =>
      'Pubky dispose d\'un protocole chiffré de pair à pair, pubky-noise : chacun écrit sur son propre homeserver et lit celui de l\'autre, sans serveur supplémentaire. Il est encore en version candidate et n\'existe qu\'en bibliothèque Rust, il faut donc le porter avant de pouvoir afficher quoi que ce soit ici.';

  @override
  String get messagesWipFollow => 'Suivre l\'avancement';

  @override
  String get tabDiscover => 'Découverte';

  @override
  String get titleDiscover => 'Découverte';

  @override
  String get discoverPopular => 'Populaire';

  @override
  String get discoverPeople => 'COMPTES À DÉCOUVRIR';

  @override
  String get discoverEmpty =>
      'Rien à montrer pour l\'instant. Tire vers le bas pour réessayer.';

  @override
  String discoverEmptyTag(String tag) {
    return 'Aucun post ne porte encore #$tag.';
  }

  @override
  String get composeTranslateFrom => 'Depuis';

  @override
  String get composeTranslateTarget => 'Vers';

  @override
  String get composeTranslateSameLanguage => 'Choisis deux langues différentes';

  @override
  String get composeTranslateKeepsMentions =>
      'Les mentions et les liens ne sont pas touchés — une clé traduite ne notifierait plus personne.';

  @override
  String get composeTranslateAuto => 'Détecter automatiquement';

  @override
  String get composeTranslateQuota =>
      'La clé DeepL a épuisé son quota du mois. Il repart au mois suivant.';

  @override
  String get settingsTranslation => 'Traduction';

  @override
  String get composeTranslateWorking => 'Traduction en cours…';

  @override
  String get composeTranslateBadKey =>
      'DeepL a refusé la clé. Vérifie-la dans les réglages, ou efface-la pour revenir au service sans clé.';

  @override
  String get composeTranslateViaDeepL =>
      'Traduit par DeepL avec ta clé — le brouillon quitte le téléphone.';

  @override
  String get settingsDeepLKey => 'Clé d\'API DeepL (facultatif)';

  @override
  String get settingsDeepLKeyHint => '…:fx pour une clé gratuite';

  @override
  String get settingsDeepLKeyNote =>
      'La traduction demande une clé. Le plan gratuit de DeepL couvre 500 000 caractères par mois ; une clé gratuite se termine par « :fx ». Sans clé, le bouton Traduire le dit au lieu d\'échouer.';

  @override
  String get settingsDeepLChecking => 'Vérification de la clé…';

  @override
  String settingsDeepLValid(String used, String limit) {
    return 'Clé acceptée — $used caractères utilisés sur $limit.';
  }

  @override
  String get settingsDeepLInvalid => 'DeepL a refusé cette clé.';

  @override
  String get composeTranslateNoKey =>
      'La traduction demande une clé DeepL. Ajoute-la dans les réglages — le plan gratuit couvre 500 000 caractères par mois.';

  @override
  String get postTitle => 'Post';

  @override
  String get postLoading => 'Chargement…';

  @override
  String get postGone =>
      'Ce post n\'est pas dans l\'index — il a peut-être été supprimé.';

  @override
  String get postInReplyTo => 'EN RÉPONSE À';

  @override
  String get postNoReplies => 'AUCUNE RÉPONSE POUR L\'INSTANT';

  @override
  String postReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count RÉPONSES',
      one: '1 RÉPONSE',
    );
    return '$_temp0';
  }

  @override
  String get composeImage => 'Image';

  @override
  String get composeImageRemove => 'Retirer l\'image';

  @override
  String get composeUploading => 'Envoi de l\'image…';

  @override
  String get composeReplyTitle => 'Répondre';

  @override
  String get composeReplyHint => 'Ta réponse…';

  @override
  String get composeReplyPublish => 'Répondre';

  @override
  String get postReply => 'Répondre';

  @override
  String get actionClose => 'Fermer';

  @override
  String get postTranslate => 'Traduire ce post';

  @override
  String get postTranslatedBy =>
      'Traduit par DeepL — touche la flèche pour l\'original';
}
