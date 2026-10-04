import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('fr')];

  /// The app's name: title bar, task switcher, placeholder home.
  ///
  /// In fr, this message translates to:
  /// **'Tournée des calendriers'**
  String get appTitle;

  /// Title of the first-launch screen (PLAN §5.1).
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get screenWelcome;

  /// Title of the create-a-tournée screen (PLAN §5.2).
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle tournée'**
  String get screenCreate;

  /// Title of the join screen (PLAN §5.2).
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre une tournée'**
  String get screenJoin;

  /// Title of the waiting-for-approval screen (PLAN §5.2).
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée'**
  String get screenJoinPending;

  /// Title of the map mode that adds streets (PLAN §5.4).
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des rues'**
  String get screenAddStreets;

  /// Title of the manual street form (PLAN §5.5).
  ///
  /// In fr, this message translates to:
  /// **'Rue à la main'**
  String get screenManualStreet;

  /// Placeholder title of the street screen; the real one shows the street's name (PLAN §5.6).
  ///
  /// In fr, this message translates to:
  /// **'Rue'**
  String get screenStreet;

  /// Title of the street edit mode (PLAN §5.5).
  ///
  /// In fr, this message translates to:
  /// **'Modifier la rue'**
  String get screenEditStreet;

  /// Placeholder title of the team screen (PLAN §5.8).
  ///
  /// In fr, this message translates to:
  /// **'Équipe'**
  String get screenTeam;

  /// Title of the settings screen (PLAN §5.9).
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get screenSettings;

  /// Title of the new campaign screen (PLAN §5.10).
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle campagne'**
  String get screenNewCampaign;

  /// Title of the trash screen (PLAN §5.11).
  ///
  /// In fr, this message translates to:
  /// **'Corbeille'**
  String get screenTrash;

  /// Screen-reader name of a house still to visit.
  ///
  /// In fr, this message translates to:
  /// **'à faire'**
  String get tileStatusToDo;

  /// Screen-reader name of a visited house.
  ///
  /// In fr, this message translates to:
  /// **'fait'**
  String get tileStatusDone;

  /// Screen-reader name of a house where nobody answered.
  ///
  /// In fr, this message translates to:
  /// **'personne'**
  String get tileStatusNobodyHome;

  /// Screen-reader name of a house to visit again later.
  ///
  /// In fr, this message translates to:
  /// **'à faire, repasser'**
  String get tileStatusComeBack;

  /// Screen-reader label of a house tile, e.g. « Numéro 3bis, fait ».
  ///
  /// In fr, this message translates to:
  /// **'Numéro {number}, {status}'**
  String houseTileSemantics(String number, String status);

  /// Screen-reader label of a partly visited building tile.
  ///
  /// In fr, this message translates to:
  /// **'Numéro {number}, immeuble, {done} sur {total} faits'**
  String buildingTileSemantics(String number, int done, int total);

  /// Screen-reader label of a tile whose house has a note (the small dot).
  ///
  /// In fr, this message translates to:
  /// **'{tile}, avec une note'**
  String tileWithNoteSemantics(String tile);

  /// Name of the status « to do », in the undo snackbar.
  ///
  /// In fr, this message translates to:
  /// **'À faire'**
  String get statusToDo;

  /// Name of the status « done », in the undo snackbar.
  ///
  /// In fr, this message translates to:
  /// **'Fait'**
  String get statusDone;

  /// Name of the status « nobody home », in the undo snackbar.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get statusNobodyHome;

  /// Undo snackbar after a tap on a house tile (PLAN §5.6).
  ///
  /// In fr, this message translates to:
  /// **'{number} → {status}'**
  String houseMarked(String number, String status);

  /// Tooltip of the ✏ button of the street screen, which opens the edit mode.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la rue'**
  String get editStreetAction;

  /// Toggle of the street screen that hides the done houses.
  ///
  /// In fr, this message translates to:
  /// **'Masquer faits'**
  String get hideDone;

  /// Header of the column of odd numbers.
  ///
  /// In fr, this message translates to:
  /// **'Côté impair'**
  String get oddSide;

  /// Header of the column of even numbers.
  ///
  /// In fr, this message translates to:
  /// **'Côté pair'**
  String get evenSide;

  /// Screen-reader label of the counts of the street screen (« 31/42 · ✗ 3 · ↻ 1 »).
  ///
  /// In fr, this message translates to:
  /// **'{done} sur {total} faits, {nobodyHome} personne, {comeBack} à repasser'**
  String streetCountsSemantics(
    int done,
    int total,
    int nobodyHome,
    int comeBack,
  );

  /// Start of the hint at the bottom of the street screen, before the glyphs ○ → ✓ → ✗ → ○.
  ///
  /// In fr, this message translates to:
  /// **'Appui :'**
  String get tapHintTap;

  /// End of the hint at the bottom of the street screen.
  ///
  /// In fr, this message translates to:
  /// **'Appui long : détails'**
  String get tapHintHold;

  /// Screen-reader label of the hint at the bottom of the street screen.
  ///
  /// In fr, this message translates to:
  /// **'Appui : à faire, fait, personne, à faire. Appui long : détails'**
  String get tapHintSemantics;

  /// Street screen opened for a street that is not on the phone or is in the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'Cette rue n\'est plus sur ce téléphone.'**
  String get streetGone;

  /// Screen-reader name of the status control of the house sheet (« À faire | Fait | Personne », PLAN §5.7).
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get houseStatusGroup;

  /// Box of the house sheet: the residents asked the team to come back later.
  ///
  /// In fr, this message translates to:
  /// **'Repasser'**
  String get comeBack;

  /// Under the disabled « Repasser » box when the house is done (a done house cannot get a « repasser »).
  ///
  /// In fr, this message translates to:
  /// **'Déjà fait : rien à repasser.'**
  String get comeBackDoneReason;

  /// Placeholder and screen-reader name of the field saying when to come back.
  ///
  /// In fr, this message translates to:
  /// **'Quand ? ex. après 19h'**
  String get comeBackHintPlaceholder;

  /// Shown when typing or pasting would make the come-back hint longer than allowed; the edit is refused.
  ///
  /// In fr, this message translates to:
  /// **'Précision limitée à {max} caractères.'**
  String comeBackHintTooLong(int max);

  /// Label of the note field of the house sheet.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// Under every note field (PLAN §5.7, §8).
  ///
  /// In fr, this message translates to:
  /// **'N\'écrivez ni nom ni information personnelle.'**
  String get notePrivacyHint;

  /// Shown when typing or pasting would make the note longer than allowed; the edit is refused.
  ///
  /// In fr, this message translates to:
  /// **'Note limitée à {max} caractères.'**
  String noteTooLong(int max);

  /// Characters used / allowed, under a text field with a limit.
  ///
  /// In fr, this message translates to:
  /// **'{count}/{max}'**
  String textCount(int count, int max);

  /// Screen-reader label of the characters counter.
  ///
  /// In fr, this message translates to:
  /// **'{count} caractères sur {max}'**
  String textCountSemantics(int count, int max);

  /// Last change of a house, made today (no member names before M2).
  ///
  /// In fr, this message translates to:
  /// **'Modifié à {time}'**
  String houseChangedToday(DateTime time);

  /// Last change of a house, made before today: « Modifié le 3 oct. à 14:02 ».
  ///
  /// In fr, this message translates to:
  /// **'Modifié le {day} à {time}'**
  String houseChangedOn(DateTime day, DateTime time);

  /// House sheet of a number that was removed meanwhile, or whose street went to the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro n\'est plus dans cette rue.'**
  String get houseGone;

  /// Header of the street list of the temporary start screen (PLAN §5.0), with the number of streets.
  ///
  /// In fr, this message translates to:
  /// **'Mes rues · {count}'**
  String startStreetsHeader(int count);

  /// Placeholder and screen-reader name of the field that filters a list of streets by name.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer les rues…'**
  String get filterStreetsHint;

  /// Button of the start screen that opens the import screen, and title of that screen (PLAN §5.0).
  ///
  /// In fr, this message translates to:
  /// **'Importer des rues'**
  String get importStreetsAction;

  /// Start screen, first launch: no street imported yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune rue pour l\'instant'**
  String get startEmptyTitle;

  /// Start screen, first launch: what to do.
  ///
  /// In fr, this message translates to:
  /// **'Importez les rues d\'une commune pour commencer. Il faut le réseau une fois ; ensuite tout fonctionne hors ligne.'**
  String get startEmptyBody;

  /// Shown when the street filter keeps no street.
  ///
  /// In fr, this message translates to:
  /// **'Aucune rue ne correspond à « {filter} ».'**
  String filterNoMatch(String filter);

  /// Progress of a street in the start list: doors done / doors.
  ///
  /// In fr, this message translates to:
  /// **'{done}/{total}'**
  String streetProgress(int done, int total);

  /// Screen-reader label of a street row of the start list.
  ///
  /// In fr, this message translates to:
  /// **'{name}, {done} sur {total} faits'**
  String streetRowSemantics(String name, int done, int total);

  /// Screen-reader label of a street row whose doors are all done.
  ///
  /// In fr, this message translates to:
  /// **'{name}, terminée, {total} sur {total} faits'**
  String streetRowCompleteSemantics(String name, int total);

  /// Label of the commune field of the import screen.
  ///
  /// In fr, this message translates to:
  /// **'Commune'**
  String get communeLabel;

  /// Placeholder of the commune field of the import screen.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la commune'**
  String get communeHint;

  /// A commune suggestion, or the chosen commune, with its postcode.
  ///
  /// In fr, this message translates to:
  /// **'{name} ({postcode})'**
  String communeWithPostcode(String name, String postcode);

  /// A commune with several postcodes: the first, then an ellipsis.
  ///
  /// In fr, this message translates to:
  /// **'{name} ({postcode}…)'**
  String communeWithPostcodes(String name, String postcode);

  /// The commune search found nothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucune commune ne porte ce nom.'**
  String get communeNoneFound;

  /// The commune search could not reach the service.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réseau : la recherche de communes en a besoin. Réessayez quand le téléphone capte.'**
  String get communeSearchNoNetwork;

  /// The commune search service answered with an error.
  ///
  /// In fr, this message translates to:
  /// **'La recherche de communes ne répond pas. Réessayez plus tard.'**
  String get communeSearchServiceError;

  /// While the streets of the chosen commune are being listed.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des rues…'**
  String get streetsLoading;

  /// The address base (BAN) could not be reached.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réseau. Réessayez quand le téléphone capte.'**
  String get addressNoNetwork;

  /// The address base (BAN) answered with an error.
  ///
  /// In fr, this message translates to:
  /// **'Le service des adresses ne répond pas. Réessayez plus tard.'**
  String get addressServiceError;

  /// The address base (BAN) does not know the commune or a street.
  ///
  /// In fr, this message translates to:
  /// **'La base d\'adresses ne connaît pas cette commune ou certaines de ses rues.'**
  String get addressNotFound;

  /// Button that tries a failed network call again.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// Above the import checklist: the commune's streets and how many are ticked.
  ///
  /// In fr, this message translates to:
  /// **'{total, plural, =1{1 rue} other{{total} rues}} · {checked, plural, =0{0 cochée} =1{1 cochée} other{{checked} cochées}}'**
  String importStreetCount(int total, int checked);

  /// Ticks every street the filter shows.
  ///
  /// In fr, this message translates to:
  /// **'Tout cocher'**
  String get checkAll;

  /// Unticks every street the filter shows.
  ///
  /// In fr, this message translates to:
  /// **'Tout décocher'**
  String get uncheckAll;

  /// How many house numbers the address base lists for a street.
  ///
  /// In fr, this message translates to:
  /// **'{count} n°'**
  String streetNumberCount(int count);

  /// A street of the import checklist that is already on the phone.
  ///
  /// In fr, this message translates to:
  /// **'déjà importée'**
  String get alreadyImported;

  /// Note above the import button.
  ///
  /// In fr, this message translates to:
  /// **'Nécessite le réseau. Les rues déjà importées gardent leurs marques.'**
  String get importFooter;

  /// Import button with the number of ticked streets.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Importer} =1{Importer 1 rue} other{Importer {count} rues}}'**
  String importButton(int count);

  /// Shown while the ticked streets are imported.
  ///
  /// In fr, this message translates to:
  /// **'Import en cours… {done}/{total}'**
  String importProgress(int done, int total);

  /// Message on the start screen after a complete import.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune nouvelle rue} =1{1 rue importée} other{{count} rues importées}}'**
  String importDone(int count);

  /// After an import where some streets failed; reason is one of the address* messages.
  ///
  /// In fr, this message translates to:
  /// **'{imported, plural, =0{Aucune rue importée} =1{1 rue importée} other{{imported} rues importées}}, {failed, plural, =1{1 en échec} other{{failed} en échec}}. {reason} Les rues encore cochées restent à importer.'**
  String importPartial(int imported, int failed, String reason);

  /// Title of the debug-only component gallery, and of the button opening it.
  ///
  /// In fr, this message translates to:
  /// **'Composants'**
  String get galleryTitle;

  /// Gallery section: buttons.
  ///
  /// In fr, this message translates to:
  /// **'Boutons'**
  String get galleryButtons;

  /// Gallery sample label of a primary button.
  ///
  /// In fr, this message translates to:
  /// **'Bouton principal'**
  String get galleryPrimaryButton;

  /// Gallery sample label of a disabled button.
  ///
  /// In fr, this message translates to:
  /// **'Bouton désactivé'**
  String get galleryDisabledButton;

  /// Gallery sample label of a secondary button.
  ///
  /// In fr, this message translates to:
  /// **'Bouton secondaire'**
  String get gallerySecondaryButton;

  /// Gallery sample label of a 52 dp button.
  ///
  /// In fr, this message translates to:
  /// **'Bouton compact'**
  String get galleryCompactButton;

  /// Gallery section: status tiles.
  ///
  /// In fr, this message translates to:
  /// **'Tuiles de statut'**
  String get galleryStatusTiles;

  /// Gallery section: bottom sheet and snackbar.
  ///
  /// In fr, this message translates to:
  /// **'Feuille et message'**
  String get gallerySheetAndSnackBar;

  /// Gallery button that opens the sample bottom sheet.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la feuille'**
  String get galleryShowSheet;

  /// Title of the sample bottom sheet.
  ///
  /// In fr, this message translates to:
  /// **'Rue des Lilas'**
  String get gallerySheetTitle;

  /// Body of the sample bottom sheet.
  ///
  /// In fr, this message translates to:
  /// **'Le contenu de la feuille se place ici.'**
  String get gallerySheetBody;

  /// Gallery button that shows the sample snackbar.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le message'**
  String get galleryShowSnackBar;

  /// Sample snackbar message, as after marking a house.
  ///
  /// In fr, this message translates to:
  /// **'7 → Personne'**
  String get gallerySnackBarMessage;

  /// Action that reverts the last change (snackbar).
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get undo;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
