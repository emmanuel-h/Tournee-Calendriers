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
  String tileWithNoteSemantics(String tile) {
    return '$tile, avec une note';
  }

  @override
  String get statusToDo => 'À faire';

  @override
  String get statusDone => 'Fait';

  @override
  String get statusNobodyHome => 'Personne';

  @override
  String houseMarked(String number, String status) {
    return '$number → $status';
  }

  @override
  String get editStreetAction => 'Modifier la rue';

  @override
  String get hideDone => 'Masquer faits';

  @override
  String get oddSide => 'Côté impair';

  @override
  String get evenSide => 'Côté pair';

  @override
  String streetCountsSemantics(
    int done,
    int total,
    int nobodyHome,
    int comeBack,
  ) {
    return '$done sur $total faits, $nobodyHome personne, $comeBack à repasser';
  }

  @override
  String get tapHintTap => 'Appui :';

  @override
  String get tapHintHold => 'Appui long : détails';

  @override
  String get tapHintSemantics =>
      'Appui : à faire, fait, personne, à faire. Appui long : détails';

  @override
  String get streetGone => 'Cette rue n\'est plus sur ce téléphone.';

  @override
  String startStreetsHeader(int count) {
    return 'Mes rues · $count';
  }

  @override
  String get filterStreetsHint => 'Filtrer les rues…';

  @override
  String get importStreetsAction => 'Importer des rues';

  @override
  String get startEmptyTitle => 'Aucune rue pour l\'instant';

  @override
  String get startEmptyBody =>
      'Importez les rues d\'une commune pour commencer. Il faut le réseau une fois ; ensuite tout fonctionne hors ligne.';

  @override
  String filterNoMatch(String filter) {
    return 'Aucune rue ne correspond à « $filter ».';
  }

  @override
  String streetProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String streetRowSemantics(String name, int done, int total) {
    return '$name, $done sur $total faits';
  }

  @override
  String streetRowCompleteSemantics(String name, int total) {
    return '$name, terminée, $total sur $total faits';
  }

  @override
  String get communeLabel => 'Commune';

  @override
  String get communeHint => 'Nom de la commune';

  @override
  String communeWithPostcode(String name, String postcode) {
    return '$name ($postcode)';
  }

  @override
  String communeWithPostcodes(String name, String postcode) {
    return '$name ($postcode…)';
  }

  @override
  String get communeNoneFound => 'Aucune commune ne porte ce nom.';

  @override
  String get communeSearchNoNetwork =>
      'Pas de réseau : la recherche de communes en a besoin. Réessayez quand le téléphone capte.';

  @override
  String get communeSearchServiceError =>
      'La recherche de communes ne répond pas. Réessayez plus tard.';

  @override
  String get streetsLoading => 'Chargement des rues…';

  @override
  String get addressNoNetwork =>
      'Pas de réseau. Réessayez quand le téléphone capte.';

  @override
  String get addressServiceError =>
      'Le service des adresses ne répond pas. Réessayez plus tard.';

  @override
  String get addressNotFound =>
      'La base d\'adresses ne connaît pas cette commune ou certaines de ses rues.';

  @override
  String get retry => 'Réessayer';

  @override
  String importStreetCount(int total, int checked) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total rues',
      one: '1 rue',
    );
    String _temp1 = intl.Intl.pluralLogic(
      checked,
      locale: localeName,
      other: '$checked cochées',
      one: '1 cochée',
      zero: '0 cochée',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get checkAll => 'Tout cocher';

  @override
  String get uncheckAll => 'Tout décocher';

  @override
  String streetNumberCount(int count) {
    return '$count n°';
  }

  @override
  String get alreadyImported => 'déjà importée';

  @override
  String get importFooter =>
      'Nécessite le réseau. Les rues déjà importées gardent leurs marques.';

  @override
  String importButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importer $count rues',
      one: 'Importer 1 rue',
      zero: 'Importer',
    );
    return '$_temp0';
  }

  @override
  String importProgress(int done, int total) {
    return 'Import en cours… $done/$total';
  }

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rues importées',
      one: '1 rue importée',
      zero: 'Aucune nouvelle rue',
    );
    return '$_temp0';
  }

  @override
  String importPartial(int imported, int failed, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: '$imported rues importées',
      one: '1 rue importée',
      zero: 'Aucune rue importée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed en échec',
      one: '1 en échec',
    );
    return '$_temp0, $_temp1. $reason Les rues encore cochées restent à importer.';
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
