// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Tournée des calendriers';

  @override
  String get screenWelcome => 'Bienvenue';

  @override
  String get screenCreate => 'Nouvelle tournée';

  @override
  String get screenJoin => 'Rejoindre une tournée';

  @override
  String get screenJoinPending => 'Demande envoyée';

  @override
  String get screenAddStreets => 'Ajouter des rues';

  @override
  String get screenManualStreet => 'Rue à la main';

  @override
  String get screenStreet => 'Rue';

  @override
  String get screenEditStreet => 'Modifier la rue';

  @override
  String get screenTeam => 'Équipe';

  @override
  String get screenSettings => 'Paramètres';

  @override
  String get screenNewCampaign => 'Nouvelle campagne';

  @override
  String get screenTrash => 'Corbeille';

  @override
  String get tileStatusToDo => 'à faire';

  @override
  String get tileStatusDone => 'fait';

  @override
  String get tileStatusNobodyHome => 'personne';

  @override
  String get tileStatusComeBack => 'à faire, repasser';

  @override
  String houseTileSemantics(String number, String status) {
    return 'Numéro $number, $status';
  }

  @override
  String buildingTileSemantics(String number, int done, int total) {
    return 'Numéro $number, immeuble, $done sur $total faits';
  }

  @override
  String get galleryTitle => 'Composants';

  @override
  String get galleryButtons => 'Boutons';

  @override
  String get galleryPrimaryButton => 'Bouton principal';

  @override
  String get galleryDisabledButton => 'Bouton désactivé';

  @override
  String get gallerySecondaryButton => 'Bouton secondaire';

  @override
  String get galleryCompactButton => 'Bouton compact';

  @override
  String get galleryStatusTiles => 'Tuiles de statut';

  @override
  String get gallerySheetAndSnackBar => 'Feuille et message';

  @override
  String get galleryShowSheet => 'Afficher la feuille';

  @override
  String get gallerySheetTitle => 'Rue des Lilas';

  @override
  String get gallerySheetBody => 'Le contenu de la feuille se place ici.';

  @override
  String get galleryShowSnackBar => 'Afficher le message';

  @override
  String get gallerySnackBarMessage => '7 → Personne';

  @override
  String get undo => 'Annuler';
}
