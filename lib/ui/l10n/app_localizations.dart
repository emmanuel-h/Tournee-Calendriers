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

  /// Start of the hint at the bottom of the street screen, before the glyphs ○ → ✓ → ✗ → ○, all drawn as vector shapes.
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
  /// **'Appui : à faire, fait, personne, à faire. Appui long : détails'**
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
  /// **'Déjà fait : rien à repasser.'**
  String get comeBackDoneReason;

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
  /// **'{count, plural, =1{1 porte marquée n\'existe plus dans ce plan : son statut, sa note et son « repasser » seront perdus.} other{{count} portes marquées n\'existent plus dans ce plan : leurs statuts, notes et « repasser » seront perdus.}}'**
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
  /// **'N° {number} redevient une maison'**
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
  /// **'Ce numéro a des marques (statut, note, « repasser » ou portes marquées). Elles partent avec lui à la Corbeille.'**
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

  /// Button of a building's sheet in edit mode: the building becomes a single house again.
  ///
  /// In fr, this message translates to:
  /// **'Redevenir une maison'**
  String get backToHouseAction;

  /// Title of the confirmation when the doors of the building have marks.
  ///
  /// In fr, this message translates to:
  /// **'Redevenir une maison ?'**
  String get confirmBackToHouseTitle;

  /// Body of the confirmation when the doors of the building have marks.
  ///
  /// In fr, this message translates to:
  /// **'Les portes de l\'immeuble et leurs marques (statuts, notes, « repasser ») seront perdues.'**
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

  /// End of the hint of the building grid, after « Appui : ○ → ✓ → ✗ → ○ ·».
  ///
  /// In fr, this message translates to:
  /// **'Appui long : note, repasser'**
  String get gridHintHold;

  /// Screen-reader label of the hint of the building grid.
  ///
  /// In fr, this message translates to:
  /// **'Appui : à faire, fait, personne, à faire. Appui long : note, repasser'**
  String get gridHintSemantics;

  /// Button under the building grid that lays the building out again.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les étages'**
  String get editFloors;

  /// Button under the building grid that opens the building's own note and « repasser ».
  ///
  /// In fr, this message translates to:
  /// **'Note · Repasser'**
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

  /// Button of a building's sheet in edit mode, and title of the screen that adds, removes and renames doors floor by floor (PLAN §5.7).
  ///
  /// In fr, this message translates to:
  /// **'Ajuster les portes'**
  String get adjustDoorsAction;

  /// Screen-reader name and tooltip of the ✕ of « Ajuster les portes », which leaves it (every change is already stored).
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get adjustDoorsClose;

  /// Under the floors of « Ajuster les portes ».
  ///
  /// In fr, this message translates to:
  /// **'Touchez une porte pour la renommer (« Gauche », « 5A »…). Les marques des autres portes sont gardées.'**
  String get adjustDoorsHint;

  /// Screen-reader name of a door of « Ajuster les portes »: a tap opens its rename sheet.
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

  /// Title of the confirmation before removing a door that has a mark.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la porte {label} ?'**
  String confirmRemoveDoorTitle(String label);

  /// Body of the confirmation before removing a door that has a mark.
  ///
  /// In fr, this message translates to:
  /// **'Elle a déjà une marque (fait, personne, repasser ou note), qui partira avec elle. « Annuler » la ramène juste après.'**
  String get confirmRemoveDoorBody;

  /// Closes a confirmation, keeping what it was about to remove.
  ///
  /// In fr, this message translates to:
  /// **'Garder'**
  String get keep;

  /// ✕ on the only door left in a building: a building keeps at least one door.
  ///
  /// In fr, this message translates to:
  /// **'C\'est la dernière porte de l\'immeuble. Pour en refaire une maison, touchez son numéro puis « Redevenir une maison ».'**
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
  /// **'Importez les rues d\'une commune pour commencer. Il faut le réseau une fois ; ensuite tout fonctionne hors ligne.'**
  String get startEmptyBody;

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
