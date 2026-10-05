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
  String get houseStatusGroup => 'Statut';

  @override
  String get comeBack => 'Repasser';

  @override
  String get comeBackDoneReason => 'Déjà fait : rien à repasser.';

  @override
  String get comeBackHintPlaceholder => 'Quand ? ex. après 19h';

  @override
  String comeBackHintTooLong(int max) {
    return 'Précision limitée à $max caractères.';
  }

  @override
  String get noteLabel => 'Note';

  @override
  String get notePrivacyHint => 'N\'écrivez ni nom ni information personnelle.';

  @override
  String noteTooLong(int max) {
    return 'Note limitée à $max caractères.';
  }

  @override
  String textCount(int count, int max) {
    return '$count/$max';
  }

  @override
  String textCountSemantics(int count, int max) {
    return '$count caractères sur $max';
  }

  @override
  String houseChangedToday(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Modifié à $timeString';
  }

  @override
  String houseChangedOn(DateTime day, DateTime time) {
    final intl.DateFormat dayDateFormat = intl.DateFormat.MMMd(localeName);
    final String dayString = dayDateFormat.format(day);
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Modifié le $dayString à $timeString';
  }

  @override
  String get houseGone => 'Ce numéro n\'est plus dans cette rue.';

  @override
  String get transformToBuilding => 'Transformer en immeuble…';

  @override
  String get cancel => 'Annuler';

  @override
  String get buildingSetupTitle => 'Décrire l\'immeuble';

  @override
  String get setupStaircases => 'Escaliers';

  @override
  String get setupFloors => 'Étages';

  @override
  String get setupDoorsPerFloor => 'Portes par étage';

  @override
  String get setupFewerStaircases => 'Un escalier de moins';

  @override
  String get setupMoreStaircases => 'Un escalier de plus';

  @override
  String get setupFewerFloors => 'Un étage de moins';

  @override
  String get setupMoreFloors => 'Un étage de plus';

  @override
  String get setupFewerDoors => 'Une porte de moins';

  @override
  String get setupMoreDoors => 'Une porte de plus';

  @override
  String setupStepperSemantics(String label, String value) {
    return '$label : $value';
  }

  @override
  String get setupFloorsUnknown => 'Inconnus';

  @override
  String setupFloorsRange(String top) {
    return 'RdC–$top';
  }

  @override
  String get setupLabelStyle => 'Numéros des portes';

  @override
  String get labelStyleNumber => '51, 52…';

  @override
  String get labelStyleLetter => '5A, 5B…';

  @override
  String get labelStyleFree => 'Libres';

  @override
  String setupPreviewTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count logements',
      one: '1 logement',
    );
    return 'Aperçu · $_temp0';
  }

  @override
  String setupPreviewStaircasesTwo(String first, String last) {
    return 'Esc. $first et $last : ';
  }

  @override
  String setupPreviewStaircasesMany(String first, String last) {
    return 'Esc. $first à $last : ';
  }

  @override
  String setupPreviewRange(String first, String last) {
    return '$first–$last';
  }

  @override
  String get setupPreviewHint =>
      'Chaque étage pourra ensuite être ajusté (porte en plus ou en moins).';

  @override
  String get setupValidate => 'Valider';

  @override
  String get setupNoStaircase => 'Au moins 1 escalier.';

  @override
  String setupTooManyStaircases(int max) {
    return '$max escaliers au plus (A à Z).';
  }

  @override
  String get setupBelowGroundFloor => 'Les sous-sols ne sont pas comptés.';

  @override
  String setupTooManyFloors(int max) {
    return '$max étages au plus.';
  }

  @override
  String get setupNoDoor => 'Au moins 1 porte par étage.';

  @override
  String setupTooManyDoorsForLetters(int max) {
    return '$max portes par étage au plus avec 5A, 5B…';
  }

  @override
  String setupTooManyDwellings(int max) {
    return '$max logements au plus par immeuble.';
  }

  @override
  String get setupConfirmTitle => 'Modifier les étages ?';

  @override
  String setupConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count portes marquées n\'existent plus dans ce plan : leurs statuts, notes et « repasser » seront perdus.',
      one: '1 porte marquée n\'existe plus dans ce plan : son statut, sa note et son « repasser » seront perdus.',
    );
    return '$_temp0';
  }

  @override
  String get setupConfirmAction => 'Modifier';

  @override
  String get editStreetClose => 'Quitter la modification';

  @override
  String get editStreetOk => 'OK';

  @override
  String get streetNameLabel => 'Nom de la rue';

  @override
  String get streetNameBlank => 'Le nom de la rue ne peut pas être vide.';

  @override
  String streetNameTooLong(int max) {
    return 'Nom limité à $max caractères.';
  }

  @override
  String editBuildingTile(String number) {
    return '$number · immeuble';
  }

  @override
  String editTileSemantics(String number) {
    return 'Modifier le numéro $number';
  }

  @override
  String editBuildingTileSemantics(String number) {
    return 'Modifier le numéro $number, immeuble';
  }

  @override
  String removeNumberSemantics(String number) {
    return 'Supprimer le numéro $number';
  }

  @override
  String get addNumbersButton => '+ numéros';

  @override
  String get editHint =>
      'Touchez un numéro pour le renommer ou le transformer en immeuble.';

  @override
  String get deleteStreetAction => 'Supprimer la rue';

  @override
  String numberRemoved(String number) {
    return 'N° $number supprimé';
  }

  @override
  String numberRenamed(String from, String to) {
    return 'N° $from → $to';
  }

  @override
  String backToHouseDone(String number) {
    return 'N° $number redevient une maison';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String confirmRemoveTitle(String number) {
    return 'Supprimer le n° $number ?';
  }

  @override
  String get confirmRemoveBody =>
      'Ce numéro a des marques (statut, note, « repasser » ou portes marquées). Elles partent avec lui à la Corbeille.';

  @override
  String get confirmDeleteStreetTitle => 'Supprimer la rue ?';

  @override
  String confirmDeleteStreetBody(String name) {
    return '« $name » part à la Corbeille avec ses numéros et leurs marques, pour toute l\'équipe.';
  }

  @override
  String get addNumbersTitle => 'Ajouter des numéros';

  @override
  String get numbersLabel => 'Numéros';

  @override
  String get numbersPlaceholder => '12bis, 21-25';

  @override
  String get numbersHelper => 'Un numéro, une liste ou une plage (21-25).';

  @override
  String numbersPreviewTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numéros',
      one: '1 numéro',
    );
    return 'Aperçu · $_temp0';
  }

  @override
  String numbersAlreadyThere(String numbers) {
    return 'Déjà dans la rue : $numbers';
  }

  @override
  String numbersFromCorbeille(int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reviennent de la Corbeille avec leurs marques : $numbers',
      one: 'Revient de la Corbeille avec ses marques : $numbers',
    );
    return '$_temp0';
  }

  @override
  String get addNumbersConfirm => 'Ajouter';

  @override
  String numbersInvalidRange(String token) {
    return '« $token » : une plage relie deux numéros simples, comme 21-25.';
  }

  @override
  String numbersTooMany(int max) {
    return '$max numéros au plus à la fois.';
  }

  @override
  String get numberEmpty => 'Tapez un numéro.';

  @override
  String numberMalformed(String text) {
    return '« $text » n\'est pas un numéro.';
  }

  @override
  String numberTooLarge(String text, int max) {
    return '« $text » : $max au plus.';
  }

  @override
  String numberInvalidSuffix(String text) {
    return '« $text » : après le numéro, un complément en lettres sans accent (12bis, 3A).';
  }

  @override
  String numberSuffixTooLong(String text, int max) {
    return '« $text » : complément de $max caractères au plus.';
  }

  @override
  String get numberLabel => 'Numéro';

  @override
  String get renumberAction => 'Changer le numéro';

  @override
  String renumberTaken(String number) {
    return 'Le $number est déjà dans la rue.';
  }

  @override
  String renumberInCorbeille(String number) {
    return 'Le $number est dans la Corbeille : ajoutez-le avec « + numéros » pour le retrouver avec ses marques, ou choisissez un autre numéro.';
  }

  @override
  String get backToHouseAction => 'Redevenir une maison';

  @override
  String get confirmBackToHouseTitle => 'Redevenir une maison ?';

  @override
  String get confirmBackToHouseBody =>
      'Les portes de l\'immeuble et leurs marques (statuts, notes, « repasser ») seront perdues.';

  @override
  String get floorGround => 'RdC';

  @override
  String get floorFirst => '1er';

  @override
  String floorNth(int level) {
    return '${level}e';
  }

  @override
  String get floorUnknown => 'Logements';

  @override
  String get staircaseGroup => 'Escalier';

  @override
  String staircaseTab(String letter, int done, int total) {
    return 'Esc. $letter · $done/$total';
  }

  @override
  String staircaseTabSemantics(String letter, int done, int total) {
    return 'Escalier $letter, $done sur $total faits';
  }

  @override
  String staircaseSpoken(String letter) {
    return 'Escalier $letter';
  }

  @override
  String staircaseShort(String letter) {
    return 'Esc. $letter';
  }

  @override
  String doorSpoken(String label) {
    return 'porte $label';
  }

  @override
  String buildingCountSemantics(int done, int total) {
    return '$done sur $total logements faits';
  }

  @override
  String get gridHintHold => 'Appui long : note, repasser';

  @override
  String get gridHintSemantics =>
      'Appui : à faire, fait, personne, à faire. Appui long : note, repasser';

  @override
  String get editFloors => 'Modifier les étages';

  @override
  String get buildingDetails => 'Note · Repasser';

  @override
  String get buildingGone => 'Ce numéro n\'est plus un immeuble de cette rue.';

  @override
  String get doorGone => 'Cette porte n\'est plus dans l\'immeuble.';

  @override
  String get adjustDoorsAction => 'Ajuster les portes';

  @override
  String get adjustDoorsClose => 'Quitter';

  @override
  String get adjustDoorsHint =>
      'Touchez une porte pour la renommer (« Gauche », « 5A »…). Les marques des autres portes sont gardées.';

  @override
  String renameDoorSemantics(String label) {
    return 'Renommer la porte $label';
  }

  @override
  String removeDoorSemantics(String label) {
    return 'Supprimer la porte $label';
  }

  @override
  String addDoorSemantics(String floor) {
    return 'Une porte de plus au $floor';
  }

  @override
  String get addDoorGroundSemantics => 'Une porte de plus au rez-de-chaussée';

  @override
  String get addDoorUnknownFloorSemantics => 'Une porte de plus';

  @override
  String doorRemoved(String label) {
    return 'Porte $label supprimée';
  }

  @override
  String confirmRemoveDoorTitle(String label) {
    return 'Supprimer la porte $label ?';
  }

  @override
  String get confirmRemoveDoorBody =>
      'Elle a déjà une marque (fait, personne, repasser ou note), qui partira avec elle. « Annuler » la ramène juste après.';

  @override
  String get keep => 'Garder';

  @override
  String get lastDoorRefused =>
      'C\'est la dernière porte de l\'immeuble. Pour en refaire une maison, touchez son numéro puis « Redevenir une maison ».';

  @override
  String doorTitle(String label) {
    return 'Porte $label';
  }

  @override
  String get doorNameLabel => 'Nom de la porte';

  @override
  String get renameDoorAction => 'Renommer';

  @override
  String get doorLabelTaken => 'Ce nom est déjà pris à cet étage.';

  @override
  String get doorLabelBlank => 'Le nom de la porte ne peut pas être vide.';

  @override
  String doorLabelTooLong(int max) {
    return 'Nom limité à $max caractères.';
  }

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
