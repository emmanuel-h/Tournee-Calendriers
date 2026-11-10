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

  /// Title of the create-a-sector screen (PLAN §5.2).
  ///
  /// In fr, this message translates to:
  /// **'Nouveau secteur'**
  String get screenCreate;

  /// Title of the join screen (PLAN §5.2).
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre un secteur'**
  String get screenJoin;

  /// Title of the waiting-for-approval screen (PLAN §5.2).
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée'**
  String get screenJoinPending;

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

  /// Title of the Secteur screen (PLAN §5.8, §5.14) before its sector is read.
  ///
  /// In fr, this message translates to:
  /// **'Secteur'**
  String get screenSector;

  /// Title of the settings screen (PLAN §5.9).
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get screenSettings;

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

  /// Screen-reader name of a house or door whose residents did not want a calendar (status « Refusé », #113); also the word of the snackbar « N° 9 : refusé » and of the map legend.
  ///
  /// In fr, this message translates to:
  /// **'refusé'**
  String get tileStatusRefused;

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

  /// Name of the status « to do », on its button and in the title of the status picker.
  ///
  /// In fr, this message translates to:
  /// **'À faire'**
  String get statusToDo;

  /// Name of the status « done », on its button and in the title of the status picker.
  ///
  /// In fr, this message translates to:
  /// **'Fait'**
  String get statusDone;

  /// Name of the status « refused » (no calendar wanted, #113), on its button and in the title of the status picker.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get statusRefused;

  /// Name of the status « nobody home », on its button and in the title of the status picker.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get statusNobodyHome;

  /// Name of the status « come back later », on its button and in the title of the status picker.
  ///
  /// In fr, this message translates to:
  /// **'Repasser'**
  String get statusComeBack;

  /// Next to the status glyph of a tile or a door tried two times or more with nobody home (#80), e.g. « ×3 ».
  ///
  /// In fr, this message translates to:
  /// **'×{count}'**
  String tileTries(int count);

  /// Screen-reader end of the label of a house or door « personne » tried two times or more: « Numéro 7, personne, 3e passage ».
  ///
  /// In fr, this message translates to:
  /// **'{count}e passage'**
  String tileTriesNobodyHome(int count);

  /// How many times nobody was home, in a house or door sheet (#80), and at the end of the screen-reader label of a tile done or « repasser » tried two times or more: « Numéro 7, fait, 2 passages sans personne ».
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} passage sans personne} other{{count} passages sans personne}}'**
  String nobodyHomeTries(int count);

  /// « ✗ Personne » of the status picker on a house or door « personne » or « repasser » already tried with nobody home (#80, HouseNobody mockup): one more try, the status « Personne ».
  ///
  /// In fr, this message translates to:
  /// **'De nouveau personne'**
  String get nobodyHomeAgain;

  /// Snackbar once the status picker of a house closed on a status it stored (PLAN §5.6), with « Annuler »: « N° 7 : personne ».
  ///
  /// In fr, this message translates to:
  /// **'N° {number} : {status}'**
  String houseStatusStored(String number, String status);

  /// Snackbar once the status picker made a house « personne » tried two times or more (#80): « N° 3bis : personne (3e passage) ».
  ///
  /// In fr, this message translates to:
  /// **'N° {number} : {status} ({count}e passage)'**
  String houseStatusStoredTries(String number, String status, int count);

  /// Snackbar once the status picker of a door of the building grid stored a status: « Porte 51 : fait ».
  ///
  /// In fr, this message translates to:
  /// **'Porte {label} : {status}'**
  String doorStatusStored(String label, String status);

  /// Snackbar once the status picker made a door « personne » tried two times or more: « Porte 51 : personne (3e passage) ».
  ///
  /// In fr, this message translates to:
  /// **'Porte {label} : {status} ({count}e passage)'**
  String doorStatusStoredTries(String label, String status, int count);

  /// Hint at the bottom of the street screen while no snackbar shows (PLAN §5.6): a tap on a house opens its status picker.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur une maison pour changer son statut'**
  String get streetHint;

  /// Hint under the doors of the building grid (PLAN §5.7): a tap on a door opens its status picker.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur une porte pour changer son statut'**
  String get gridHint;

  /// Screen-reader label of a house tile of the street screen, which opens the status picker: « Numéro 7, à faire, changer le statut ».
  ///
  /// In fr, this message translates to:
  /// **'Numéro {number}, {status}, changer le statut'**
  String houseTilePickSemantics(String number, String status);

  /// Title of the status picker of a house (House mockup), its status in grey beside it.
  ///
  /// In fr, this message translates to:
  /// **'N° {number}'**
  String statusPickerHouse(String number);

  /// Title of the status picker of a door of the building grid (Building mockup): « Porte 51 · Fait ».
  ///
  /// In fr, this message translates to:
  /// **'Porte {label} · {status}'**
  String statusPickerDoor(String label, String status);

  /// Title of the step of the status picker that asks when to come back, after « Repasser » (HouseComeBack mockup): « N° 5 · quand repasser ? », « Porte 51 · quand repasser ? ».
  ///
  /// In fr, this message translates to:
  /// **'{subject} · quand repasser ?'**
  String statusPickerComeBack(String subject);

  /// Button that closes the « quand repasser ? » step of the status picker; each day and hour is already stored.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get statusPickerValidate;

  /// How many calendars a house or door done took, in its status picker (#114, RunStreet mockup), and at the end of the screen-reader label of a tile or door with two or more: « Numéro 9, fait, 2 calendriers ».
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} calendrier} other{{count} calendriers}}'**
  String houseCalendars(int count);

  /// Screen-reader name and tooltip of the « − » beside « 2 calendriers » in the status picker (#114); disabled at one calendar. Never changes a don.
  ///
  /// In fr, this message translates to:
  /// **'Un calendrier de moins'**
  String get removeCalendar;

  /// Screen-reader name and tooltip of the ✕ of the status picker: closes it, nothing more stored.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get statusPickerClose;

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

  /// Screen-reader label of the counts of the street screen (« 31/42 · ⊘ 2 · ✗ 3 · ↻ 1 »); « faits » counts the done and refused houses together (#113). French puts 0 and 1 in the singular.
  ///
  /// In fr, this message translates to:
  /// **'{done} sur {total} faits, {refused, plural, one{{refused} refusé} other{{refused} refusés}}, {nobodyHome} personne, {comeBack} à repasser'**
  String streetCountsSemantics(
    int done,
    int total,
    int refused,
    int nobodyHome,
    int comeBack,
  );

  /// Street screen opened for a street that is not on the phone or is in the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'Cette rue n\'est plus sur ce téléphone.'**
  String get streetGone;

  /// Screen-reader name of the group of status buttons of the status picker of a house or door (PLAN §5.6).
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get houseStatusGroup;

  /// Box of the building's own « Repasser » sheet: the residents asked the team to come back later.
  ///
  /// In fr, this message translates to:
  /// **'Repasser'**
  String get comeBack;

  /// Title of the block of the house, door and building sheets that says when to come back: day chips, an hour list and a summary line (HouseComeBack mockup, #81). Greyed unless the status is « Repasser ».
  ///
  /// In fr, this message translates to:
  /// **'Quand repasser ?'**
  String get comeBackWhenLabel;

  /// Screen-reader name of the row of day chips of « Quand repasser ? ».
  ///
  /// In fr, this message translates to:
  /// **'Jour'**
  String get comeBackDayGroup;

  /// Day chip of « Quand repasser ? »: today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get comeBackToday;

  /// Day chip of « Quand repasser ? »: tomorrow.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get comeBackTomorrow;

  /// Day chip of « Quand repasser ? »: yesterday, shown only when that day was chosen before.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get comeBackYesterday;

  /// Day chip of « Quand repasser ? » for another day: its short weekday and its date (« sam. 24 »); the screen writes its first letter in capital (« Sam. 24 »).
  ///
  /// In fr, this message translates to:
  /// **'{day}'**
  String comeBackChipDay(DateTime day);

  /// What a screen reader says for a day chip of another day: « samedi 24 octobre ».
  ///
  /// In fr, this message translates to:
  /// **'{day}'**
  String comeBackChipDaySemantics(DateTime day);

  /// Label of the hour list of « Quand repasser ? ».
  ///
  /// In fr, this message translates to:
  /// **'Heure'**
  String get comeBackHourLabel;

  /// First choice of the hour list of « Quand repasser ? »: the day only.
  ///
  /// In fr, this message translates to:
  /// **'Pas d\'heure'**
  String get comeBackNoHour;

  /// An hour of the list of « Quand repasser ? », 8 to 21.
  ///
  /// In fr, this message translates to:
  /// **'{hour} h'**
  String comeBackHour(int hour);

  /// Summary line of « Quand repasser ? » while no day is chosen.
  ///
  /// In fr, this message translates to:
  /// **'Pas de jour choisi'**
  String get comeBackNoDay;

  /// Summary line of « Quand repasser ? »: today, without hour.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get comeBackOnToday;

  /// Summary line of « Quand repasser ? »: today at about an hour.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui vers {hour} h'**
  String comeBackOnTodayAt(int hour);

  /// Summary line of « Quand repasser ? »: tomorrow, without hour.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get comeBackOnTomorrow;

  /// Summary line of « Quand repasser ? »: tomorrow at about an hour.
  ///
  /// In fr, this message translates to:
  /// **'Demain vers {hour} h'**
  String comeBackOnTomorrowAt(int hour);

  /// Summary line of « Quand repasser ? » when the day chosen was yesterday: it is past.
  ///
  /// In fr, this message translates to:
  /// **'C\'était hier'**
  String get comeBackOnYesterday;

  /// Summary line of « Quand repasser ? » when the time chosen was yesterday at about an hour: it is past.
  ///
  /// In fr, this message translates to:
  /// **'C\'était hier vers {hour} h'**
  String comeBackOnYesterdayAt(int hour);

  /// Summary line of « Quand repasser ? »: a day after tomorrow, without hour (« Le samedi 24 oct. »).
  ///
  /// In fr, this message translates to:
  /// **'Le {day}'**
  String comeBackOnDay(DateTime day);

  /// Summary line of « Quand repasser ? »: a day after tomorrow at about an hour (« Le samedi 24 oct. vers 18 h », mockup HouseComeBack).
  ///
  /// In fr, this message translates to:
  /// **'Le {day} vers {hour} h'**
  String comeBackOnDayAt(DateTime day, int hour);

  /// Summary line of « Quand repasser ? » when the day chosen is before yesterday: it is past (« C'était le mercredi 14 oct. »).
  ///
  /// In fr, this message translates to:
  /// **'C\'était le {day}'**
  String comeBackPastDay(DateTime day);

  /// Summary line of « Quand repasser ? » when the time chosen is before yesterday at about an hour: it is past.
  ///
  /// In fr, this message translates to:
  /// **'C\'était le {day} vers {hour} h'**
  String comeBackPastDayAt(DateTime day, int hour);

  /// Last change of a house, made today, by nobody the phone can name.
  ///
  /// In fr, this message translates to:
  /// **'Modifié à {time}'**
  String houseChangedToday(DateTime time);

  /// Last change of a house, made before today: « Modifié le 3 oct. à 14:02 ».
  ///
  /// In fr, this message translates to:
  /// **'Modifié le {day} à {time}'**
  String houseChangedOn(DateTime day, DateTime time);

  /// Last change of a house, made today by a member: « Modifié par Léa · 14:02 » (PLAN §5.7).
  ///
  /// In fr, this message translates to:
  /// **'Modifié par {name} · {time}'**
  String houseChangedByToday(String name, DateTime time);

  /// Last change of a house, made before today by a member: « Modifié par Léa · 3 oct. à 14:02 ».
  ///
  /// In fr, this message translates to:
  /// **'Modifié par {name} · {day} à {time}'**
  String houseChangedByOn(String name, DateTime day, DateTime time);

  /// The name of the member on the phone in « Modifié par vous · 14:02 ».
  ///
  /// In fr, this message translates to:
  /// **'vous'**
  String get houseChangedByMe;

  /// House sheet of a number that was removed meanwhile, or whose street went to the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro n\'est plus dans cette rue.'**
  String get houseGone;

  /// Button of the number sheet of edit mode that opens « Décrire l'immeuble » (PLAN §5.5).
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

  /// Title of the rename sheet of a door, and what « … · quand repasser ? » is about in its status picker.
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

  /// Placeholder and screen-reader name of the field that filters a list of streets by name.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer les rues…'**
  String get filterStreetsHint;

  /// Title of the panel of Accueil with no secteur open (PLAN §5.0, NoSector mockup).
  ///
  /// In fr, this message translates to:
  /// **'Aucun secteur ouvert'**
  String get noSectorTitle;

  /// Accueil with no secteur open, under « Aucun secteur ouvert »: what to do (PLAN §5.0).
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez le secteur de votre équipe avec le code qu\'on vous a donné.'**
  String get noSectorBody;

  /// Line at the bottom of Accueil's panel while changes made on this phone wait to be sent (PLAN §5.3, §7), after a cloud glyph. Firestore tells only which streets have writes waiting, so it counts streets, not changes. Never shown for 0.
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

  /// A street of the import checklist imported before and now in the Corbeille: ticking it brings it back with its marks.
  ///
  /// In fr, this message translates to:
  /// **'dans la Corbeille'**
  String get inCorbeille;

  /// Message on the start screen after an import that only brought streets back from the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 rue restaurée} other{{count} rues restaurées}}'**
  String importRestored(int count);

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

  /// Title of the open sector on the start screen (PLAN §5.3) and of a row of « Mes secteurs ».
  ///
  /// In fr, this message translates to:
  /// **'Secteur {number} · {year}'**
  String sectorTitle(String number, String year);

  /// Screen-reader label of the title button that opens « Mes secteurs » (Home mockup).
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}. Changer de secteur'**
  String sectorTitleSemantics(String title, String centre);

  /// Title of the sheet listing the member's sectors (PLAN §5.3), and of its row in Paramètres.
  ///
  /// In fr, this message translates to:
  /// **'Mes secteurs'**
  String get mySectorsTitle;

  /// « Mes secteurs » when the phone knows no sector yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun secteur pour l\'instant.'**
  String get mySectorsEmpty;

  /// Second line of a sector the member asked to join, not accepted yet (Switcher mockup).
  ///
  /// In fr, this message translates to:
  /// **'{centre} · votre demande est en attente'**
  String mySectorsPending(String centre);

  /// Screen-reader label of the open sector in « Mes secteurs ».
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}, secteur ouvert'**
  String mySectorsOpenSemantics(String title, String centre);

  /// Screen-reader label of another sector in « Mes secteurs »: a tap opens it.
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}, ouvrir'**
  String mySectorsClosedSemantics(String title, String centre);

  /// Second line of a sector not open where join requests wait for an answer, beside a red dot (Switcher mockup).
  ///
  /// In fr, this message translates to:
  /// **'{centre} · {count, plural, =1{1 demande en attente} other{{count} demandes en attente}}'**
  String mySectorsWaiting(String centre, int count);

  /// Screen-reader label of a sector not open where join requests wait: the dot, said.
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}, {count, plural, =1{1 demande en attente} other{{count} demandes en attente}}, ouvrir'**
  String mySectorsWaitingSemantics(String title, String centre, int count);

  /// Screen-reader label of a sector the member asked to join, not accepted yet.
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}, votre demande est en attente'**
  String mySectorsPendingSemantics(String title, String centre);

  /// Section header of Paramètres: the member's own settings (PLAN §5.9).
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get settingsYou;

  /// Muted line of Paramètres under « Mes secteurs »: the sector downloads itself for offline use, unseen (PLAN §5.9, §7).
  ///
  /// In fr, this message translates to:
  /// **'L\'application fonctionne sans réseau ; les modifications sont envoyées dès qu\'il revient.'**
  String get settingsOfflineLine;

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

  /// Value of the « Mes secteurs » row of Paramètres: the open sector.
  ///
  /// In fr, this message translates to:
  /// **'{number} · {year}'**
  String settingsMySectorsValue(String number, String year);

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

  /// Row of Paramètres with the app's version; a tap opens « Nouveautés ».
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// Screen-reader label of the version row: a tap opens « Nouveautés ».
  ///
  /// In fr, this message translates to:
  /// **'Version {version}, voir les nouveautés'**
  String settingsVersionSemantics(String version);

  /// Row of Paramètres under the version: opens the licences of the packages and bundled fonts.
  ///
  /// In fr, this message translates to:
  /// **'Licences'**
  String get settingsLicences;

  /// Title of the page opened by the version row of Paramètres: what changed in each version (Changelog mockup).
  ///
  /// In fr, this message translates to:
  /// **'Nouveautés'**
  String get changelogTitle;

  /// The day a version came out, next to its number in « Nouveautés ».
  ///
  /// In fr, this message translates to:
  /// **'{date}'**
  String changelogDate(DateTime date);

  /// Screen-reader label of a version's heading in « Nouveautés ».
  ///
  /// In fr, this message translates to:
  /// **'{version} · {date}'**
  String changelogHeading(String version, DateTime date);

  /// « Nouveautés », version 0.1.0: what it brings, one short line for the members.
  ///
  /// In fr, this message translates to:
  /// **'Première version de test.'**
  String get release010First;

  /// Line of « Nouveautés » for 0.10.1.
  ///
  /// In fr, this message translates to:
  /// **'Sans secteur ouvert, l\'accueil propose de rejoindre un secteur (ou d\'en créer un, pour un administrateur) : les rues n\'existent plus que dans un secteur.'**
  String get release0101NoSector;

  /// Line of « Nouveautés » for 0.10.0: the team's area is now « secteur » on every screen (#115); « tournée » now names one outing (PLAN §2).
  ///
  /// In fr, this message translates to:
  /// **'La zone de l\'équipe s\'appelle maintenant un « secteur » ; une « tournée » est une sortie dans ce secteur.'**
  String get release0100Sector;

  /// Line of « Nouveautés » for 0.10.0: the status picker replaces the tap cycle and the hold (#107).
  ///
  /// In fr, this message translates to:
  /// **'Rue : touchez une maison ou une porte, puis choisissez son statut. Plus de cycle ni d\'appui long.'**
  String get release0100Picker;

  /// Line of « Nouveautés » for 0.10.0: the fifth status « ⊘ Refusé », counted with the done houses (#113).
  ///
  /// In fr, this message translates to:
  /// **'Nouveau statut « Refusé » pour une maison ou une porte qui ne veut pas de calendrier : elle compte comme faite.'**
  String get release0100Refused;

  /// Line of « Nouveautés » for 0.10.0: the privacy text covers the tournées and calendars (#112).
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité : le texte dit aussi ce qui est gardé des tournées, des dons et des calendriers.'**
  String get release0100Privacy;

  /// Line of « Nouveautés » for 0.10.0: calendars per house, the « − » and the badge (#114).
  ///
  /// In fr, this message translates to:
  /// **'Une maison faite garde son nombre de calendriers : « + Ajouter un don » en ajoute un, « − » en retire un, et la tuile affiche le nombre à partir de 2.'**
  String get release0100Calendars;

  /// Line of « Nouveautés » for 0.10.0: the tournées on screen (#109).
  ///
  /// In fr, this message translates to:
  /// **'Tournées : « Commencer une tournée » sur l\'accueil, le montant de chaque don après « Fait », la liste des dons et le bilan à valider en fin de tournée.'**
  String get release0100Rounds;

  /// Line of « Nouveautés » for 0.10.0: the collecte of the secteur in Équipe (#111).
  ///
  /// In fr, this message translates to:
  /// **'Équipe : « Collecte 2026 » montre l\'argent récolté par le secteur, tournée par tournée, jamais par membre.'**
  String get release0100Collecte;

  /// Line of « Nouveautés » for 0.9.0.
  ///
  /// In fr, this message translates to:
  /// **'Équipe : chaque membre montre le nombre de rues qu\'il couvre ; touchez ce nombre pour voir leurs noms.'**
  String get release090Streets;

  /// Line of « Nouveautés » for 0.9.0.
  ///
  /// In fr, this message translates to:
  /// **'Équipe : « Quitter le secteur » et « Supprimer le secteur » restent en bas de l\'écran.'**
  String get release090Buttons;

  /// Line of « Nouveautés » for 0.9.0.
  ///
  /// In fr, this message translates to:
  /// **'Une longue rue ajoutée juste avant de fermer l\'application est complétée au démarrage suivant, même sans réseau.'**
  String get release090CaughtUp;

  /// Line of « Nouveautés » for 0.8.0.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle icône, et un écran de démarrage aux couleurs de l\'application.'**
  String get release080Icon;

  /// Line of « Nouveautés » for 0.8.0.
  ///
  /// In fr, this message translates to:
  /// **'Le thème sombre est revu, et les écrans restent lisibles avec une grande taille de texte.'**
  String get release080Dark;

  /// Line of « Nouveautés » for 0.8.0.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité : un nouveau texte, et un lien vers la politique complète en ligne.'**
  String get release080Privacy;

  /// « Nouveautés », version 0.7.0: the sector is kept for offline use by itself.
  ///
  /// In fr, this message translates to:
  /// **'Le secteur ouvert reste disponible sans réseau : la carte et les rues sont gardées sur le téléphone, toutes seules.'**
  String get release070Offline;

  /// « Nouveautés », version 0.7.0: sectors that cannot open offline are greyed.
  ///
  /// In fr, this message translates to:
  /// **'Sans réseau, un secteur jamais ouvert sur ce téléphone apparaît en gris dans « Mes secteurs ».'**
  String get release070Greyed;

  /// « Nouveautés », version 0.7.0: the line in Paramètres.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres rappelle que l\'application fonctionne sans réseau.'**
  String get release070Settings;

  /// « Nouveautés », version 0.6.0: « libre » lines stand out.
  ///
  /// In fr, this message translates to:
  /// **'Les rues libres se voient mieux sur la carte : tirets gris foncé sur un liseré blanc.'**
  String get release060FreeLines;

  /// « Nouveautés », version 0.6.0: a ✕ on the street card.
  ///
  /// In fr, this message translates to:
  /// **'La fiche d\'une rue sur la carte se ferme avec ✕.'**
  String get release060CloseCard;

  /// « Nouveautés », version 0.6.0: streets of ex-members are free.
  ///
  /// In fr, this message translates to:
  /// **'Les rues d\'un membre qui a quitté l\'équipe redeviennent libres.'**
  String get release060LeftTeam;

  /// « Nouveautés », version 0.5.1: street lines from the map tiles.
  ///
  /// In fr, this message translates to:
  /// **'Les rues du secteur apparaissent enfin sur la carte : leur tracé vient du fond de carte, et les rues déjà ajoutées reçoivent le leur.'**
  String get release051Lines;

  /// « Nouveautés », version 0.5.1: adding a street no longer waits.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une rue depuis la carte est immédiat, et la route touchée s\'allume tout de suite.'**
  String get release051AddAtOnce;

  /// « Nouveautés », version 0.5.1: take a street from the list.
  ///
  /// In fr, this message translates to:
  /// **'Une rue des « Autres rues du secteur » s\'ouvre sur la carte pour se l\'attribuer.'**
  String get release051TakeFromList;

  /// « Nouveautés », version 0.5.0: the sector's map on Accueil.
  ///
  /// In fr, this message translates to:
  /// **'Accueil montre la carte du secteur : ses rues, ses maisons, une légende et le panneau « Mes rues ».'**
  String get release050Map;

  /// « Nouveautés », version 0.5.0: communes and adding streets.
  ///
  /// In fr, this message translates to:
  /// **'Un secteur a ses communes ; « Ajouter des rues » s\'ouvre dessus, en carte ou en liste : touchez une route, cherchez-la ou saisissez-la.'**
  String get release050AddStreets;

  /// « Nouveautés », version 0.5.0: who covers a street.
  ///
  /// In fr, this message translates to:
  /// **'Chaque rue dit qui la couvre ; on la prend ou la libère.'**
  String get release050Assignees;

  /// « Nouveautés », version 0.5.0: tries with nobody home and when to come back.
  ///
  /// In fr, this message translates to:
  /// **'« Repassé, toujours personne » compte les passages sans réponse, et on choisit le jour et l\'heure où repasser.'**
  String get release050Tries;

  /// « Nouveautés », version 0.4.0: who made the last change.
  ///
  /// In fr, this message translates to:
  /// **'Les fiches des maisons et des portes disent qui les a modifiées en dernier : « Modifié par Léa · 14:02 ».'**
  String get release040LastChangeBy;

  /// « Nouveautés », version 0.4.0: a revoked admin is told.
  ///
  /// In fr, this message translates to:
  /// **'Un administrateur dont les droits ont été retirés en est averti : « Vous n\'êtes plus administrateur. »'**
  String get release040AdminRevoked;

  /// « Nouveautés », version 0.3.0: the whole device identifier.
  ///
  /// In fr, this message translates to:
  /// **'L\'identifiant de l\'appareil s\'affiche en entier dans Paramètres et sur l\'écran de bienvenue.'**
  String get release030DeviceId;

  /// « Nouveautés », version 0.2.0: only admins create a sector.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les administrateurs créent un secteur ; les autres le rejoignent avec un code.'**
  String get release020Admins;

  /// « Nouveautés », version 0.2.0: admins see and manage every sector.
  ///
  /// In fr, this message translates to:
  /// **'Les administrateurs voient tous les secteurs, les gèrent et peuvent les rejoindre directement.'**
  String get release020AllSectors;

  /// « Nouveautés », version 0.2.0: Équipe actions for admins, anyone may leave.
  ///
  /// In fr, this message translates to:
  /// **'Équipe : « Nouveau code », « Retirer » et « Supprimer » sont réservés aux administrateurs ; chacun peut quitter le secteur.'**
  String get release020Team;

  /// « Nouveautés », version 0.2.0: the device identifier in Paramètres.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres affiche l\'identifiant de l\'appareil, à donner pour devenir administrateur.'**
  String get release020DeviceId;

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

  /// Privacy page: the account (PLAN §8.3): its section of PRIVACY.md, word for word.
  ///
  /// In fr, this message translates to:
  /// **'L\'appli ne demande ni adresse e-mail ni numéro de téléphone. Au premier lancement, elle crée un compte anonyme. Vos coéquipiers voient seulement le prénom que vous avez tapé.'**
  String get privacyAccountBody;

  /// Privacy page: section about the data stored.
  ///
  /// In fr, this message translates to:
  /// **'Données enregistrées'**
  String get privacyDataTitle;

  /// Privacy page: what is stored (PLAN §8.3): its section of PRIVACY.md, word for word.
  ///
  /// In fr, this message translates to:
  /// **'Pour chaque rue du secteur : les numéros, leur place sur la carte, ce qui s\'est passé à chaque porte (fait, refusé, personne, à repasser), le jour et l\'heure où repasser, combien de calendriers la maison a pris, et le prénom de qui l\'a noté. Pour chaque tournée validée : son début et sa fin, le nombre de maisons visitées, le nombre et le total des dons par moyen de paiement, et les calendriers offerts, sans le prénom de qui l\'a faite. Un don n\'est jamais lié à une maison : la liste des dons reste sur le téléphone jusqu\'à la validation de la tournée, puis elle est effacée. Rien d\'autre : pas de nom d\'habitant, pas de note.'**
  String get privacyDataBody;

  /// Privacy page: section about the phone's position.
  ///
  /// In fr, this message translates to:
  /// **'Position'**
  String get privacyLocationTitle;

  /// Privacy page: the phone's position (PLAN §8.3): its section of PRIVACY.md, word for word.
  ///
  /// In fr, this message translates to:
  /// **'La position du téléphone sert seulement à vous placer sur la carte, quand vous touchez le bouton. Rien n\'est sauvegardé en dehors de votre téléphone.'**
  String get privacyLocationBody;

  /// Privacy page: section about where the data is kept.
  ///
  /// In fr, this message translates to:
  /// **'Hébergement'**
  String get privacyHostingTitle;

  /// Privacy page: where the data is kept (PLAN §8.3): its section of PRIVACY.md, word for word.
  ///
  /// In fr, this message translates to:
  /// **'Les secteurs sont stockés chez Google Firebase, dans l\'Union européenne. Les cartes viennent d\'OpenFreeMap et les adresses de la Base Adresse Nationale : comme tout site web, ces services voient l\'adresse IP du téléphone quand ils lui envoient des données.'**
  String get privacyHostingBody;

  /// Privacy page: section about deleting the data.
  ///
  /// In fr, this message translates to:
  /// **'Suppression'**
  String get privacyDeletionTitle;

  /// Privacy page: how data is deleted (PLAN §8.3): its section of PRIVACY.md, word for word.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le secteur efface tout ce qu\'il contient. Quand une campagne commence, celle d\'il y a deux ans est effacée. Désinstaller l\'appli efface ce qui est sur le téléphone, y compris les dons d\'une tournée pas encore validée ; ce qui est partagé avec l\'équipe reste jusqu\'à la suppression du secteur.'**
  String get privacyDeletionBody;

  /// Last row of the privacy page, under a divider: opens PRIVACY.md of the repository in the browser (PLAN §5.9, #36).
  ///
  /// In fr, this message translates to:
  /// **'Politique complète en ligne'**
  String get privacyOnline;

  /// What screen readers say for the row that opens the online privacy policy.
  ///
  /// In fr, this message translates to:
  /// **'Politique complète en ligne, s\'ouvre dans le navigateur'**
  String get privacyOnlineSemantics;

  /// Snackbar when the browser could not be opened for the online privacy policy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir le navigateur. La politique est à l\'adresse {url}'**
  String privacyOnlineFailed(String url);

  /// Tooltip and screen-reader name of Accueil's Secteur button, a folded map (PLAN §5.14).
  ///
  /// In fr, this message translates to:
  /// **'Secteur'**
  String get homeSector;

  /// Screen-reader name of the Secteur button when join requests wait (the dot, PLAN §5.14).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Secteur, 1 demande en attente} other{Secteur, {count} demandes en attente}}'**
  String homeSectorWaiting(int count);

  /// Title of Équipe (Team mockup).
  ///
  /// In fr, this message translates to:
  /// **'Secteur {number}'**
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
  /// **'QR code du secteur, code {code}'**
  String teamQrSemantics(String code);

  /// Button of Équipe that opens the phone's share sheet with the join code.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get teamShare;

  /// Text shared by « Partager » in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'Secteur {number} · {centre}\nRejoignez-le dans l\'app Tournée Calendriers avec le code {code}.'**
  String teamShareText(String number, String centre, String code);

  /// Screen-reader name and tooltip of the copy button right of the join code (Équipe, « Nouveau secteur »).
  ///
  /// In fr, this message translates to:
  /// **'Copier le code'**
  String get teamCopyCode;

  /// Short message once the join code is on the clipboard.
  ///
  /// In fr, this message translates to:
  /// **'Code copié'**
  String get teamCodeCopied;

  /// Admin-only button of Équipe: replaces the join code (PLAN §5.8, §5.12).
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

  /// An administrator of the app in Équipe (PLAN §5.12; {name} may already read « Manu (vous) »).
  ///
  /// In fr, this message translates to:
  /// **'{name} · admin'**
  String teamMemberAdmin(String name);

  /// Screen-reader name of the ⋮ of a member (admins only).
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
  /// **'{name} n\'aura plus accès au secteur. Ses marques restent dans les rues.'**
  String teamRemoveBody(String name);

  /// Row of « Rues » in Secteur that opens the Corbeille (PLAN §5.11, §5.14).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Corbeille · vide} =1{Corbeille · 1 élément} other{Corbeille · {count} éléments}}'**
  String teamCorbeille(int count);

  /// Section header of Secteur over « Ajouter des rues » and the Corbeille, with the secteur's street count (PLAN §5.14).
  ///
  /// In fr, this message translates to:
  /// **'Rues ({count})'**
  String teamStreetsHeader(int count);

  /// The same header while the streets are being read from the phone.
  ///
  /// In fr, this message translates to:
  /// **'Rues'**
  String get teamStreetsHeaderCounting;

  /// Second line of « Ajouter des rues » in Secteur (PLAN §5.14).
  ///
  /// In fr, this message translates to:
  /// **'Sur la carte ou depuis la liste des communes'**
  String get teamAddStreetsHint;

  /// Button of Équipe for every member, admins and the creator included (PLAN §5.12).
  ///
  /// In fr, this message translates to:
  /// **'Quitter le secteur'**
  String get teamLeave;

  /// Title of the confirmation before leaving.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le secteur {number} ?'**
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

  /// Admin-only button of Équipe (PLAN §5.12).
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le secteur'**
  String get teamDelete;

  /// Title of the confirmation before deleting the sector.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le secteur {number} ?'**
  String teamDeleteTitle(String number);

  /// Body of the confirmation before deleting the sector (PLAN §8.3).
  ///
  /// In fr, this message translates to:
  /// **'Les rues, les statuts et les membres seront supprimés pour toute l\'équipe. C\'est définitif.'**
  String get teamDeleteBody;

  /// Confirm button of the confirmation before deleting the sector.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get teamDeleteConfirm;

  /// Équipe when no sector is open.
  ///
  /// In fr, this message translates to:
  /// **'Aucun secteur ouvert.'**
  String get teamNoSector;

  /// Équipe when the sector cannot be read (removed, deleted, never read offline).
  ///
  /// In fr, this message translates to:
  /// **'L\'équipe ne peut pas être affichée : le secteur n\'est pas sur ce téléphone, ou vous n\'en faites plus partie.'**
  String get teamUnavailable;

  /// Snackbar of Équipe when a command was refused because a teammate acted first.
  ///
  /// In fr, this message translates to:
  /// **'L\'équipe a changé entre-temps.'**
  String get teamChanged;

  /// Snackbar of Équipe when a new code, joining as an admin or deleting the sector needs the network.
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

  /// Line under the app's name on « Bienvenue » (PLAN §5.1, Welcome mockup).
  ///
  /// In fr, this message translates to:
  /// **'Notez chaque porte de votre secteur et suivez l\'avancement de l\'équipe en direct.'**
  String get welcomeIntro;

  /// Hint under « Votre prénom » on « Bienvenue ».
  ///
  /// In fr, this message translates to:
  /// **'Visible par votre équipe.'**
  String get welcomeNameHelp;

  /// Button of « Bienvenue » and « Mes secteurs » that opens « Nouveau secteur ».
  ///
  /// In fr, this message translates to:
  /// **'Créer un secteur'**
  String get createSectorAction;

  /// Button of « Bienvenue » and « Mes secteurs » that opens « Rejoindre un secteur ».
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre un secteur'**
  String get joinSectorAction;

  /// Screen-reader label of the app's name as the title of the start screen with no sector open: a button that opens « Mes secteurs ».
  ///
  /// In fr, this message translates to:
  /// **'{title}. Mes secteurs'**
  String appTitleSemantics(String title);

  /// Line of « Nouveau secteur » and « Rejoindre » while the phone gets its account.
  ///
  /// In fr, this message translates to:
  /// **'Connexion au serveur…'**
  String get accountSigningIn;

  /// Line of « Nouveau secteur » and « Rejoindre » when the phone could not get its account, with « Réessayer ».
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne : créer ou rejoindre un secteur demande le réseau.'**
  String get accountOffline;

  /// Label of the centre de secours field of « Nouveau secteur ».
  ///
  /// In fr, this message translates to:
  /// **'Centre de secours'**
  String get createCentreLabel;

  /// Screen-reader name of the list of known centres under the field.
  ///
  /// In fr, this message translates to:
  /// **'Centres de secours connus'**
  String get createCentreListSemantics;

  /// Last row of the list of centres: adds the station typed.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter « {name} »'**
  String createCentreAdd(String name);

  /// Under the centre de secours field when the name is too long.
  ///
  /// In fr, this message translates to:
  /// **'Nom limité à {max} caractères.'**
  String createCentreTooLong(int max);

  /// Label of the number field of « Nouveau secteur ».
  ///
  /// In fr, this message translates to:
  /// **'N° de secteur'**
  String get createNumberLabel;

  /// Under the number field when what is typed is not a sector number.
  ///
  /// In fr, this message translates to:
  /// **'Un numéro de 1 à {max}.'**
  String createNumberInvalid(int max);

  /// Label of the year field of « Nouveau secteur ».
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get createYearLabel;

  /// Under the year field when what is typed is not a campaign year.
  ///
  /// In fr, this message translates to:
  /// **'Une année de {first} à {last}.'**
  String createYearInvalid(int first, int last);

  /// Main button of « Nouveau secteur ».
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get createAction;

  /// Warning of « Nouveau secteur » when the number is taken in that centre (CreateTaken mockup).
  ///
  /// In fr, this message translates to:
  /// **'Le secteur {number} du {centre} existe déjà.'**
  String createTakenTitle(String number, String centre);

  /// Under the warning of a sector that exists already.
  ///
  /// In fr, this message translates to:
  /// **'Demandez le code ou le QR code à la personne qui l\'a créée.'**
  String get createTakenBody;

  /// Button under the warning: opens « Rejoindre un secteur ».
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre avec un code'**
  String get createJoinWithCode;

  /// Under « Créer » or « Demander à rejoindre » when the server could not be reached.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réseau. Réessayez une fois connecté.'**
  String get onboardingOffline;

  /// Above the QR code of a sector just created.
  ///
  /// In fr, this message translates to:
  /// **'Secteur {number} · {centre} est prêt. Montrez ce code à l\'équipe.'**
  String createReady(String number, String centre);

  /// Bottom button of « Nouveau secteur » once created: opens the start screen on the new sector.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get createContinue;

  /// Button of « Rejoindre » that opens the camera, and the title of the camera screen.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le QR code'**
  String get joinScan;

  /// Between « Scanner le QR code » and the code boxes.
  ///
  /// In fr, this message translates to:
  /// **'ou saisir le code'**
  String get joinOrType;

  /// Screen-reader name of the second box of the code.
  ///
  /// In fr, this message translates to:
  /// **'Code, suite'**
  String get joinCodeSecondSemantics;

  /// Under the code boxes when a character no code has is typed.
  ///
  /// In fr, this message translates to:
  /// **'Un code n\'a que des lettres et des chiffres, sans 0, O, 1, I ni L.'**
  String get joinInvalidCharacter;

  /// Under the code boxes when the QR code scanned is not a sector's.
  ///
  /// In fr, this message translates to:
  /// **'Ce QR code n\'est pas celui d\'un secteur.'**
  String get joinScanRefused;

  /// When no sector has the code typed or scanned.
  ///
  /// In fr, this message translates to:
  /// **'Aucun secteur n\'a ce code. Vérifiez-le auprès de la personne qui vous l\'a donné.'**
  String get joinUnknownCode;

  /// When the sector of the code cannot be read for lack of network, with « Réessayer ».
  ///
  /// In fr, this message translates to:
  /// **'Pas de réseau : le secteur ne peut pas être affiché.'**
  String get joinLookupOffline;

  /// The sector a join code shows, and the subtitle of « Demande envoyée ».
  ///
  /// In fr, this message translates to:
  /// **'Secteur {number} · {centre}'**
  String joinPreviewTitle(String number, String centre);

  /// Under the sector a join code shows.
  ///
  /// In fr, this message translates to:
  /// **'Campagne {year}'**
  String joinPreviewCampaign(String year);

  /// Main button of « Rejoindre un secteur »: sends the request.
  ///
  /// In fr, this message translates to:
  /// **'Demander à rejoindre'**
  String get joinRequest;

  /// When the sector of the code is already one of the member's.
  ///
  /// In fr, this message translates to:
  /// **'Ce secteur est déjà dans « Mes secteurs ».'**
  String get joinAlreadyJoined;

  /// Over the camera of « Scanner le QR code ».
  ///
  /// In fr, this message translates to:
  /// **'Visez le QR code du secteur.'**
  String get scannerHint;

  /// On the camera screen when the camera is refused or missing.
  ///
  /// In fr, this message translates to:
  /// **'L\'appareil photo n\'est pas disponible. Saisissez le code à la main.'**
  String get scannerUnavailable;

  /// Text of « Demande envoyée » (PLAN §5.2, JoinPending mockup).
  ///
  /// In fr, this message translates to:
  /// **'Un membre du secteur doit vous accepter. Demandez-le à la personne qui vous a donné le code.'**
  String get joinPendingBody;

  /// Note of « Demande envoyée ».
  ///
  /// In fr, this message translates to:
  /// **'Cet écran s\'ouvrira tout seul sur le secteur dès que vous serez accepté.'**
  String get joinPendingOpensItself;

  /// Screen-reader label of the clock of « Demande envoyée ».
  ///
  /// In fr, this message translates to:
  /// **'Demande en attente'**
  String get joinPendingSemantics;

  /// Button of « Demande envoyée »: withdraws the request.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get joinPendingCancel;

  /// Message once the member's request was refused.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get joinRefused;

  /// Message over the next screen once the server said an admin removed the member from a sector, which the phone then forgot (PLAN §5.3).
  ///
  /// In fr, this message translates to:
  /// **'Vous avez été retiré du secteur {number}.'**
  String sectorRemoved(String number);

  /// Message over the next screen once the server said a sector of the member was deleted, which the phone then forgot (PLAN §5.3).
  ///
  /// In fr, this message translates to:
  /// **'Le secteur {number} a été supprimé.'**
  String sectorDeleted(String number);

  /// Message over the next screen once the server said the phone is no longer an admin, so a sector it only visited was forgotten (PLAN §5.12).
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes plus administrateur : le secteur {number} est retiré de Mes secteurs.'**
  String sectorAdminRevoked(String number);

  /// Last row of Paramètres › Application: the phone's uid (PLAN §5.12).
  ///
  /// In fr, this message translates to:
  /// **'Identifiant de l\'appareil'**
  String get deviceIdLabel;

  /// Paramètres, under the phone's uid when it is an admin's (PLAN §5.12).
  ///
  /// In fr, this message translates to:
  /// **'Administrateur'**
  String get deviceIdIsAdmin;

  /// Screen-reader name and tooltip of the copy button of the phone's uid.
  ///
  /// In fr, this message translates to:
  /// **'Copier l\'identifiant de l\'appareil'**
  String get deviceIdCopy;

  /// Snackbar once the phone's uid is on the clipboard.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant copié'**
  String get deviceIdCopied;

  /// Paramètres row of the phone's uid when the phone has no account and is offline.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte : connectez-vous au réseau.'**
  String get deviceIdNoAccount;

  /// Admin-only link of « Mes secteurs » to every sector of the app, and that screen's title (PLAN §5.12).
  ///
  /// In fr, this message translates to:
  /// **'Tous les secteurs'**
  String get mySectorsAll;

  /// Second line of a sector an admin opened without being in its team (Switcher mockup).
  ///
  /// In fr, this message translates to:
  /// **'{centre} · administrateur'**
  String mySectorsVisited(String centre);

  /// Screen-reader label of a visited sector not open in « Mes secteurs ».
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}, administrateur, ouvrir'**
  String mySectorsVisitedSemantics(String title, String centre);

  /// Screen-reader label of the open sector in « Mes secteurs » when the admin only visits it.
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}, administrateur, secteur ouvert'**
  String mySectorsVisitedOpenSemantics(String title, String centre);

  /// Second line of a sector greyed in « Mes secteurs » while offline: it was never downloaded on this phone, so it cannot open (Switcher mockup, PLAN §5.3).
  ///
  /// In fr, this message translates to:
  /// **'{centre} · Disponible avec réseau'**
  String mySectorsUnavailable(String centre);

  /// Screen-reader label of a sector greyed in « Mes secteurs » while offline (announced as disabled too).
  ///
  /// In fr, this message translates to:
  /// **'{title}, {centre}, disponible avec réseau'**
  String mySectorsUnavailableSemantics(String title, String centre);

  /// Under the title of « Tous les secteurs » (AllSectors mockup).
  ///
  /// In fr, this message translates to:
  /// **'Administrateur · {count, plural, =0{aucun secteur} =1{1 secteur} other{{count} secteurs}}'**
  String allSectorsSubtitle(int count);

  /// Second line of a sector of « Tous les secteurs »: its active members (« Aucun membre » in red).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun membre} =1{1 membre} other{{count} membres}}'**
  String allSectorsMembers(int count);

  /// Second line of a sector the admin is an active member of.
  ///
  /// In fr, this message translates to:
  /// **'{members} · vous en êtes membre'**
  String allSectorsMine(String members);

  /// Second line of a sector where join requests wait, beside a red dot.
  ///
  /// In fr, this message translates to:
  /// **'{details} · {count, plural, =1{1 demande en attente} other{{count} demandes en attente}}'**
  String allSectorsWaiting(String details, int count);

  /// Screen-reader label of a sector of « Tous les secteurs »: the dot is said in the details.
  ///
  /// In fr, this message translates to:
  /// **'{title}, {details}, ouvrir'**
  String allSectorsRowSemantics(String title, String details);

  /// « Tous les secteurs » when the server cannot be reached; « Réessayer » under it.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réseau : la liste ne peut pas être affichée.'**
  String get allSectorsOffline;

  /// Under « Créer », in « Toutes les sectors », or in a snackbar of Équipe and of the admin banner, when the server refused an admin's command because the phone's admins/{uid} was removed (PLAN §5.12).
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes plus administrateur.'**
  String get notAdminAnyMore;

  /// Under the list of « Tous les secteurs » (AllSectors mockup).
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez un secteur pour le gérer : code, équipe, rues. Vous n\'y entrez comme membre que si vous le rejoignez.'**
  String get allSectorsHint;

  /// « Tous les secteurs » when the app has none.
  ///
  /// In fr, this message translates to:
  /// **'Aucun secteur pour l\'instant.'**
  String get allSectorsEmpty;

  /// Banner on Accueil when an admin opened a sector they are not in (HomeAdmin mockup).
  ///
  /// In fr, this message translates to:
  /// **'Administrateur · pas membre'**
  String get adminBannerTitle;

  /// Second line of the banner of an admin who is not in the sector.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes pas dans l\'équipe de ce secteur.'**
  String get adminBannerBody;

  /// Button of the banner: the admin joins the team at once (PLAN §5.12).
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get adminBannerJoin;

  /// Button of Équipe for an admin who only visits the sector: forgets it on the phone, writes nothing (PLAN §5.12).
  ///
  /// In fr, this message translates to:
  /// **'Retirer de Mes secteurs'**
  String get teamForgetVisit;

  /// « supprimée par un administrateur »: an admin of the app who is not in the team (PLAN §5.12).
  ///
  /// In fr, this message translates to:
  /// **'un administrateur'**
  String get corbeilleAdmin;

  /// What screen readers say for the map (Accueil, Ajouter des rues).
  ///
  /// In fr, this message translates to:
  /// **'Carte du secteur'**
  String get mapLabel;

  /// Round button over the map that centres it on the phone's position (PLAN §5.3); said by screen readers and shown as its tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Me localiser'**
  String get mapLocateMe;

  /// Snackbar after « Me localiser » when the phone's location service (GPS) is off.
  ///
  /// In fr, this message translates to:
  /// **'La localisation du téléphone est désactivée.'**
  String get mapLocationServiceOff;

  /// Snackbar after « Me localiser » when the user refused the system's location dialog; the next tap asks again.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez la localisation pour vous situer sur la carte.'**
  String get mapLocationRefused;

  /// Snackbar after « Me localiser » when the location access was refused for good; its action opens the phone's settings.
  ///
  /// In fr, this message translates to:
  /// **'La localisation est refusée pour l\'application. Autorisez-la dans les réglages.'**
  String get mapLocationRefusedForever;

  /// Action of the snackbar above: opens the app's page of the phone's settings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get mapLocationSettings;

  /// Snackbar after « Me localiser » when the phone gives no position (no GPS fix yet).
  ///
  /// In fr, this message translates to:
  /// **'Position introuvable pour l\'instant. Réessayez dans un moment.'**
  String get mapPositionUnavailable;

  /// Gallery section: the map widget, and the title of its debug screen.
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get galleryMap;

  /// Gallery button opening the debug screen of the map widget.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la carte'**
  String get galleryOpenMap;

  /// Debug map screen: shows or hides the highlighted « selected road ».
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une route'**
  String get galleryMapSelectRoad;

  /// Debug map screen: a street of the sample was tapped.
  ///
  /// In fr, this message translates to:
  /// **'Rue touchée : {street}'**
  String galleryMapStreetTapped(String street);

  /// Debug map screen: the map was tapped outside the sample streets.
  ///
  /// In fr, this message translates to:
  /// **'Touché en {latitude}, {longitude}'**
  String galleryMapTapped(String latitude, String longitude);

  /// Label of the communes of « Nouveau secteur » (#78), and header of the communes in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'Communes'**
  String get communesLabel;

  /// Placeholder of the field that searches a commune to add to a sector (« Nouveau secteur », Équipe).
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une commune…'**
  String get communeAddHint;

  /// Screen-reader label and tooltip of the ✕ of a commune chip or row.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name}'**
  String communeRemove(String name);

  /// Header of the sector's communes in Équipe.
  ///
  /// In fr, this message translates to:
  /// **'Communes ({count})'**
  String teamCommunesHeader(int count);

  /// Button under the communes of Équipe, and title of the sheet it opens.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une commune'**
  String get teamAddCommune;

  /// Snackbar of Équipe: the commune picked is already one of the sector's.
  ///
  /// In fr, this message translates to:
  /// **'Cette commune est déjà dans le secteur.'**
  String get teamCommuneAlreadyIn;

  /// Snackbar of Équipe: the sector covers as many communes as it may.
  ///
  /// In fr, this message translates to:
  /// **'Un secteur a au plus {max} communes.'**
  String teamTooManyCommunes(int max);

  /// Row of « Rues » in Secteur, and title of the screen it opens (PLAN §5.4, §5.14).
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des rues'**
  String get addStreetsTitle;

  /// Screen-reader name of the « Carte | Liste » tabs of « Ajouter des rues ».
  ///
  /// In fr, this message translates to:
  /// **'Ajouter depuis'**
  String get addStreetsModes;

  /// Tab of « Ajouter des rues »: the map.
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get addStreetsMapTab;

  /// Tab of « Ajouter des rues »: the checklist of a commune's streets.
  ///
  /// In fr, this message translates to:
  /// **'Liste'**
  String get addStreetsListTab;

  /// Right of a street of the « Liste » tab that the sector already has.
  ///
  /// In fr, this message translates to:
  /// **'déjà dans le secteur'**
  String get alreadyInSector;

  /// Button of the « Liste » tab: adds the ticked streets to the sector.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Ajouter} =1{Ajouter 1 rue} other{Ajouter {count} rues}}'**
  String addButton(int count);

  /// In place of the button of the « Liste » tab while streets are added.
  ///
  /// In fr, this message translates to:
  /// **'Ajout en cours… {done}/{total}'**
  String addProgress(int done, int total);

  /// Snackbar once every street ticked in the « Liste » tab is in the sector.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune nouvelle rue} =1{1 rue ajoutée au secteur} other{{count} rues ajoutées au secteur}}'**
  String addDone(int count);

  /// Snackbar once the streets ticked are in the sector, some back from the Corbeille.
  ///
  /// In fr, this message translates to:
  /// **'{added, plural, =1{1 rue ajoutée} other{{added} rues ajoutées}}, {restored, plural, =1{1 restaurée} other{{restored} restaurées}}'**
  String addDoneAndRestored(int added, int restored);

  /// Under the checklist of the « Liste » tab when some streets could not be added.
  ///
  /// In fr, this message translates to:
  /// **'{added, plural, =0{Aucune rue ajoutée} =1{1 rue ajoutée} other{{added} rues ajoutées}}, {failed, plural, =1{1 en échec} other{{failed} en échec}}. {reason} Les rues encore cochées restent à ajouter.'**
  String addPartial(int added, int failed, String reason);

  /// Header of Accueil's panel (PLAN §5.14): the doors done of every street of the sector, out of all their doors.
  ///
  /// In fr, this message translates to:
  /// **'Rues · {done}/{total}'**
  String homeStreets(int done, int total);

  /// What screen readers say for « Rues · 31/50 ».
  ///
  /// In fr, this message translates to:
  /// **'Rues, {done} sur {total} faits'**
  String homeStreetsSemantics(int done, int total);

  /// Accueil's panel when the sector has no street at all.
  ///
  /// In fr, this message translates to:
  /// **'Aucune rue dans le secteur pour l\'instant.'**
  String get homeNoStreet;

  /// Screen-reader name of the handle of Accueil's panel: shows the whole list of streets.
  ///
  /// In fr, this message translates to:
  /// **'Afficher toute la liste'**
  String get homePanelExpand;

  /// Screen-reader name of the handle of Accueil's panel once it shows the whole list: brings back the map.
  ///
  /// In fr, this message translates to:
  /// **'Réduire la liste'**
  String get homePanelReduce;

  /// The map's legend once folded: a small chip that unfolds it.
  ///
  /// In fr, this message translates to:
  /// **'Légende'**
  String get mapLegend;

  /// Screen-reader name of the folded legend chip.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la légende'**
  String get mapLegendShow;

  /// Screen-reader name of the unfolded legend: a tap folds it.
  ///
  /// In fr, this message translates to:
  /// **'Masquer la légende'**
  String get mapLegendHide;

  /// Legend of the map: a street with every door done (green line).
  ///
  /// In fr, this message translates to:
  /// **'faite'**
  String get mapLegendStreetDone;

  /// Legend of the map: a street partly visited (orange line).
  ///
  /// In fr, this message translates to:
  /// **'en partie'**
  String get mapLegendStreetPartial;

  /// Legend of the map: a street with nothing visited yet (blue line).
  ///
  /// In fr, this message translates to:
  /// **'à faire'**
  String get mapLegendStreetToDo;

  /// Placeholder and screen-reader name of the search box of « Ajouter des rues » (Pick mockup).
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une rue'**
  String get addStreetsSearchHint;

  /// Tooltip of the ✕ of the search box: empties it and closes the results.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la recherche'**
  String get addStreetsSearchClear;

  /// Under the search box when the BAN finds no street of that name in the sector's communes.
  ///
  /// In fr, this message translates to:
  /// **'Aucune rue trouvée.'**
  String get addStreetsSearchNone;

  /// Under the search box when the phone is offline.
  ///
  /// In fr, this message translates to:
  /// **'Connexion nécessaire pour chercher une rue.'**
  String get addStreetsSearchNoNetwork;

  /// Under the search box when the address service failed.
  ///
  /// In fr, this message translates to:
  /// **'Le service des adresses ne répond pas. Réessayez dans un moment.'**
  String get addStreetsSearchError;

  /// Screen-reader name and tooltip of the ✕ at the top right of the street card, which closes it like a tap elsewhere on the map or the back gesture (PLAN §5.3, §5.4).
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get streetCardClose;

  /// Chip of the card of a street of the sector: its doors done.
  ///
  /// In fr, this message translates to:
  /// **'{done}/{total} faits'**
  String streetCardProgress(int done, int total);

  /// What screen readers say for « 31/42 faits ».
  ///
  /// In fr, this message translates to:
  /// **'{done} sur {total} faits'**
  String streetCardProgressSemantics(int done, int total);

  /// Button of the card of a street of the sector: opens the street.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir'**
  String get streetCardOpen;

  /// Title of the manual street form (PLAN §5.5, Manual mockup).
  ///
  /// In fr, this message translates to:
  /// **'Rue à la main'**
  String get manualTitle;

  /// Label of the name field of « Rue à la main ».
  ///
  /// In fr, this message translates to:
  /// **'Nom de la rue'**
  String get manualName;

  /// Label of the commune of « Rue à la main ».
  ///
  /// In fr, this message translates to:
  /// **'Commune'**
  String get manualCommune;

  /// Over the commune search of « Rue à la main » for a sector without commune nor street.
  ///
  /// In fr, this message translates to:
  /// **'Le secteur n\'a pas encore de commune : cherchez celle de la rue.'**
  String get manualNoCommune;

  /// Label of the first number of the range of « Rue à la main ».
  ///
  /// In fr, this message translates to:
  /// **'Du n°'**
  String get manualFrom;

  /// Label of the last number of the range of « Rue à la main ».
  ///
  /// In fr, this message translates to:
  /// **'Au n°'**
  String get manualTo;

  /// Screen-reader name of « Les deux | Impairs | Pairs ».
  ///
  /// In fr, this message translates to:
  /// **'Côtés'**
  String get manualSides;

  /// Both sides of the street.
  ///
  /// In fr, this message translates to:
  /// **'Les deux'**
  String get manualBothSides;

  /// Odd numbers only.
  ///
  /// In fr, this message translates to:
  /// **'Impairs'**
  String get manualOddSide;

  /// Even numbers only.
  ///
  /// In fr, this message translates to:
  /// **'Pairs'**
  String get manualEvenSide;

  /// Label of the extra numbers of « Rue à la main ».
  ///
  /// In fr, this message translates to:
  /// **'Numéros en plus'**
  String get manualExtras;

  /// Under the extra numbers field.
  ///
  /// In fr, this message translates to:
  /// **'Séparés par des virgules.'**
  String get manualExtrasHelper;

  /// Under the preview of « Rue à la main ».
  ///
  /// In fr, this message translates to:
  /// **'Fonctionne sans réseau. La rue n\'aura pas de tracé sur la carte.'**
  String get manualOffline;

  /// Button of « Rue à la main ».
  ///
  /// In fr, this message translates to:
  /// **'Ajouter la rue'**
  String get manualAdd;

  /// Snackbar once a street typed in by hand is added.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » ajoutée au secteur.'**
  String manualAdded(String name);

  /// Outlined button under the totals of Accueil's panel (RunStart mockup), for an active member of the open secteur while no tournée is on (PLAN §5.13).
  ///
  /// In fr, this message translates to:
  /// **'Commencer une tournée'**
  String get roundStart;

  /// Snackbar of Accueil when « Commencer une tournée » is tapped while a tournée started in another secteur is still on: one tournée at a time on a phone.
  ///
  /// In fr, this message translates to:
  /// **'Une tournée est déjà en cours dans un autre secteur.'**
  String get roundAlreadyOnElsewhere;

  /// Snackbar of the street screen and the building grid when a house, a door or the building's « Repasser » is tapped while no tournée is on (StreetIdle mockup, PLAN §5.14): houses are marked only during a tournée.
  ///
  /// In fr, this message translates to:
  /// **'Commencez une tournée pour marquer les maisons.'**
  String get markingNeedsRound;

  /// Action of the « Commencez une tournée… » snackbar: starts the tournée (offline too) and stays on the street.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get markingStartRound;

  /// Snackbar, with no action, when an admin visiting the secteur (never in a tournée) taps a house, a door or the building's « Repasser » (PLAN §5.14).
  ///
  /// In fr, this message translates to:
  /// **'Seuls les membres en tournée marquent les maisons.'**
  String get markingMembersOnly;

  /// How long the tournée has been on, in its first minute: « En tournée · moins d'une minute » (PLAN §5.13, §5.14).
  ///
  /// In fr, this message translates to:
  /// **'moins d\'une minute'**
  String get roundElapsedJustStarted;

  /// How long the tournée has been on, under an hour: « 20 min ».
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String roundElapsedMinutes(int minutes);

  /// How long the tournée has been on: « 1 h 20 »; minutes with two digits.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h {minutes}'**
  String roundElapsedHours(int hours, String minutes);

  /// How long the tournée has been on, on a whole hour: « 2 h ».
  ///
  /// In fr, this message translates to:
  /// **'{hours} h'**
  String roundElapsedWholeHours(int hours);

  /// First line of the « En tournée » band on top of Accueil, the street screen and the building grid (RunHome, RunStreet mockups, PLAN §5.14): « En tournée · 1 h 20 ».
  ///
  /// In fr, this message translates to:
  /// **'En tournée · {elapsed}'**
  String roundBandSince(String elapsed);

  /// Second line of the « En tournée » band, which opens « Dons de la tournée »: « 19 dons · 280 € › ».
  ///
  /// In fr, this message translates to:
  /// **'{totals} ›'**
  String roundBandTotals(String totals);

  /// What screen readers hear for the left part of the « En tournée » band, a button that opens « Dons de la tournée »: « En tournée depuis 1 h 20, 19 dons, 280 €. Voir les dons ».
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{En tournée depuis {elapsed}, {count} don, {amount}. Voir les dons} other{En tournée depuis {elapsed}, {count} dons, {amount}. Voir les dons}}'**
  String roundBandSpoken(String elapsed, int count, String amount);

  /// The paid dons of the tournée and their money (PLAN §5.13): « 19 dons · 280 € », « 1 don · 10 € », « 0 don · 0 € ». A free calendar is not a don of money.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} don · {amount}} other{{count} dons · {amount}}}'**
  String roundTotals(int count, String amount);

  /// The ink pill (■) at the right of the « En tournée » band, which opens « Bilan de la tournée ».
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get roundFinish;

  /// What screen readers hear for « ■ Terminer ».
  ///
  /// In fr, this message translates to:
  /// **'Terminer la tournée'**
  String get roundFinishSpoken;

  /// An amount in whole euros: « 10 € », « 1 280 € ».
  ///
  /// In fr, this message translates to:
  /// **'{euros} €'**
  String amountEuros(int euros);

  /// An amount with cents: « 7,50 € ».
  ///
  /// In fr, this message translates to:
  /// **'{euros},{cents} €'**
  String amountEurosCents(int euros, String cents);

  /// An amount with cents as « Montant » shows it, prefilled in « Modifier le don »: « 7,50 ».
  ///
  /// In fr, this message translates to:
  /// **'{euros},{cents}'**
  String amountInputCents(int euros, String cents);

  /// Title of the step of the status picker after « Fait » during a tournée, or « + Ajouter un don » (PLAN §5.6, RunStreet mockup).
  ///
  /// In fr, this message translates to:
  /// **'Montant du don'**
  String get donationStepTitle;

  /// Screen-reader name and tooltip of the ✕ of « Montant du don » after « Fait » on a house: no calendar was handed over, the house goes back as it was.
  ///
  /// In fr, this message translates to:
  /// **'Annuler : la maison reprend son statut'**
  String get donationCancelHouse;

  /// The same on a door of a building.
  ///
  /// In fr, this message translates to:
  /// **'Annuler : la porte reprend son statut'**
  String get donationCancelDoor;

  /// Screen-reader name of the choice « Espèces | Chèque | Carte ».
  ///
  /// In fr, this message translates to:
  /// **'Moyen de paiement'**
  String get paymentMethodGroup;

  /// A payment method: on the choice, in « Dons de la tournée » and in the « Bilan ».
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get paymentCash;

  /// A payment method, on the choice and in « Dons de la tournée ».
  ///
  /// In fr, this message translates to:
  /// **'Chèque'**
  String get paymentCheque;

  /// A payment method, on the choice (short).
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get paymentCard;

  /// A payment method in « Dons de la tournée » and in the « Bilan ».
  ///
  /// In fr, this message translates to:
  /// **'Carte bancaire'**
  String get paymentCardLong;

  /// The cheques line of « ARGENT RÉCOLTÉ » in the « Bilan ».
  ///
  /// In fr, this message translates to:
  /// **'Chèques'**
  String get paymentCheques;

  /// Button of « Montant du don », and title of the step it opens, where the amount is typed.
  ///
  /// In fr, this message translates to:
  /// **'Autre montant'**
  String get donationOtherAmount;

  /// Button of « Montant du don » (a calendar given for free), and such a don in « Dons de la tournée ».
  ///
  /// In fr, this message translates to:
  /// **'Calendrier offert'**
  String get donationFreeCalendar;

  /// Label of the amount field of « Autre montant », « Nouveau don » and « Modifier le don ».
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get amountLabel;

  /// After the amount typed in « Montant ».
  ///
  /// In fr, this message translates to:
  /// **'€'**
  String get amountSuffix;

  /// Under the amount field of « Autre montant ».
  ///
  /// In fr, this message translates to:
  /// **'Par exemple 7,50'**
  String get amountHint;

  /// Under « Montant » when « Valider » is tapped with nothing typed.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez un montant.'**
  String get amountEmpty;

  /// Under « Montant » when what is typed is not a number, or 0.
  ///
  /// In fr, this message translates to:
  /// **'Entrez un montant valide.'**
  String get amountNotValid;

  /// Under « Montant » when three digits follow the comma.
  ///
  /// In fr, this message translates to:
  /// **'Deux chiffres après la virgule au plus.'**
  String get amountTooManyDecimals;

  /// Under « Montant » past 1 000 €.
  ///
  /// In fr, this message translates to:
  /// **'1 000 € au plus par don.'**
  String get amountTooLarge;

  /// Button of « Autre montant », « Nouveau don » and « Modifier le don »: the don is kept.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get donationValidate;

  /// What a paid don is in a snackbar: « 10 € en espèces ».
  ///
  /// In fr, this message translates to:
  /// **'{amount} en {method}'**
  String donationPaid(String amount, String method);

  /// The cash method inside a sentence: « 10 € en espèces ».
  ///
  /// In fr, this message translates to:
  /// **'espèces'**
  String get paymentCashWord;

  /// The cheque method inside a sentence: « 5 € en chèque ».
  ///
  /// In fr, this message translates to:
  /// **'chèque'**
  String get paymentChequeWord;

  /// The card method inside a sentence: « 10 € en carte ».
  ///
  /// In fr, this message translates to:
  /// **'carte'**
  String get paymentCardWord;

  /// A free calendar inside a sentence: « N° 7 fait · calendrier offert ».
  ///
  /// In fr, this message translates to:
  /// **'calendrier offert'**
  String get donationFreeWord;

  /// Snackbar once « Fait » and its don are stored during a tournée (PLAN §5.6), with « Annuler », which takes the don back too: « N° 7 fait · 10 € en espèces ».
  ///
  /// In fr, this message translates to:
  /// **'N° {number} fait · {donation}'**
  String houseDoneWithDonation(String number, String donation);

  /// The same for a door of a building: « Porte 51 : fait · 10 € en espèces ».
  ///
  /// In fr, this message translates to:
  /// **'Porte {label} : fait · {donation}'**
  String doorDoneWithDonation(String label, String donation);

  /// Snackbar once « + Ajouter un don » gave a don for a house already done: « N° 9 · 5 € en chèque ajouté ».
  ///
  /// In fr, this message translates to:
  /// **'N° {number} · {donation} ajouté'**
  String houseDonationAdded(String number, String donation);

  /// The same for a door: « Porte 51 · 5 € en chèque ajouté ».
  ///
  /// In fr, this message translates to:
  /// **'Porte {label} · {donation} ajouté'**
  String doorDonationAdded(String label, String donation);

  /// « + Ajouter un don » of the status picker on a house done during a tournée (RunStreet mockup), and the button of « Dons de la tournée » (RunDons mockup).
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un don'**
  String get addDonation;

  /// Title of the list of the tournée's dons (RunDons mockup).
  ///
  /// In fr, this message translates to:
  /// **'Dons de la tournée'**
  String get donsTitle;

  /// « Dons de la tournée » before the first don.
  ///
  /// In fr, this message translates to:
  /// **'Aucun don pour l\'instant.'**
  String get donsEmpty;

  /// Title of the sheet « Ajouter un don » of « Dons de la tournée » opens: money from someone with no house.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau don'**
  String get donationNewTitle;

  /// Title of the sheet a don of « Dons de la tournée » opens (RunDon mockup).
  ///
  /// In fr, this message translates to:
  /// **'Modifier le don'**
  String get donationEditTitle;

  /// Link of « Modifier le don »: the don leaves the tournée.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce don'**
  String get donationRemove;

  /// Title of the screen « Terminer » opens (RunRecap mockup).
  ///
  /// In fr, this message translates to:
  /// **'Bilan de la tournée'**
  String get recapTitle;

  /// Under « Bilan de la tournée »: « samedi 24 octobre, de 14 h 05 à 18 h 20 » (shown with a capital first letter).
  ///
  /// In fr, this message translates to:
  /// **'{day}, de {start} à {end}'**
  String recapWhen(DateTime day, String start, String end);

  /// A time of day: « 14 h 05 »; minutes with two digits.
  ///
  /// In fr, this message translates to:
  /// **'{hour} h {minute}'**
  String clockTime(int hour, String minute);

  /// A time of day on the hour: « 18 h ».
  ///
  /// In fr, this message translates to:
  /// **'{hour} h'**
  String clockTimeWhole(int hour);

  /// Under the first figure of the « Bilan » (« 23 maisons visitées »).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{maison visitée} other{maisons visitées}}'**
  String recapHouses(int count);

  /// Under the second figure of the « Bilan » (« 19 dons »).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{don} other{dons}}'**
  String recapDons(int count);

  /// Under the third figure of the « Bilan » (« 2 calendriers offerts »).
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{calendrier offert} other{calendriers offerts}}'**
  String recapFree(int count);

  /// Section header of the « Bilan » (shown in capitals).
  ///
  /// In fr, this message translates to:
  /// **'Argent récolté'**
  String get recapMoney;

  /// How many dons of a method, in the « Bilan »: « 15 dons », « 1 don », « 0 don ».
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} don} other{{count} dons}}'**
  String donCount(int count);

  /// Last line of « ARGENT RÉCOLTÉ ».
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get recapTotal;

  /// Row of the « Bilan » that opens « Dons de la tournée ».
  ///
  /// In fr, this message translates to:
  /// **'Voir les dons'**
  String get recapSeeDons;

  /// Red button of the « Bilan »: asks, then sends the summary.
  ///
  /// In fr, this message translates to:
  /// **'Valider la tournée'**
  String get recapValidate;

  /// Button of the « Bilan »: back, the tournée goes on.
  ///
  /// In fr, this message translates to:
  /// **'Continuer la tournée'**
  String get recapContinue;

  /// Title of the dialog « Valider la tournée » opens.
  ///
  /// In fr, this message translates to:
  /// **'Valider la tournée ?'**
  String get recapConfirmTitle;

  /// Body of that dialog: a validated tournée is never changed.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pourrez plus la modifier.'**
  String get recapConfirmBody;

  /// Button of that dialog that validates the tournée.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get recapConfirmOk;

  /// Header of the collecte row of Équipe (shown in capitals, RunTeam mockup) and title of the Collecte screen (Cash mockup, PLAN §5.13).
  ///
  /// In fr, this message translates to:
  /// **'Collecte {campaign}'**
  String collecteTitle(String campaign);

  /// First line of the collecte row of Équipe: the money of every validated tournée of the campaign (« 600 € récoltés »). Never per member.
  ///
  /// In fr, this message translates to:
  /// **'{amount} récoltés'**
  String teamCollecteRaised(String amount);

  /// Second line of the collecte row of Équipe: « 41 dons en 4 tournées », « 1 don en 1 tournée », « 0 don en 0 tournée ».
  ///
  /// In fr, this message translates to:
  /// **'{dons} en {rounds, plural, one{{rounds} tournée} other{{rounds} tournées}}'**
  String teamCollecteDons(String dons, int rounds);

  /// What screen readers hear for the collecte row of Équipe, a button that opens the Collecte screen.
  ///
  /// In fr, this message translates to:
  /// **'{title} : {raised}, {dons}'**
  String teamCollecteSpoken(String title, String raised, String dons);

  /// Under the title of the Collecte screen.
  ///
  /// In fr, this message translates to:
  /// **'Secteur {number} · tournées validées'**
  String collecteSubtitle(String number);

  /// Section header of the Collecte screen over the totals of every validated tournée (shown in capitals): « TOTAL DES 4 TOURNÉES ».
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Total des tournées} =1{Total de la tournée} other{Total des {count} tournées}}'**
  String collecteTotalHeader(int count);

  /// Line of the totals of the Collecte screen: how many calendars were given for free, with no amount.
  ///
  /// In fr, this message translates to:
  /// **'Calendriers offerts'**
  String get collecteFree;

  /// Section header of the Collecte screen over the validated tournées, newest first (shown in capitals).
  ///
  /// In fr, this message translates to:
  /// **'Tournées'**
  String get collecteRoundsHeader;

  /// A validated tournée in the Collecte screen: « Sam. 24 oct. · 14:05 → 18:20 » (shown with a capital first letter). Never its member.
  ///
  /// In fr, this message translates to:
  /// **'{day} · {start} → {end}'**
  String collecteRoundWhen(DateTime day, DateTime start, DateTime end);

  /// Under a validated tournée in the Collecte screen: « 23 maisons, 19 dons ».
  ///
  /// In fr, this message translates to:
  /// **'{houses, plural, one{{houses} maison} other{{houses} maisons}}, {dons}'**
  String collecteRoundLine(int houses, String dons);

  /// What screen readers hear for a folded tournée of the Collecte screen; a tap shows its methods.
  ///
  /// In fr, this message translates to:
  /// **'{when}, {amount}, afficher le détail'**
  String collecteRoundShow(String when, String amount);

  /// What screen readers hear for an unfolded tournée of the Collecte screen; a tap folds it.
  ///
  /// In fr, this message translates to:
  /// **'{when}, {amount}, masquer le détail'**
  String collecteRoundHide(String when, String amount);

  /// At the bottom of the Collecte screen.
  ///
  /// In fr, this message translates to:
  /// **'Une tournée validée ne peut plus être modifiée. Les dons ne sont jamais associés à une adresse.'**
  String get collecteNeverChanged;

  /// The Collecte screen when no secteur is open or its tournées cannot be read.
  ///
  /// In fr, this message translates to:
  /// **'La collecte ne peut pas être affichée.'**
  String get collecteUnavailable;

  /// Selection sheet of « Ajouter des rues » with nothing ticked (PLAN §5.14, Pick mockup).
  ///
  /// In fr, this message translates to:
  /// **'Touchez les rues à ajouter ou tracez une zone.'**
  String get addStreetsPickHint;

  /// Title of the selection sheet: how many streets are ticked.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 rue sélectionnée} other{{count} rues sélectionnées}}'**
  String addStreetsPicked(int count);

  /// Under the name of a ticked street in the selection sheet: « Villefranche-sur-Saône · 19 numéros ».
  ///
  /// In fr, this message translates to:
  /// **'{commune} · {numbers}'**
  String addStreetsPickedFacts(String commune, String numbers);

  /// How many numbers a ticked street brings, after its commune.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{aucun numéro} =1{1 numéro} other{{count} numéros}}'**
  String addStreetsNumbers(int count);

  /// Screen-reader name and tooltip of the ✕ of a ticked street: unticks it.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name}'**
  String addStreetsUntick(String name);

  /// Screen-reader name of the handle of the selection sheet: leaves only its title.
  ///
  /// In fr, this message translates to:
  /// **'Réduire la sélection'**
  String get addStreetsFold;

  /// Screen-reader name of the handle of the folded selection sheet: shows the ticked streets again.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la sélection'**
  String get addStreetsUnfold;

  /// In the selection sheet while the street tapped is looked up.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de la rue…'**
  String get addStreetsLookingUp;

  /// Snackbar when the street tapped on the map is in the sector already: nothing is ticked.
  ///
  /// In fr, this message translates to:
  /// **'{name} est déjà dans le secteur.'**
  String addStreetsAlreadyIn(String name);

  /// Snackbar when a road is tapped offline (PLAN §5.4).
  ///
  /// In fr, this message translates to:
  /// **'Connexion nécessaire pour ajouter une rue.'**
  String get addStreetsNoNetwork;

  /// Snackbar when the BAN knows no street at the point tapped (a private road, a new estate).
  ///
  /// In fr, this message translates to:
  /// **'Aucune rue connue ici.'**
  String get addStreetsNoStreetHere;

  /// Snackbar when the address service failed for the road tapped.
  ///
  /// In fr, this message translates to:
  /// **'Le service des adresses ne répond pas.'**
  String get addStreetsServiceError;

  /// Action of the look-up snackbars: opens « Rue à la main », which works offline.
  ///
  /// In fr, this message translates to:
  /// **'Saisir à la main'**
  String get addStreetsManualAction;

  /// Link at the bottom of the selection sheet: opens « Rue à la main », offline too.
  ///
  /// In fr, this message translates to:
  /// **'Rue absente de la carte ? Saisir à la main'**
  String get addStreetsManualLink;

  /// Above « Ajouter N rues » when some ticked streets could not be added; they stay ticked.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 rue n\'a pas pu être ajoutée : la Base Adresse Nationale donne des numéros incohérents. Saisissez-la à la main.} other{{count} rues n\'ont pas pu être ajoutées : la Base Adresse Nationale donne des numéros incohérents. Saisissez-les à la main.}}'**
  String addStreetsAddFailed(int count);

  /// Above « Ajouter N rues » when the numbers of a street found in a zone could not be read offline; it and the streets after it stay ticked.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 rue n\'a pas pu être ajoutée : connexion nécessaire.} other{{count} rues n\'ont pas pu être ajoutées : connexion nécessaire.}}'**
  String addStreetsAddFailedNoNetwork(int count);

  /// Above « Ajouter N rues » when the address service failed for streets found in a zone; they stay ticked.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 rue n\'a pas pu être ajoutée : le service des adresses ne répond pas. Réessayez plus tard.} other{{count} rues n\'ont pas pu être ajoutées : le service des adresses ne répond pas. Réessayez plus tard.}}'**
  String addStreetsAddFailedService(int count);

  /// The pill next to the search box of « Ajouter des rues »: on, a drag on the map draws a zone (PLAN §5.14, PickZone mockup).
  ///
  /// In fr, this message translates to:
  /// **'Zone'**
  String get addStreetsZone;

  /// Screen-reader name of the « Zone » pill while it is off.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une zone'**
  String get addStreetsZoneStart;

  /// Screen-reader name of the « Zone » pill while it is on: a tap leaves the mode, the ticks stay.
  ///
  /// In fr, this message translates to:
  /// **'Zone en cours, annuler'**
  String get addStreetsZoneStop;

  /// Selection sheet with nothing ticked while « Zone » is on and no zone is drawn.
  ///
  /// In fr, this message translates to:
  /// **'Faites glisser le doigt sur la carte pour tracer une zone.'**
  String get addStreetsZoneHint;

  /// In the zone's sheet while the streets of the zone drawn are looked for.
  ///
  /// In fr, this message translates to:
  /// **'Recherche des rues de la zone…'**
  String get addStreetsZoneLooking;

  /// Title of the zone's sheet: how many streets the zone holds, greyed ones included.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune rue dans la zone} =1{1 rue dans la zone} other{{count} rues dans la zone}}'**
  String addStreetsZoneStreets(int count);

  /// Under a greyed street of the zone's list that the sector has already.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans le secteur'**
  String get addStreetsZoneInSector;

  /// Under a greyed road of the zone's list that no street of the address base is named after.
  ///
  /// In fr, this message translates to:
  /// **'Aucune adresse connue'**
  String get addStreetsZoneNoAddress;

  /// Snackbar when a zone is drawn too far out (under zoom 15): nothing is listed.
  ///
  /// In fr, this message translates to:
  /// **'Zoomez pour tracer une zone.'**
  String get addStreetsZoomIn;

  /// Snackbar when the zone drawn holds more streets than a zone keeps: nothing is listed.
  ///
  /// In fr, this message translates to:
  /// **'Zone trop grande : {max} rues au plus.'**
  String addStreetsZoneTooLarge(int max);
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
