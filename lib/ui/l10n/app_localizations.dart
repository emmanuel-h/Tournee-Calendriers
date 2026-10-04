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
