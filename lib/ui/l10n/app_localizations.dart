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

  /// Title of the team screen (PLAN §5.8) before its tournée is read.
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

  /// Screen-reader name of a house or door to visit again later (status « Repasser »), or of a building with its own « repasser ».
  ///
  /// In fr, this message translates to:
  /// **'repasser'**
  String get tileStatusComeBack;

  /// Screen-reader label of a house tile, e.g. « Numéro 3bis, fait ».
  ///
  /// In fr, this message translates to:
  /// **'Numéro {number}, {status}'**
  String houseTileSemantics(String number, String status);

  /// Screen-reader label of a partly visited building tile; « ouvrir » says a tap opens its grid.
  ///
  /// In fr, this message translates to:
  /// **'Numéro {number}, immeuble, {done} sur {total} faits, ouvrir'**
  String buildingTileSemantics(String number, int done, int total);

  /// Screen-reader label of a building tile with no door done, every door done, or its own « repasser », e.g. « Numéro 8, immeuble, fait, ouvrir ».
  ///
  /// In fr, this message translates to:
  /// **'Numéro {number}, immeuble, {status}, ouvrir'**
  String buildingStatusTileSemantics(String number, String status);

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

  /// Name of the status « come back later », in the undo snackbar and the status control of the house sheet.
  ///
  /// In fr, this message translates to:
  /// **'Repasser'**
  String get statusComeBack;

  /// Undo snackbar after a tap on a house tile (PLAN §5.6). The « → » is drawn as a vector arrow; screen readers hear the text as written.
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

  /// Start of the hint at the bottom of the street screen, before the glyphs ○ → ✓ → ✗ → ↻ → ○, all drawn as vector shapes.
  ///
  /// In fr, this message translates to:
  /// **'Appui :'**
  String get tapHintTap;

  /// End of the hint at the bottom of the street screen.
  ///
  /// In fr, this message translates to:
  /// **'Appui long : détails'**
  String get tapHintHold;

  /// Screen-reader label of the hint at the bottom of the street screen.
  ///
  /// In fr, this message translates to:
  /// **'Appui : à faire, fait, personne, repasser, à faire. Appui long : détails'**
  String get tapHintSemantics;

  /// Street screen opened for a street that is not on the phone or is in the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'Cette rue n\'est plus sur ce téléphone.'**
  String get streetGone;

  /// Screen-reader name of the status control of the house sheet (« À faire | Fait | Personne | Repasser », PLAN §5.7).
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get houseStatusGroup;

  /// Box of the building's own « Repasser » sheet: the residents asked the team to come back later.
  ///
  /// In fr, this message translates to:
  /// **'Repasser'**
  String get comeBack;

  /// Label of the hint field of the house and door sheets; the field is greyed unless the status is « Repasser ».
  ///
  /// In fr, this message translates to:
  /// **'Quand repasser ?'**
  String get comeBackWhenLabel;

  /// Placeholder of the « Quand repasser ? » field of the house and door sheets.
  ///
  /// In fr, this message translates to:
  /// **'ex. après 19h'**
  String get comeBackWhenPlaceholder;

  /// Placeholder and screen-reader name of the field saying when to come back.
  ///
  /// In fr, this message translates to:
  /// **'Quand ? ex. après 19h'**
  String get comeBackHintPlaceholder;

  /// Shown when typing or pasting would make the come-back hint longer than allowed; the edit is refused.
  ///
  /// In fr, this message translates to:
  /// **'Précision limitée à {max} caractères.'**
  String comeBackHintTooLong(int max);

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

  /// Button of the house sheet that opens « Décrire l'immeuble » (PLAN §5.7).
  ///
  /// In fr, this message translates to:
  /// **'Transformer en immeuble…'**
  String get transformToBuilding;

  /// Button that closes a confirmation without doing anything.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// Title of the sheet that lays a building out (« Transformer en immeuble… », « Modifier les étages », PLAN §5.7).
  ///
  /// In fr, this message translates to:
  /// **'Décrire l\'immeuble'**
  String get buildingSetupTitle;

  /// Stepper of the building setup: how many staircases.
  ///
  /// In fr, this message translates to:
  /// **'Escaliers'**
  String get setupStaircases;

  /// Stepper of the building setup: the floors, from the RdC up.
  ///
  /// In fr, this message translates to:
  /// **'Étages'**
  String get setupFloors;

  /// Stepper of the building setup: doors on each floor.
  ///
  /// In fr, this message translates to:
  /// **'Portes par étage'**
  String get setupDoorsPerFloor;

  /// Screen-reader name of the − button of the staircases stepper.
  ///
  /// In fr, this message translates to:
  /// **'Un escalier de moins'**
  String get setupFewerStaircases;

  /// Screen-reader name of the + button of the staircases stepper.
  ///
  /// In fr, this message translates to:
  /// **'Un escalier de plus'**
  String get setupMoreStaircases;

  /// Screen-reader name of the − button of the floors stepper.
  ///
  /// In fr, this message translates to:
  /// **'Un étage de moins'**
  String get setupFewerFloors;

  /// Screen-reader name of the + button of the floors stepper.
  ///
  /// In fr, this message translates to:
  /// **'Un étage de plus'**
  String get setupMoreFloors;

  /// Screen-reader name of the − button of the doors stepper.
  ///
  /// In fr, this message translates to:
  /// **'Une porte de moins'**
  String get setupFewerDoors;

  /// Screen-reader name of the + button of the doors stepper.
  ///
  /// In fr, this message translates to:
  /// **'Une porte de plus'**
  String get setupMoreDoors;

  /// Screen-reader label of the value of a stepper, read again after each tap.
  ///
  /// In fr, this message translates to:
  /// **'{label} : {value}'**
  String setupStepperSemantics(String label, String value);

  /// Box of the building setup: ticked, one « Étages » and one « Portes par étage » stepper set every staircase alike; unticked, each staircase has its own.
  ///
  /// In fr, this message translates to:
  /// **'Même chose pour chaque escalier'**
  String get setupSameForEach;

  /// Header above the steppers of one staircase in the building setup, shown in capitals (« ESC. A »).
  ///
  /// In fr, this message translates to:
  /// **'Esc. {letter}'**
  String setupStaircaseHeader(String letter);

  /// Screen-reader name of a stepper or of its (−)/(+) when each staircase has its own: « Étages, escalier B ».
  ///
  /// In fr, this message translates to:
  /// **'{text}, escalier {letter}'**
  String setupForStaircase(String text, String letter);

  /// Value of the floors stepper when the floors are unknown: the doors make one « Logements » row.
  ///
  /// In fr, this message translates to:
  /// **'Inconnus'**
  String get setupFloorsUnknown;

  /// Value of the floors stepper: from the RdC to the top floor.
  ///
  /// In fr, this message translates to:
  /// **'RdC–{top}'**
  String setupFloorsRange(String top);

  /// Choice of how the doors are labelled.
  ///
  /// In fr, this message translates to:
  /// **'Numéros des portes'**
  String get setupLabelStyle;

  /// Door labels: floor then door number.
  ///
  /// In fr, this message translates to:
  /// **'51, 52…'**
  String get labelStyleNumber;

  /// Door labels: floor then a letter.
  ///
  /// In fr, this message translates to:
  /// **'5A, 5B…'**
  String get labelStyleLetter;

  /// Door labels typed by hand later (placeholders 1, 2, 3… until then).
  ///
  /// In fr, this message translates to:
  /// **'Libres'**
  String get labelStyleFree;

  /// Header of the preview of the building setup.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu · {count, plural, =1{1 logement} other{{count} logements}}'**
  String setupPreviewTitle(int count);

  /// Start of the part of the preview line of one staircase, when the staircases differ.
  ///
  /// In fr, this message translates to:
  /// **'Esc. {letter} : '**
  String setupPreviewStaircaseOne(String letter);

  /// Start of the preview line when the building has two staircases.
  ///
  /// In fr, this message translates to:
  /// **'Esc. {first} et {last} : '**
  String setupPreviewStaircasesTwo(String first, String last);

  /// Start of the preview line when the building has three staircases or more.
  ///
  /// In fr, this message translates to:
  /// **'Esc. {first} à {last} : '**
  String setupPreviewStaircasesMany(String first, String last);

  /// The labels of the first and last doors of a floor, in the preview.
  ///
  /// In fr, this message translates to:
  /// **'{first}–{last}'**
  String setupPreviewRange(String first, String last);

  /// Under the preview of the building setup.
  ///
  /// In fr, this message translates to:
  /// **'Chaque étage pourra ensuite être ajusté (porte en plus ou en moins).'**
  String get setupPreviewHint;

  /// Lays the building out as described.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get setupValidate;

  /// Refusal of the staircases stepper below one.
  ///
  /// In fr, this message translates to:
  /// **'Au moins 1 escalier.'**
  String get setupNoStaircase;

  /// Refusal of the staircases stepper above the limit.
  ///
  /// In fr, this message translates to:
  /// **'{max} escaliers au plus (A à Z).'**
  String setupTooManyStaircases(int max);

  /// Refusal of the floors stepper below « Inconnus ».
  ///
  /// In fr, this message translates to:
  /// **'Les sous-sols ne sont pas comptés.'**
  String get setupBelowGroundFloor;

  /// Refusal of the floors stepper above the limit.
  ///
  /// In fr, this message translates to:
  /// **'{max} étages au plus.'**
  String setupTooManyFloors(int max);

  /// Refusal of the doors stepper below one.
  ///
  /// In fr, this message translates to:
  /// **'Au moins 1 porte par étage.'**
  String get setupNoDoor;

  /// Refusal of the letter labels (or of one more door with them) past Z.
  ///
  /// In fr, this message translates to:
  /// **'{max} portes par étage au plus avec 5A, 5B…'**
  String setupTooManyDoorsForLetters(int max);

  /// Refusal of a stepper that would pass the most dwellings of a building.
  ///
  /// In fr, this message translates to:
  /// **'{max} logements au plus par immeuble.'**
  String setupTooManyDwellings(int max);

  /// Title of the confirmation when a new layout drops doors that have marks.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les étages ?'**
  String get setupConfirmTitle;

  /// Body of the confirmation when a new layout drops doors that have marks.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 porte marquée n\'existe plus dans ce plan : son statut et son « repasser » seront perdus.} other{{count} portes marquées n\'existent plus dans ce plan : leurs statuts et « repasser » seront perdus.}}'**
  String setupConfirmBody(int count);

  /// Confirms a new layout that drops doors with marks.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get setupConfirmAction;

  /// Screen-reader name and tooltip of the ✕ of the edit mode, which leaves it (the name is kept, as with OK).
  ///
  /// In fr, this message translates to:
  /// **'Quitter la modification'**
  String get editStreetClose;

  /// Button of the edit mode's top bar that keeps the name and leaves (PLAN §5.5).
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get editStreetOk;

  /// Label of the name field of the edit mode.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la rue'**
  String get streetNameLabel;

  /// Under the name field when it holds only spaces; the old name is kept.
  ///
  /// In fr, this message translates to:
  /// **'Le nom de la rue ne peut pas être vide.'**
  String get streetNameBlank;

  /// Under the name field when the name is too long; the old name is kept.
  ///
  /// In fr, this message translates to:
  /// **'Nom limité à {max} caractères.'**
  String streetNameTooLong(int max);

  /// A building's tile in edit mode.
  ///
  /// In fr, this message translates to:
  /// **'{number} · immeuble'**
  String editBuildingTile(String number);

  /// Screen-reader name of a number in edit mode; a tap opens its sheet.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le numéro {number}'**
  String editTileSemantics(String number);

  /// Screen-reader name of a building in edit mode.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le numéro {number}, immeuble'**
  String editBuildingTileSemantics(String number);

  /// Screen-reader name of the ✕ of a number in edit mode.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le numéro {number}'**
  String removeNumberSemantics(String number);

  /// Button under each column of the edit mode; opens « Ajouter des numéros ».
  ///
  /// In fr, this message translates to:
  /// **'+ numéros'**
  String get addNumbersButton;

  /// Under the numbers of the edit mode.
  ///
  /// In fr, this message translates to:
  /// **'Touchez un numéro pour le renommer ou le transformer en immeuble.'**
  String get editHint;

  /// Bottom button of the edit mode: sends the street to the Corbeille after a confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la rue'**
  String get deleteStreetAction;

  /// Undo snackbar after ✕ on a number.
  ///
  /// In fr, this message translates to:
  /// **'N° {number} supprimé'**
  String numberRemoved(String number);

  /// Undo snackbar after a number was changed (3 → 3bis). The « → » is drawn as a vector arrow; screen readers hear the text as written.
  ///
  /// In fr, this message translates to:
  /// **'N° {from} → {to}'**
  String numberRenamed(String from, String to);

  /// Undo snackbar after a building was turned back into a single house.
  ///
  /// In fr, this message translates to:
  /// **'N° {number} changé en maison'**
  String backToHouseDone(String number);

  /// Confirms a removal (a number, a street).
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// Title of the confirmation before removing a number that has marks.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le n° {number} ?'**
  String confirmRemoveTitle(String number);

  /// Body of the confirmation before removing a number that has marks (PLAN §5.5).
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro a des marques (statut, « repasser » ou portes marquées). Elles partent avec lui à la Corbeille.'**
  String get confirmRemoveBody;

  /// Title of the confirmation of « Supprimer la rue ».
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la rue ?'**
  String get confirmDeleteStreetTitle;

  /// Body of the confirmation of « Supprimer la rue ».
  ///
  /// In fr, this message translates to:
  /// **'« {name} » part à la Corbeille avec ses numéros et leurs marques, pour toute l\'équipe.'**
  String confirmDeleteStreetBody(String name);

  /// Title of the sheet opened by « + numéros » (PLAN §5.5); also the screen-reader name of that button.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des numéros'**
  String get addNumbersTitle;

  /// Label of the field of « Ajouter des numéros ».
  ///
  /// In fr, this message translates to:
  /// **'Numéros'**
  String get numbersLabel;

  /// Placeholder of the field of « Ajouter des numéros »: an example.
  ///
  /// In fr, this message translates to:
  /// **'12bis, 21-25'**
  String get numbersPlaceholder;

  /// Under the field of « Ajouter des numéros ».
  ///
  /// In fr, this message translates to:
  /// **'Un numéro, une liste ou une plage (21-25).'**
  String get numbersHelper;

  /// Header of the preview of « Ajouter des numéros ».
  ///
  /// In fr, this message translates to:
  /// **'Aperçu · {count, plural, =1{1 numéro} other{{count} numéros}}'**
  String numbersPreviewTitle(int count);

  /// In the preview: numbers the street already shows, which are skipped.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans la rue : {numbers}'**
  String numbersAlreadyThere(String numbers);

  /// In the preview: numbers in the Corbeille, which come back with their marks.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Revient de la Corbeille avec ses marques : {numbers}} other{Reviennent de la Corbeille avec leurs marques : {numbers}}}'**
  String numbersFromCorbeille(int count, String numbers);

  /// Adds the numbers typed in « Ajouter des numéros ».
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get addNumbersConfirm;

  /// An item with a dash that is not a range of two plain numbers.
  ///
  /// In fr, this message translates to:
  /// **'« {token} » : une plage relie deux numéros simples, comme 21-25.'**
  String numbersInvalidRange(String token);

  /// The field gives more numbers than allowed at once.
  ///
  /// In fr, this message translates to:
  /// **'{max} numéros au plus à la fois.'**
  String numbersTooMany(int max);

  /// The number field is blank.
  ///
  /// In fr, this message translates to:
  /// **'Tapez un numéro.'**
  String get numberEmpty;

  /// What was typed does not start with a number.
  ///
  /// In fr, this message translates to:
  /// **'« {text} » n\'est pas un numéro.'**
  String numberMalformed(String text);

  /// The number is above the largest house number.
  ///
  /// In fr, this message translates to:
  /// **'« {text} » : {max} au plus.'**
  String numberTooLarge(String text, int max);

  /// What follows the number is not a valid suffix.
  ///
  /// In fr, this message translates to:
  /// **'« {text} » : après le numéro, un complément en lettres sans accent (12bis, 3A).'**
  String numberInvalidSuffix(String text);

  /// The suffix after the number is too long.
  ///
  /// In fr, this message translates to:
  /// **'« {text} » : complément de {max} caractères au plus.'**
  String numberSuffixTooLong(String text, int max);

  /// Label of the number field of a number's sheet in edit mode.
  ///
  /// In fr, this message translates to:
  /// **'Numéro'**
  String get numberLabel;

  /// Gives the house the number typed (3 → 3bis), its marks kept.
  ///
  /// In fr, this message translates to:
  /// **'Changer le numéro'**
  String get renumberAction;

  /// The number typed is shown by another house.
  ///
  /// In fr, this message translates to:
  /// **'Le {number} est déjà dans la rue.'**
  String renumberTaken(String number);

  /// The number typed belongs to a house in the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'Le {number} est dans la Corbeille : ajoutez-le avec « + numéros » pour le retrouver avec ses marques, ou choisissez un autre numéro.'**
  String renumberInCorbeille(String number);

  /// Choice of the « Gérer l'immeuble » menu of the building grid: the building becomes a single house again.
  ///
  /// In fr, this message translates to:
  /// **'Changer en maison'**
  String get backToHouseAction;

  /// Title of the confirmation when the doors of the building have marks.
  ///
  /// In fr, this message translates to:
  /// **'Changer en maison ?'**
  String get confirmBackToHouseTitle;

  /// Body of the confirmation when the doors of the building have marks.
  ///
  /// In fr, this message translates to:
  /// **'Les portes de l\'immeuble et leurs marques (statuts, « repasser ») seront perdues.'**
  String get confirmBackToHouseBody;

  /// The ground floor (rez-de-chaussée), in the grid and the setup.
  ///
  /// In fr, this message translates to:
  /// **'RdC'**
  String get floorGround;

  /// The first floor.
  ///
  /// In fr, this message translates to:
  /// **'1er'**
  String get floorFirst;

  /// A floor from the second up: 2e, 3e…
  ///
  /// In fr, this message translates to:
  /// **'{level}e'**
  String floorNth(int level);

  /// The single row of a building whose floors are unknown.
  ///
  /// In fr, this message translates to:
  /// **'Logements'**
  String get floorUnknown;

  /// Screen-reader name of the staircase control of the building grid.
  ///
  /// In fr, this message translates to:
  /// **'Escalier'**
  String get staircaseGroup;

  /// A button of the staircase control: its letter, doors done / doors.
  ///
  /// In fr, this message translates to:
  /// **'Esc. {letter} · {done}/{total}'**
  String staircaseTab(String letter, int done, int total);

  /// Screen-reader name of a button of the staircase control.
  ///
  /// In fr, this message translates to:
  /// **'Escalier {letter}, {done} sur {total} faits'**
  String staircaseTabSemantics(String letter, int done, int total);

  /// A staircase, in the screen-reader name of a door: « Escalier A, 5e, porte 51, fait ».
  ///
  /// In fr, this message translates to:
  /// **'Escalier {letter}'**
  String staircaseSpoken(String letter);

  /// A staircase, in the title of a door sheet: « Esc. A · 5e ».
  ///
  /// In fr, this message translates to:
  /// **'Esc. {letter}'**
  String staircaseShort(String letter);

  /// A door, in the screen-reader name of a door: « Escalier A, 5e, porte 51, fait ».
  ///
  /// In fr, this message translates to:
  /// **'porte {label}'**
  String doorSpoken(String label);

  /// Screen-reader name of the count of the building grid (« ◐ 15/24 »).
  ///
  /// In fr, this message translates to:
  /// **'{done} sur {total} logements faits'**
  String buildingCountSemantics(int done, int total);

  /// Screen-reader name and tooltip of the ✕ left of the building grid's number, which closes the grid like a swipe down (PLAN §5.7).
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get gridClose;

  /// End of the hint of the building grid, after « Appui : ○ → ✓ → ✗ → ↻ → ○ ·».
  ///
  /// In fr, this message translates to:
  /// **'Appui long : détails'**
  String get gridHintHold;

  /// Screen-reader label of the hint of the building grid.
  ///
  /// In fr, this message translates to:
  /// **'Appui : à faire, fait, personne, repasser, à faire. Appui long : détails'**
  String get gridHintSemantics;

  /// Choice of the « Gérer l'immeuble » menu of the building grid that lays the building out again.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les étages'**
  String get editFloors;

  /// Button under the building grid, and title of the menu it opens: Modifier les étages, Modifier les portes, Changer en maison.
  ///
  /// In fr, this message translates to:
  /// **'Gérer l\'immeuble'**
  String get manageBuilding;

  /// Button of a building's sheet in edit mode that opens its grid, where the building is changed.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir l\'immeuble'**
  String get openBuilding;

  /// Button under the building grid that opens the building's own « repasser » and its hint.
  ///
  /// In fr, this message translates to:
  /// **'Repasser'**
  String get buildingDetails;

  /// Building grid or sheet of a number that is no longer a building of the street.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro n\'est plus un immeuble de cette rue.'**
  String get buildingGone;

  /// Door sheet of a door that a new layout removed.
  ///
  /// In fr, this message translates to:
  /// **'Cette porte n\'est plus dans l\'immeuble.'**
  String get doorGone;

  /// Choice of the « Gérer l'immeuble » menu of the building grid, and title of the screen that adds, removes and renames doors floor by floor (PLAN §5.7).
  ///
  /// In fr, this message translates to:
  /// **'Modifier les portes'**
  String get adjustDoorsAction;

  /// Screen-reader name and tooltip of the ✕ of « Modifier les portes », which leaves it (every change is already stored).
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get adjustDoorsClose;

  /// Under the floors of « Modifier les portes ».
  ///
  /// In fr, this message translates to:
  /// **'Touchez une porte pour la renommer (« Gauche », « 5A »…).'**
  String get adjustDoorsHint;

  /// Screen-reader name of a door of « Modifier les portes »: a tap opens its rename sheet.
  ///
  /// In fr, this message translates to:
  /// **'Renommer la porte {label}'**
  String renameDoorSemantics(String label);

  /// Screen-reader name and tooltip of the ✕ of a door.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la porte {label}'**
  String removeDoorSemantics(String label);

  /// Screen-reader name of the « + » at the end of a floor from the 1er up.
  ///
  /// In fr, this message translates to:
  /// **'Une porte de plus au {floor}'**
  String addDoorSemantics(String floor);

  /// Screen-reader name of the « + » at the end of the RdC.
  ///
  /// In fr, this message translates to:
  /// **'Une porte de plus au rez-de-chaussée'**
  String get addDoorGroundSemantics;

  /// Screen-reader name of the « + » of the « Logements » row (floors unknown).
  ///
  /// In fr, this message translates to:
  /// **'Une porte de plus'**
  String get addDoorUnknownFloorSemantics;

  /// Undo snackbar after ✕ on a door.
  ///
  /// In fr, this message translates to:
  /// **'Porte {label} supprimée'**
  String doorRemoved(String label);

  /// Undo snackbar after « + » at the end of a floor.
  ///
  /// In fr, this message translates to:
  /// **'Porte {label} ajoutée'**
  String doorAdded(String label);

  /// Undo snackbar after a door was renamed (11 → Gauche). The « → » is drawn as a vector arrow; screen readers hear the text as written.
  ///
  /// In fr, this message translates to:
  /// **'Porte {from} → {to}'**
  String doorRenamed(String from, String to);

  /// Title of the confirmation before removing a door that has a mark.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la porte {label} ?'**
  String confirmRemoveDoorTitle(String label);

  /// Body of the confirmation before removing a door that has a mark.
  ///
  /// In fr, this message translates to:
  /// **'Elle a déjà une marque (fait, personne ou repasser), qui partira avec elle. « Annuler » la ramène juste après.'**
  String get confirmRemoveDoorBody;

  /// Closes a confirmation, keeping what it was about to remove.
  ///
  /// In fr, this message translates to:
  /// **'Garder'**
  String get keep;

  /// ✕ on the only door left in a building: a building keeps at least one door.
  ///
  /// In fr, this message translates to:
  /// **'C\'est la dernière porte de l\'immeuble. Pour en refaire une maison, revenez à l\'immeuble : « Gérer l\'immeuble », puis « Changer en maison ».'**
  String get lastDoorRefused;

  /// Title of the rename sheet of a door.
  ///
  /// In fr, this message translates to:
  /// **'Porte {label}'**
  String doorTitle(String label);

  /// Label of the field of the rename sheet of a door.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la porte'**
  String get doorNameLabel;

  /// Gives the door the name typed, its marks kept.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get renameDoorAction;

  /// Another door of the same floor has the name typed.
  ///
  /// In fr, this message translates to:
  /// **'Ce nom est déjà pris à cet étage.'**
  String get doorLabelTaken;

  /// The name typed for a door is empty.
  ///
  /// In fr, this message translates to:
  /// **'Le nom de la porte ne peut pas être vide.'**
  String get doorLabelBlank;

  /// The name typed for a door is too long.
  ///
  /// In fr, this message translates to:
  /// **'Nom limité à {max} caractères.'**
  String doorLabelTooLong(int max);

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
  /// **'Importez les rues d\'une commune pour commencer.'**
  String get startEmptyBody;

  /// Line above « Importer des rues » while changes made on this phone wait to be sent (PLAN §5.3, §7), after a cloud glyph. Firestore tells only which streets have writes waiting, so it counts streets, not changes. Never shown for 0.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Modifications d\'une rue en attente d\'envoi} other{Modifications de {count} rues en attente d\'envoi}}'**
  String pendingSyncLine(int count);

  /// Shown when the street filter keeps no street.
  ///
  /// In fr, this message translates to:
  /// **'Aucune rue ne correspond à « {filter} ».'**
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
  /// **'Pas de réseau : la recherche de communes en a besoin. Réessayez quand le téléphone capte.'**
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

  /// A street of the import checklist imported before and now in the Corbeille: ticking it brings it back with its marks.
  ///
  /// In fr, this message translates to:
  /// **'dans la Corbeille'**
  String get inCorbeille;

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

  /// Message on the start screen after an import that only brought streets back from the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 rue restaurée} other{{count} rues restaurées}}'**
  String importRestored(int count);

  /// Message on the start screen after an import that downloaded streets and brought others back from the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'{imported, plural, =1{1 rue importée} other{{imported} rues importées}}, {restored, plural, =1{1 restaurée} other{{restored} restaurées}}'**
  String importDoneAndRestored(int imported, int restored);

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

  /// Title of the dialog shown over any screen when the phone could not write a change (its storage is full).
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement impossible'**
  String get saveFailedTitle;

  /// Body of that dialog. The change still shows and is kept at the next write of the street that succeeds; it is lost if the app closes first.
  ///
  /// In fr, this message translates to:
  /// **'Le téléphone n\'a pas pu enregistrer le dernier changement : sa mémoire est peut-être pleine. Libérez de la place avant de fermer l\'application.'**
  String get saveFailedBody;

  /// Button that closes that dialog.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get saveFailedOk;

  /// Title of the open tournée on the start screen (PLAN §5.3) and of a row of « Mes tournées ».
  ///
  /// In fr, this message translates to:
  /// **'Tournée {number} · {year}'**
  String tourneeTitle(String number, String year);

  /// Screen-reader label of the title button that opens « Mes tournées » (Home mockup).
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}. Changer de tournée'**
  String tourneeTitleSemantics(String title, String centre);

  /// Title of the sheet listing the member's tournées (PLAN §5.3), and of its row in Paramètres.
  ///
  /// In fr, this message translates to:
  /// **'Mes tournées'**
  String get myTourneesTitle;

  /// « Mes tournées » when the phone knows no tournée yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune tournée pour l\'instant.'**
  String get myTourneesEmpty;

  /// Second line of a tournée the member asked to join, not accepted yet (Switcher mockup).
  ///
  /// In fr, this message translates to:
  /// **'{centre} · votre demande est en attente'**
  String myTourneesPending(String centre);

  /// Screen-reader label of the open tournée in « Mes tournées ».
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}, tournée ouverte'**
  String myTourneesOpenSemantics(String title, String centre);

  /// Screen-reader label of another tournée in « Mes tournées »: a tap opens it.
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}, ouvrir'**
  String myTourneesClosedSemantics(String title, String centre);

  /// Screen-reader label of a tournée the member asked to join, not accepted yet.
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}, votre demande est en attente'**
  String myTourneesPendingSemantics(String title, String centre);

  /// Section header of Paramètres: the member's own settings (PLAN §5.9).
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get settingsYou;

  /// Section header of Paramètres: the app's settings.
  ///
  /// In fr, this message translates to:
  /// **'Application'**
  String get settingsApplication;

  /// Row of Paramètres that changes the member's first name.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get settingsName;

  /// Value of the « Mes tournées » row of Paramètres: the open tournée.
  ///
  /// In fr, this message translates to:
  /// **'{number} · {year}'**
  String settingsMyTourneesValue(String number, String year);

  /// Row of Paramètres that picks the theme, and title of its sheet.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get settingsTheme;

  /// Theme that follows the phone's setting.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSystem;

  /// Light theme.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// Dark theme.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// Row of Paramètres that opens the privacy page, and its title.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get settingsPrivacy;

  /// Row of Paramètres with the app's version; a tap opens the licences.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// Screen-reader label of the version row: a tap opens the licences page.
  ///
  /// In fr, this message translates to:
  /// **'Version {version}, voir les licences'**
  String settingsVersionSemantics(String version);

  /// Attribution of the map and address data at the bottom of Paramètres (PLAN §8.3).
  ///
  /// In fr, this message translates to:
  /// **'Carte © contributeurs OpenStreetMap, OpenFreeMap. Adresses : Base Adresse Nationale.'**
  String get settingsCredits;

  /// Screen-reader label of a row of Paramètres with a value, e.g. « Thème, Système ».
  ///
  /// In fr, this message translates to:
  /// **'{label}, {value}'**
  String settingsRowSemantics(String label, String value);

  /// Label of the first-name field (Paramètres → Prénom).
  ///
  /// In fr, this message translates to:
  /// **'Votre prénom'**
  String get nameFieldLabel;

  /// Button that keeps the first name typed.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get nameSave;

  /// Refusal under the first-name field when it holds nothing but spaces.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez votre prénom.'**
  String get nameBlank;

  /// Shown when an edit would make the first name too long.
  ///
  /// In fr, this message translates to:
  /// **'Prénom limité à {max} caractères.'**
  String nameTooLong(int max);

  /// Privacy page: section about the account.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get privacyAccountTitle;

  /// Privacy page: the account (PLAN §8.3).
  ///
  /// In fr, this message translates to:
  /// **'Un compte anonyme est créé au premier lancement : ni adresse e-mail, ni numéro de téléphone. L\'équipe voit seulement le prénom que vous donnez.'**
  String get privacyAccountBody;

  /// Privacy page: section about the data stored.
  ///
  /// In fr, this message translates to:
  /// **'Données enregistrées'**
  String get privacyDataTitle;

  /// Privacy page: what is stored (PLAN §8.3).
  ///
  /// In fr, this message translates to:
  /// **'Les adresses et leur position (données publiques), l\'état de chaque porte, l\'indication « repasser » (20 caractères au plus) et les prénoms des membres. Aucun nom d\'habitant, aucun don, aucune réponse des habitants.'**
  String get privacyDataBody;

  /// Privacy page: section about the phone's position.
  ///
  /// In fr, this message translates to:
  /// **'Position'**
  String get privacyLocationTitle;

  /// Privacy page: the phone's position (PLAN §8.3).
  ///
  /// In fr, this message translates to:
  /// **'Votre position sert seulement à vous situer sur la carte. Elle n\'est ni enregistrée ni envoyée. L\'autorisation est demandée la première fois que vous touchez le bouton qui vous situe.'**
  String get privacyLocationBody;

  /// Privacy page: section about where the data is kept.
  ///
  /// In fr, this message translates to:
  /// **'Hébergement'**
  String get privacyHostingTitle;

  /// Privacy page: where the data is kept (PLAN §8.3, Firestore in europe-west).
  ///
  /// In fr, this message translates to:
  /// **'Les données des tournées sont hébergées dans l\'Union européenne (Google Firebase).'**
  String get privacyHostingBody;

  /// Privacy page: section about deleting the data.
  ///
  /// In fr, this message translates to:
  /// **'Suppression'**
  String get privacyDeletionTitle;

  /// Privacy page: how data is deleted (PLAN §8.3).
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la tournée efface toutes ses données. À chaque nouvelle campagne, la campagne d\'avant la précédente est effacée.'**
  String get privacyDeletionBody;

  /// Tooltip and screen-reader name of the 👥 button of the start screen (PLAN §5.3).
  ///
  /// In fr, this message translates to:
  /// **'Équipe'**
  String get homeTeam;

  /// Screen-reader name of the 👥 button when join requests wait (the dot, PLAN §5.3).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Équipe, 1 demande en attente} other{Équipe, {count} demandes en attente}}'**
  String homeTeamWaiting(int count);

  /// Title of Équipe (Team mockup).
  ///
  /// In fr, this message translates to:
  /// **'Tournée {number}'**
  String teamTitle(String number);

  /// Line under the title of Équipe.
  ///
  /// In fr, this message translates to:
  /// **'{centre} · campagne {campaign}'**
  String teamSubtitle(String centre, String campaign);

  /// Label above the join code in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'Code'**
  String get teamCodeLabel;

  /// Screen-reader name of the QR code of Équipe.
  ///
  /// In fr, this message translates to:
  /// **'QR code de la tournée, code {code}'**
  String teamQrSemantics(String code);

  /// Button of Équipe that opens the phone's share sheet with the join code.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get teamShare;

  /// Text shared by « Partager » in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'Tournée {number} · {centre}\nRejoignez-la dans l\'app Tournée Calendriers avec le code {code}.'**
  String teamShareText(String number, String centre, String code);

  /// Creator-only button of Équipe: replaces the join code (PLAN §5.8).
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code'**
  String get teamNewCode;

  /// Header of the join requests in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'En attente ({count})'**
  String teamWaitingHeader(int count);

  /// Line under a request's name in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'a demandé à rejoindre · {when}'**
  String teamRequestAsked(String when);

  /// Button of a join request in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get teamAccept;

  /// Screen-reader name of « Accepter » on the request of {name}.
  ///
  /// In fr, this message translates to:
  /// **'Accepter {name}'**
  String teamAcceptSemantics(String name);

  /// Button of a join request in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get teamRefuse;

  /// Screen-reader name of « Refuser » on the request of {name}.
  ///
  /// In fr, this message translates to:
  /// **'Refuser {name}'**
  String teamRefuseSemantics(String name);

  /// Header of the members in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'Membres ({count})'**
  String teamMembersHeader(int count);

  /// The member using the phone in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'{name} (vous)'**
  String teamMemberYou(String name);

  /// The creator in Équipe ({name} may already read « Manu (vous) »).
  ///
  /// In fr, this message translates to:
  /// **'{name} · créateur'**
  String teamMemberCreator(String name);

  /// Screen-reader name of the ⋮ of a member (creator only).
  ///
  /// In fr, this message translates to:
  /// **'Options pour {name}'**
  String teamMemberOptions(String name);

  /// Item of a member's ⋮ menu, and the confirm button.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get teamRemove;

  /// Title of the confirmation before removing a member.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name} ?'**
  String teamRemoveTitle(String name);

  /// Body of the confirmation before removing a member (PLAN §5.8).
  ///
  /// In fr, this message translates to:
  /// **'{name} n\'aura plus accès à la tournée. Ses marques restent dans les rues.'**
  String teamRemoveBody(String name);

  /// Row of Équipe that opens the Corbeille (PLAN §5.11).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Corbeille · vide} =1{Corbeille · 1 élément} other{Corbeille · {count} éléments}}'**
  String teamCorbeille(int count);

  /// Button of Équipe for every member but the creator.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la tournée'**
  String get teamLeave;

  /// Title of the confirmation before leaving.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la tournée {number} ?'**
  String teamLeaveTitle(String number);

  /// Body of the confirmation before leaving.
  ///
  /// In fr, this message translates to:
  /// **'Pour revenir, il faudra le code et l\'accord d\'un membre.'**
  String get teamLeaveBody;

  /// Confirm button of the confirmation before leaving.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get teamLeaveConfirm;

  /// Creator-only button of Équipe.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la tournée'**
  String get teamDelete;

  /// Title of the confirmation before deleting the tournée.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la tournée {number} ?'**
  String teamDeleteTitle(String number);

  /// Body of the confirmation before deleting the tournée (PLAN §8.3).
  ///
  /// In fr, this message translates to:
  /// **'Les rues, les statuts et les membres seront supprimés pour toute l\'équipe. C\'est définitif.'**
  String get teamDeleteBody;

  /// Confirm button of the confirmation before deleting the tournée.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get teamDeleteConfirm;

  /// Équipe when no tournée is open.
  ///
  /// In fr, this message translates to:
  /// **'Aucune tournée ouverte.'**
  String get teamNoTournee;

  /// Équipe when the tournée cannot be read (removed, deleted, never read offline).
  ///
  /// In fr, this message translates to:
  /// **'L\'équipe ne peut pas être affichée : la tournée n\'est pas sur ce téléphone, ou vous n\'en faites plus partie.'**
  String get teamUnavailable;

  /// Snackbar of Équipe when a command was refused because a teammate acted first.
  ///
  /// In fr, this message translates to:
  /// **'L\'équipe a changé entre-temps.'**
  String get teamChanged;

  /// Snackbar of Équipe when a new code or deleting the tournée needs the network.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réseau. Réessayez une fois connecté.'**
  String get teamOffline;

  /// Less than a minute ago.
  ///
  /// In fr, this message translates to:
  /// **'à l\'instant'**
  String get recentJustNow;

  /// Minutes ago, 1 to 59.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} min'**
  String recentMinutes(int count);

  /// Hours ago, the same day.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} h'**
  String recentHours(int count);

  /// The day before today.
  ///
  /// In fr, this message translates to:
  /// **'hier'**
  String get recentYesterday;

  /// A day before yesterday: « 3 oct. ».
  ///
  /// In fr, this message translates to:
  /// **'{day}'**
  String recentDay(DateTime day);

  /// Text under the title of the Corbeille (Trash mockup).
  ///
  /// In fr, this message translates to:
  /// **'Les rues et numéros supprimés sont gardés 30 jours avec leurs statuts, puis supprimés définitivement.'**
  String get corbeilleIntro;

  /// The Corbeille with nothing in it.
  ///
  /// In fr, this message translates to:
  /// **'La corbeille est vide.'**
  String get corbeilleEmpty;

  /// A removed number in the Corbeille: « 14ter Rue des Lilas ».
  ///
  /// In fr, this message translates to:
  /// **'{number} {street}'**
  String corbeilleNumberTitle(String number, String street);

  /// The numbers of a deleted street in the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun numéro} =1{1 numéro} other{{count} numéros}}'**
  String corbeilleStreetNumbers(int count);

  /// Who deleted a street (la rue), in the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'supprimée par {name}'**
  String corbeilleStreetDeletedBy(String name);

  /// Who removed a number (le numéro), in the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'supprimé par {name}'**
  String corbeilleNumberDeletedBy(String name);

  /// Stands for a member no longer in the team, in « supprimée par … ».
  ///
  /// In fr, this message translates to:
  /// **'un membre'**
  String get corbeilleSomeone;

  /// Button of an item of the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get corbeilleRestore;

  /// Screen-reader name of « Restaurer » on {item}.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer {item}'**
  String corbeilleRestoreSemantics(String item);

  /// Card of the start screen, with a tournée open, while the phone still holds streets from before the tournée (PLAN §5.0).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 rue est enregistrée sur ce téléphone.} other{{count} rues sont enregistrées sur ce téléphone.}}'**
  String moveStreetsCount(int count);

  /// Primary button of the card: moves the phone's streets into the open tournée.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{L\'ajouter à la tournée} other{Les ajouter à la tournée}}'**
  String moveStreetsAction(int count);

  /// Text button of the card: hides it until the next launch.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get moveStreetsLater;

  /// In the card while the phone's streets go into the tournée.
  ///
  /// In fr, this message translates to:
  /// **'Ajout en cours… {done}/{total}'**
  String moveStreetsProgress(int done, int total);

  /// Message once every street of the phone went into the tournée.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 rue ajoutée à la tournée} other{{count} rues ajoutées à la tournée}}'**
  String moveStreetsDone(int count);

  /// Message once the phone's streets went into the tournée, some of them skipped because the tournée already had them.
  ///
  /// In fr, this message translates to:
  /// **'{moved, plural, =0{Aucune rue ajoutée} =1{1 rue ajoutée} other{{moved} rues ajoutées}}, {already, plural, =1{1 déjà dans la tournée} other{{already} déjà dans la tournée}}'**
  String moveStreetsDoneSome(int moved, int already);
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
