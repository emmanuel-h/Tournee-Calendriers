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
  String get screenCreate => 'Nouveau secteur';

  @override
  String get screenJoin => 'Rejoindre un secteur';

  @override
  String get screenJoinPending => 'Demande envoyée';

  @override
  String get screenStreet => 'Rue';

  @override
  String get screenEditStreet => 'Modifier la rue';

  @override
  String get screenSector => 'Secteur';

  @override
  String get screenSettings => 'Paramètres';

  @override
  String get screenTrash => 'Corbeille';

  @override
  String get tileStatusToDo => 'à faire';

  @override
  String get tileStatusDone => 'fait';

  @override
  String get tileStatusRefused => 'refusé';

  @override
  String get tileStatusNobodyHome => 'personne';

  @override
  String get tileStatusComeBack => 'repasser';

  @override
  String houseTileSemantics(String number, String status) {
    return 'Numéro $number, $status';
  }

  @override
  String buildingTileSemantics(String number, int done, int total) {
    return 'Numéro $number, immeuble, $done sur $total faits, ouvrir';
  }

  @override
  String buildingStatusTileSemantics(String number, String status) {
    return 'Numéro $number, immeuble, $status, ouvrir';
  }

  @override
  String get statusToDo => 'À faire';

  @override
  String get statusDone => 'Fait';

  @override
  String get statusRefused => 'Refusé';

  @override
  String get statusNobodyHome => 'Personne';

  @override
  String get statusComeBack => 'Repasser';

  @override
  String tileTries(int count) {
    return '×$count';
  }

  @override
  String tileTriesNobodyHome(int count) {
    return '${count}e passage';
  }

  @override
  String nobodyHomeTries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passages sans personne',
      one: '$count passage sans personne',
    );
    return '$_temp0';
  }

  @override
  String get nobodyHomeAgain => 'De nouveau personne';

  @override
  String houseStatusStored(String number, String status) {
    return 'N° $number : $status';
  }

  @override
  String houseStatusStoredTries(String number, String status, int count) {
    return 'N° $number : $status (${count}e passage)';
  }

  @override
  String doorStatusStored(String label, String status) {
    return 'Porte $label : $status';
  }

  @override
  String doorStatusStoredTries(String label, String status, int count) {
    return 'Porte $label : $status (${count}e passage)';
  }

  @override
  String get streetHint => 'Appuyez sur une maison pour changer son statut';

  @override
  String get gridHint => 'Appuyez sur une porte pour changer son statut';

  @override
  String houseTilePickSemantics(String number, String status) {
    return 'Numéro $number, $status, changer le statut';
  }

  @override
  String statusPickerHouse(String number) {
    return 'N° $number';
  }

  @override
  String statusPickerDoor(String label, String status) {
    return 'Porte $label · $status';
  }

  @override
  String statusPickerComeBack(String subject) {
    return '$subject · quand repasser ?';
  }

  @override
  String get statusPickerValidate => 'Valider';

  @override
  String houseCalendars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count calendriers',
      one: '$count calendrier',
    );
    return '$_temp0';
  }

  @override
  String get removeCalendar => 'Un calendrier de moins';

  @override
  String get statusPickerClose => 'Fermer';

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
    int refused,
    int nobodyHome,
    int comeBack,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      refused,
      locale: localeName,
      other: '$refused refusés',
      one: '$refused refusé',
    );
    return '$done sur $total faits, $_temp0, $nobodyHome personne, $comeBack à repasser';
  }

  @override
  String get streetGone => 'Cette rue n\'est plus sur ce téléphone.';

  @override
  String get houseStatusGroup => 'Statut';

  @override
  String get comeBack => 'Repasser';

  @override
  String get comeBackWhenLabel => 'Quand repasser ?';

  @override
  String get comeBackDayGroup => 'Jour';

  @override
  String get comeBackToday => 'Aujourd\'hui';

  @override
  String get comeBackTomorrow => 'Demain';

  @override
  String get comeBackYesterday => 'Hier';

  @override
  String comeBackChipDay(DateTime day) {
    final intl.DateFormat dayDateFormat = intl.DateFormat('E d', localeName);
    final String dayString = dayDateFormat.format(day);

    return '$dayString';
  }

  @override
  String comeBackChipDaySemantics(DateTime day) {
    final intl.DateFormat dayDateFormat = intl.DateFormat.MMMMEEEEd(localeName);
    final String dayString = dayDateFormat.format(day);

    return '$dayString';
  }

  @override
  String get comeBackHourLabel => 'Heure';

  @override
  String get comeBackNoHour => 'Pas d\'heure';

  @override
  String comeBackHour(int hour) {
    return '$hour h';
  }

  @override
  String get comeBackNoDay => 'Pas de jour choisi';

  @override
  String get comeBackOnToday => 'Aujourd\'hui';

  @override
  String comeBackOnTodayAt(int hour) {
    return 'Aujourd\'hui vers $hour h';
  }

  @override
  String get comeBackOnTomorrow => 'Demain';

  @override
  String comeBackOnTomorrowAt(int hour) {
    return 'Demain vers $hour h';
  }

  @override
  String get comeBackOnYesterday => 'C\'était hier';

  @override
  String comeBackOnYesterdayAt(int hour) {
    return 'C\'était hier vers $hour h';
  }

  @override
  String comeBackOnDay(DateTime day) {
    final intl.DateFormat dayDateFormat = intl.DateFormat(
      'EEEE d MMM',
      localeName,
    );
    final String dayString = dayDateFormat.format(day);

    return 'Le $dayString';
  }

  @override
  String comeBackOnDayAt(DateTime day, int hour) {
    final intl.DateFormat dayDateFormat = intl.DateFormat(
      'EEEE d MMM',
      localeName,
    );
    final String dayString = dayDateFormat.format(day);

    return 'Le $dayString vers $hour h';
  }

  @override
  String comeBackPastDay(DateTime day) {
    final intl.DateFormat dayDateFormat = intl.DateFormat(
      'EEEE d MMM',
      localeName,
    );
    final String dayString = dayDateFormat.format(day);

    return 'C\'était le $dayString';
  }

  @override
  String comeBackPastDayAt(DateTime day, int hour) {
    final intl.DateFormat dayDateFormat = intl.DateFormat(
      'EEEE d MMM',
      localeName,
    );
    final String dayString = dayDateFormat.format(day);

    return 'C\'était le $dayString vers $hour h';
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
  String houseChangedByToday(String name, DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Modifié par $name · $timeString';
  }

  @override
  String houseChangedByOn(String name, DateTime day, DateTime time) {
    final intl.DateFormat dayDateFormat = intl.DateFormat.MMMd(localeName);
    final String dayString = dayDateFormat.format(day);
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Modifié par $name · $dayString à $timeString';
  }

  @override
  String get houseChangedByMe => 'vous';

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
    return '$label : $value';
  }

  @override
  String get setupSameForEach => 'Même chose pour chaque escalier';

  @override
  String setupStaircaseHeader(String letter) {
    return 'Esc. $letter';
  }

  @override
  String setupForStaircase(String text, String letter) {
    return '$text, escalier $letter';
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
  String setupPreviewStaircaseOne(String letter) {
    return 'Esc. $letter : ';
  }

  @override
  String setupPreviewStaircasesTwo(String first, String last) {
    return 'Esc. $first et $last : ';
  }

  @override
  String setupPreviewStaircasesMany(String first, String last) {
    return 'Esc. $first à $last : ';
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
  String get setupConfirmTitle => 'Modifier les étages ?';

  @override
  String setupConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count portes marquées n\'existent plus dans ce plan : leurs statuts et « repasser » seront perdus.',
      one: '1 porte marquée n\'existe plus dans ce plan : son statut et son « repasser » seront perdus.',
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
    return 'N° $number changé en maison';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String confirmRemoveTitle(String number) {
    return 'Supprimer le n° $number ?';
  }

  @override
  String get confirmRemoveBody =>
      'Ce numéro a des marques (statut, « repasser » ou portes marquées). Elles partent avec lui à la Corbeille.';

  @override
  String get confirmDeleteStreetTitle => 'Supprimer la rue ?';

  @override
  String confirmDeleteStreetBody(String name) {
    return '« $name » part à la Corbeille avec ses numéros et leurs marques, pour toute l\'équipe.';
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
    return 'Déjà dans la rue : $numbers';
  }

  @override
  String numbersFromCorbeille(int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reviennent de la Corbeille avec leurs marques : $numbers',
      one: 'Revient de la Corbeille avec ses marques : $numbers',
    );
    return '$_temp0';
  }

  @override
  String get addNumbersConfirm => 'Ajouter';

  @override
  String numbersInvalidRange(String token) {
    return '« $token » : une plage relie deux numéros simples, comme 21-25.';
  }

  @override
  String numbersTooMany(int max) {
    return '$max numéros au plus à la fois.';
  }

  @override
  String get numberEmpty => 'Tapez un numéro.';

  @override
  String numberMalformed(String text) {
    return '« $text » n\'est pas un numéro.';
  }

  @override
  String numberTooLarge(String text, int max) {
    return '« $text » : $max au plus.';
  }

  @override
  String numberInvalidSuffix(String text) {
    return '« $text » : après le numéro, un complément en lettres sans accent (12bis, 3A).';
  }

  @override
  String numberSuffixTooLong(String text, int max) {
    return '« $text » : complément de $max caractères au plus.';
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
    return 'Le $number est dans la Corbeille : ajoutez-le avec « + numéros » pour le retrouver avec ses marques, ou choisissez un autre numéro.';
  }

  @override
  String get backToHouseAction => 'Changer en maison';

  @override
  String get confirmBackToHouseTitle => 'Changer en maison ?';

  @override
  String get confirmBackToHouseBody =>
      'Les portes de l\'immeuble et leurs marques (statuts, « repasser ») seront perdues.';

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
  String get gridClose => 'Fermer';

  @override
  String get editFloors => 'Modifier les étages';

  @override
  String get manageBuilding => 'Gérer l\'immeuble';

  @override
  String get openBuilding => 'Ouvrir l\'immeuble';

  @override
  String get buildingDetails => 'Repasser';

  @override
  String get buildingGone => 'Ce numéro n\'est plus un immeuble de cette rue.';

  @override
  String get doorGone => 'Cette porte n\'est plus dans l\'immeuble.';

  @override
  String get adjustDoorsAction => 'Modifier les portes';

  @override
  String get adjustDoorsClose => 'Quitter';

  @override
  String get adjustDoorsHint =>
      'Touchez une porte pour la renommer (« Gauche », « 5A »…).';

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
  String doorAdded(String label) {
    return 'Porte $label ajoutée';
  }

  @override
  String doorRenamed(String from, String to) {
    return 'Porte $from → $to';
  }

  @override
  String confirmRemoveDoorTitle(String label) {
    return 'Supprimer la porte $label ?';
  }

  @override
  String get confirmRemoveDoorBody =>
      'Elle a déjà une marque (fait, personne ou repasser), qui partira avec elle. « Annuler » la ramène juste après.';

  @override
  String get keep => 'Garder';

  @override
  String get lastDoorRefused =>
      'C\'est la dernière porte de l\'immeuble. Pour en refaire une maison, revenez à l\'immeuble : « Gérer l\'immeuble », puis « Changer en maison ».';

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
  String get filterStreetsHint => 'Filtrer les rues…';

  @override
  String get noSectorTitle => 'Aucun secteur ouvert';

  @override
  String get noSectorBody =>
      'Rejoignez le secteur de votre équipe avec le code qu\'on vous a donné.';

  @override
  String pendingSyncLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modifications de $count rues en attente d\'envoi',
      one: 'Modifications d\'une rue en attente d\'envoi',
    );
    return '$_temp0';
  }

  @override
  String filterNoMatch(String filter) {
    return 'Aucune rue ne correspond à « $filter ».';
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
      'Pas de réseau : la recherche de communes en a besoin. Réessayez quand le téléphone capte.';

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
  String get inCorbeille => 'dans la Corbeille';

  @override
  String importRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rues restaurées',
      one: '1 rue restaurée',
    );
    return '$_temp0';
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

  @override
  String get saveFailedTitle => 'Enregistrement impossible';

  @override
  String get saveFailedBody =>
      'Le téléphone n\'a pas pu enregistrer le dernier changement : sa mémoire est peut-être pleine. Libérez de la place avant de fermer l\'application.';

  @override
  String get saveFailedOk => 'OK';

  @override
  String sectorTitle(String number, String year) {
    return 'Secteur $number · $year';
  }

  @override
  String sectorTitleSemantics(String title, String centre) {
    return '$title, $centre. Changer de secteur';
  }

  @override
  String get mySectorsTitle => 'Mes secteurs';

  @override
  String get mySectorsEmpty => 'Aucun secteur pour l\'instant.';

  @override
  String mySectorsPending(String centre) {
    return '$centre · votre demande est en attente';
  }

  @override
  String mySectorsOpenSemantics(String title, String centre) {
    return '$title, $centre, secteur ouvert';
  }

  @override
  String mySectorsClosedSemantics(String title, String centre) {
    return '$title, $centre, ouvrir';
  }

  @override
  String mySectorsWaiting(String centre, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes en attente',
      one: '1 demande en attente',
    );
    return '$centre · $_temp0';
  }

  @override
  String mySectorsWaitingSemantics(String title, String centre, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes en attente',
      one: '1 demande en attente',
    );
    return '$title, $centre, $_temp0, ouvrir';
  }

  @override
  String mySectorsPendingSemantics(String title, String centre) {
    return '$title, $centre, votre demande est en attente';
  }

  @override
  String get settingsYou => 'Vous';

  @override
  String get settingsOfflineLine =>
      'L\'application fonctionne sans réseau ; les modifications sont envoyées dès qu\'il revient.';

  @override
  String get settingsApplication => 'Application';

  @override
  String get settingsName => 'Prénom';

  @override
  String settingsMySectorsValue(String number, String year) {
    return '$number · $year';
  }

  @override
  String get settingsTheme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get settingsPrivacy => 'Confidentialité';

  @override
  String get settingsVersion => 'Version';

  @override
  String settingsVersionSemantics(String version) {
    return 'Version $version, voir les nouveautés';
  }

  @override
  String get settingsLicences => 'Licences';

  @override
  String get changelogTitle => 'Nouveautés';

  @override
  String changelogDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String changelogHeading(String version, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$version · $dateString';
  }

  @override
  String get release010First => 'Première version de test.';

  @override
  String get release0101NoSector =>
      'Sans secteur ouvert, l\'accueil propose de rejoindre un secteur (ou d\'en créer un, pour un administrateur) : les rues n\'existent plus que dans un secteur.';

  @override
  String get release0100Sector =>
      'La zone de l\'équipe s\'appelle maintenant un « secteur » ; une « tournée » est une sortie dans ce secteur.';

  @override
  String get release0100Picker =>
      'Rue : touchez une maison ou une porte, puis choisissez son statut. Plus de cycle ni d\'appui long.';

  @override
  String get release0100Refused =>
      'Nouveau statut « Refusé » pour une maison ou une porte qui ne veut pas de calendrier : elle compte comme faite.';

  @override
  String get release0100Privacy =>
      'Confidentialité : le texte dit aussi ce qui est gardé des tournées, des dons et des calendriers.';

  @override
  String get release0100Calendars =>
      'Une maison faite garde son nombre de calendriers : « + Ajouter un don » en ajoute un, « − » en retire un, et la tuile affiche le nombre à partir de 2.';

  @override
  String get release0100Rounds =>
      'Tournées : « Commencer une tournée » sur l\'accueil, le montant de chaque don après « Fait », la liste des dons et le bilan à valider en fin de tournée.';

  @override
  String get release0100Collecte =>
      'Équipe : « Collecte 2026 » montre l\'argent récolté par le secteur, tournée par tournée, jamais par membre.';

  @override
  String get release090Streets =>
      'Équipe : chaque membre montre le nombre de rues qu\'il couvre ; touchez ce nombre pour voir leurs noms.';

  @override
  String get release090Buttons =>
      'Équipe : « Quitter le secteur » et « Supprimer le secteur » restent en bas de l\'écran.';

  @override
  String get release090CaughtUp =>
      'Une longue rue ajoutée juste avant de fermer l\'application est complétée au démarrage suivant, même sans réseau.';

  @override
  String get release080Icon =>
      'Nouvelle icône, et un écran de démarrage aux couleurs de l\'application.';

  @override
  String get release080Dark =>
      'Le thème sombre est revu, et les écrans restent lisibles avec une grande taille de texte.';

  @override
  String get release080Privacy =>
      'Confidentialité : un nouveau texte, et un lien vers la politique complète en ligne.';

  @override
  String get release070Offline =>
      'Le secteur ouvert reste disponible sans réseau : la carte et les rues sont gardées sur le téléphone, toutes seules.';

  @override
  String get release070Greyed =>
      'Sans réseau, un secteur jamais ouvert sur ce téléphone apparaît en gris dans « Mes secteurs ».';

  @override
  String get release070Settings =>
      'Paramètres rappelle que l\'application fonctionne sans réseau.';

  @override
  String get release060FreeLines =>
      'Les rues libres se voient mieux sur la carte : tirets gris foncé sur un liseré blanc.';

  @override
  String get release060CloseCard =>
      'La fiche d\'une rue sur la carte se ferme avec ✕.';

  @override
  String get release060LeftTeam =>
      'Les rues d\'un membre qui a quitté l\'équipe redeviennent libres.';

  @override
  String get release051Lines =>
      'Les rues du secteur apparaissent enfin sur la carte : leur tracé vient du fond de carte, et les rues déjà ajoutées reçoivent le leur.';

  @override
  String get release051AddAtOnce =>
      'Ajouter une rue depuis la carte est immédiat, et la route touchée s\'allume tout de suite.';

  @override
  String get release051TakeFromList =>
      'Une rue des « Autres rues du secteur » s\'ouvre sur la carte pour se l\'attribuer.';

  @override
  String get release050Map =>
      'Accueil montre la carte du secteur : ses rues, ses maisons, une légende et le panneau « Mes rues ».';

  @override
  String get release050AddStreets =>
      'Un secteur a ses communes ; « Ajouter des rues » s\'ouvre dessus, en carte ou en liste : touchez une route, cherchez-la ou saisissez-la.';

  @override
  String get release050Assignees =>
      'Chaque rue dit qui la couvre ; on la prend ou la libère.';

  @override
  String get release050Tries =>
      '« Repassé, toujours personne » compte les passages sans réponse, et on choisit le jour et l\'heure où repasser.';

  @override
  String get release040LastChangeBy =>
      'Les fiches des maisons et des portes disent qui les a modifiées en dernier : « Modifié par Léa · 14:02 ».';

  @override
  String get release040AdminRevoked =>
      'Un administrateur dont les droits ont été retirés en est averti : « Vous n\'êtes plus administrateur. »';

  @override
  String get release030DeviceId =>
      'L\'identifiant de l\'appareil s\'affiche en entier dans Paramètres et sur l\'écran de bienvenue.';

  @override
  String get release020Admins =>
      'Seuls les administrateurs créent un secteur ; les autres le rejoignent avec un code.';

  @override
  String get release020AllSectors =>
      'Les administrateurs voient tous les secteurs, les gèrent et peuvent les rejoindre directement.';

  @override
  String get release020Team =>
      'Équipe : « Nouveau code », « Retirer » et « Supprimer » sont réservés aux administrateurs ; chacun peut quitter le secteur.';

  @override
  String get release020DeviceId =>
      'Paramètres affiche l\'identifiant de l\'appareil, à donner pour devenir administrateur.';

  @override
  String get settingsCredits =>
      'Carte © contributeurs OpenStreetMap, OpenFreeMap. Adresses : Base Adresse Nationale.';

  @override
  String settingsRowSemantics(String label, String value) {
    return '$label, $value';
  }

  @override
  String get nameFieldLabel => 'Votre prénom';

  @override
  String get nameSave => 'Enregistrer';

  @override
  String get nameBlank => 'Écrivez votre prénom.';

  @override
  String nameTooLong(int max) {
    return 'Prénom limité à $max caractères.';
  }

  @override
  String get privacyAccountTitle => 'Compte';

  @override
  String get privacyAccountBody =>
      'L\'appli ne demande ni adresse e-mail ni numéro de téléphone. Au premier lancement, elle crée un compte anonyme. Vos coéquipiers voient seulement le prénom que vous avez tapé.';

  @override
  String get privacyDataTitle => 'Données enregistrées';

  @override
  String get privacyDataBody =>
      'Pour chaque rue du secteur : les numéros, leur place sur la carte, ce qui s\'est passé à chaque porte (fait, refusé, personne, à repasser), le jour et l\'heure où repasser, combien de calendriers la maison a pris, et le prénom de qui l\'a noté. Pour chaque tournée validée : son début et sa fin, le nombre de maisons visitées, le nombre et le total des dons par moyen de paiement, et les calendriers offerts, sans le prénom de qui l\'a faite. Un don n\'est jamais lié à une maison : la liste des dons reste sur le téléphone jusqu\'à la validation de la tournée, puis elle est effacée. Rien d\'autre : pas de nom d\'habitant, pas de note.';

  @override
  String get privacyLocationTitle => 'Position';

  @override
  String get privacyLocationBody =>
      'La position du téléphone sert seulement à vous placer sur la carte, quand vous touchez le bouton. Rien n\'est sauvegardé en dehors de votre téléphone.';

  @override
  String get privacyHostingTitle => 'Hébergement';

  @override
  String get privacyHostingBody =>
      'Les secteurs sont stockés chez Google Firebase, dans l\'Union européenne. Les cartes viennent d\'OpenFreeMap et les adresses de la Base Adresse Nationale : comme tout site web, ces services voient l\'adresse IP du téléphone quand ils lui envoient des données.';

  @override
  String get privacyDeletionTitle => 'Suppression';

  @override
  String get privacyDeletionBody =>
      'Supprimer le secteur efface tout ce qu\'il contient. Quand une campagne commence, celle d\'il y a deux ans est effacée. Désinstaller l\'appli efface ce qui est sur le téléphone, y compris les dons d\'une tournée pas encore validée ; ce qui est partagé avec l\'équipe reste jusqu\'à la suppression du secteur.';

  @override
  String get privacyOnline => 'Politique complète en ligne';

  @override
  String get privacyOnlineSemantics =>
      'Politique complète en ligne, s\'ouvre dans le navigateur';

  @override
  String privacyOnlineFailed(String url) {
    return 'Impossible d\'ouvrir le navigateur. La politique est à l\'adresse $url';
  }

  @override
  String get homeSector => 'Secteur';

  @override
  String homeSectorWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Secteur, $count demandes en attente',
      one: 'Secteur, 1 demande en attente',
    );
    return '$_temp0';
  }

  @override
  String teamTitle(String number) {
    return 'Secteur $number';
  }

  @override
  String teamSubtitle(String centre, String campaign) {
    return '$centre · campagne $campaign';
  }

  @override
  String get teamCodeLabel => 'Code';

  @override
  String teamQrSemantics(String code) {
    return 'QR code du secteur, code $code';
  }

  @override
  String get teamShare => 'Partager';

  @override
  String teamShareText(String number, String centre, String code) {
    return 'Secteur $number · $centre\nRejoignez-le dans l\'app Tournée Calendriers avec le code $code.';
  }

  @override
  String get teamCopyCode => 'Copier le code';

  @override
  String get teamCodeCopied => 'Code copié';

  @override
  String get teamNewCode => 'Nouveau code';

  @override
  String teamWaitingHeader(int count) {
    return 'En attente ($count)';
  }

  @override
  String teamRequestAsked(String when) {
    return 'a demandé à rejoindre · $when';
  }

  @override
  String get teamAccept => 'Accepter';

  @override
  String teamAcceptSemantics(String name) {
    return 'Accepter $name';
  }

  @override
  String get teamRefuse => 'Refuser';

  @override
  String teamRefuseSemantics(String name) {
    return 'Refuser $name';
  }

  @override
  String teamMembersHeader(int count) {
    return 'Membres ($count)';
  }

  @override
  String teamMemberYou(String name) {
    return '$name (vous)';
  }

  @override
  String teamMemberAdmin(String name) {
    return '$name · admin';
  }

  @override
  String teamMemberOptions(String name) {
    return 'Options pour $name';
  }

  @override
  String get teamRemove => 'Retirer';

  @override
  String teamRemoveTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String teamRemoveBody(String name) {
    return '$name n\'aura plus accès au secteur. Ses marques restent dans les rues.';
  }

  @override
  String teamCorbeille(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Corbeille · $count éléments',
      one: 'Corbeille · 1 élément',
      zero: 'Corbeille · vide',
    );
    return '$_temp0';
  }

  @override
  String teamStreetsHeader(int count) {
    return 'Rues ($count)';
  }

  @override
  String get teamStreetsHeaderCounting => 'Rues';

  @override
  String get teamAddStreetsHint =>
      'Sur la carte ou depuis la liste des communes';

  @override
  String get teamLeave => 'Quitter le secteur';

  @override
  String teamLeaveTitle(String number) {
    return 'Quitter le secteur $number ?';
  }

  @override
  String get teamLeaveBody =>
      'Pour revenir, il faudra le code et l\'accord d\'un membre.';

  @override
  String get teamLeaveConfirm => 'Quitter';

  @override
  String get teamDelete => 'Supprimer le secteur';

  @override
  String teamDeleteTitle(String number) {
    return 'Supprimer le secteur $number ?';
  }

  @override
  String get teamDeleteBody =>
      'Les rues, les statuts et les membres seront supprimés pour toute l\'équipe. C\'est définitif.';

  @override
  String get teamDeleteConfirm => 'Supprimer';

  @override
  String get teamNoSector => 'Aucun secteur ouvert.';

  @override
  String get teamUnavailable =>
      'L\'équipe ne peut pas être affichée : le secteur n\'est pas sur ce téléphone, ou vous n\'en faites plus partie.';

  @override
  String get teamChanged => 'L\'équipe a changé entre-temps.';

  @override
  String get teamOffline => 'Pas de réseau. Réessayez une fois connecté.';

  @override
  String get recentJustNow => 'à l\'instant';

  @override
  String recentMinutes(int count) {
    return 'il y a $count min';
  }

  @override
  String recentHours(int count) {
    return 'il y a $count h';
  }

  @override
  String get recentYesterday => 'hier';

  @override
  String recentDay(DateTime day) {
    final intl.DateFormat dayDateFormat = intl.DateFormat.MMMd(localeName);
    final String dayString = dayDateFormat.format(day);

    return '$dayString';
  }

  @override
  String get corbeilleIntro =>
      'Les rues et numéros supprimés sont gardés 30 jours avec leurs statuts, puis supprimés définitivement.';

  @override
  String get corbeilleEmpty => 'La corbeille est vide.';

  @override
  String corbeilleNumberTitle(String number, String street) {
    return '$number $street';
  }

  @override
  String corbeilleStreetNumbers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numéros',
      one: '1 numéro',
      zero: 'aucun numéro',
    );
    return '$_temp0';
  }

  @override
  String corbeilleStreetDeletedBy(String name) {
    return 'supprimée par $name';
  }

  @override
  String corbeilleNumberDeletedBy(String name) {
    return 'supprimé par $name';
  }

  @override
  String get corbeilleSomeone => 'un membre';

  @override
  String get corbeilleRestore => 'Restaurer';

  @override
  String corbeilleRestoreSemantics(String item) {
    return 'Restaurer $item';
  }

  @override
  String get welcomeIntro =>
      'Notez chaque porte de votre secteur et suivez l\'avancement de l\'équipe en direct.';

  @override
  String get welcomeNameHelp => 'Visible par votre équipe.';

  @override
  String get createSectorAction => 'Créer un secteur';

  @override
  String get joinSectorAction => 'Rejoindre un secteur';

  @override
  String appTitleSemantics(String title) {
    return '$title. Mes secteurs';
  }

  @override
  String get accountSigningIn => 'Connexion au serveur…';

  @override
  String get accountOffline =>
      'Hors ligne : créer ou rejoindre un secteur demande le réseau.';

  @override
  String get createCentreLabel => 'Centre de secours';

  @override
  String get createCentreListSemantics => 'Centres de secours connus';

  @override
  String createCentreAdd(String name) {
    return 'Ajouter « $name »';
  }

  @override
  String createCentreTooLong(int max) {
    return 'Nom limité à $max caractères.';
  }

  @override
  String get createNumberLabel => 'N° de secteur';

  @override
  String createNumberInvalid(int max) {
    return 'Un numéro de 1 à $max.';
  }

  @override
  String get createYearLabel => 'Année';

  @override
  String createYearInvalid(int first, int last) {
    return 'Une année de $first à $last.';
  }

  @override
  String get createAction => 'Créer';

  @override
  String createTakenTitle(String number, String centre) {
    return 'Le secteur $number du $centre existe déjà.';
  }

  @override
  String get createTakenBody =>
      'Demandez le code ou le QR code à la personne qui l\'a créée.';

  @override
  String get createJoinWithCode => 'Rejoindre avec un code';

  @override
  String get onboardingOffline => 'Pas de réseau. Réessayez une fois connecté.';

  @override
  String createReady(String number, String centre) {
    return 'Secteur $number · $centre est prêt. Montrez ce code à l\'équipe.';
  }

  @override
  String get createContinue => 'Continuer';

  @override
  String get joinScan => 'Scanner le QR code';

  @override
  String get joinOrType => 'ou saisir le code';

  @override
  String get joinCodeSecondSemantics => 'Code, suite';

  @override
  String get joinInvalidCharacter =>
      'Un code n\'a que des lettres et des chiffres, sans 0, O, 1, I ni L.';

  @override
  String get joinScanRefused => 'Ce QR code n\'est pas celui d\'un secteur.';

  @override
  String get joinUnknownCode =>
      'Aucun secteur n\'a ce code. Vérifiez-le auprès de la personne qui vous l\'a donné.';

  @override
  String get joinLookupOffline =>
      'Pas de réseau : le secteur ne peut pas être affiché.';

  @override
  String joinPreviewTitle(String number, String centre) {
    return 'Secteur $number · $centre';
  }

  @override
  String joinPreviewCampaign(String year) {
    return 'Campagne $year';
  }

  @override
  String get joinRequest => 'Demander à rejoindre';

  @override
  String get joinAlreadyJoined => 'Ce secteur est déjà dans « Mes secteurs ».';

  @override
  String get scannerHint => 'Visez le QR code du secteur.';

  @override
  String get scannerUnavailable =>
      'L\'appareil photo n\'est pas disponible. Saisissez le code à la main.';

  @override
  String get joinPendingBody =>
      'Un membre du secteur doit vous accepter. Demandez-le à la personne qui vous a donné le code.';

  @override
  String get joinPendingOpensItself =>
      'Cet écran s\'ouvrira tout seul sur le secteur dès que vous serez accepté.';

  @override
  String get joinPendingSemantics => 'Demande en attente';

  @override
  String get joinPendingCancel => 'Annuler la demande';

  @override
  String get joinRefused => 'Demande refusée';

  @override
  String sectorRemoved(String number) {
    return 'Vous avez été retiré du secteur $number.';
  }

  @override
  String sectorDeleted(String number) {
    return 'Le secteur $number a été supprimé.';
  }

  @override
  String sectorAdminRevoked(String number) {
    return 'Vous n\'êtes plus administrateur : le secteur $number est retiré de Mes secteurs.';
  }

  @override
  String get deviceIdLabel => 'Identifiant de l\'appareil';

  @override
  String get deviceIdIsAdmin => 'Administrateur';

  @override
  String get deviceIdCopy => 'Copier l\'identifiant de l\'appareil';

  @override
  String get deviceIdCopied => 'Identifiant copié';

  @override
  String get deviceIdNoAccount =>
      'Pas encore de compte : connectez-vous au réseau.';

  @override
  String get mySectorsAll => 'Tous les secteurs';

  @override
  String mySectorsVisited(String centre) {
    return '$centre · administrateur';
  }

  @override
  String mySectorsVisitedSemantics(String title, String centre) {
    return '$title, $centre, administrateur, ouvrir';
  }

  @override
  String mySectorsVisitedOpenSemantics(String title, String centre) {
    return '$title, $centre, administrateur, secteur ouvert';
  }

  @override
  String mySectorsUnavailable(String centre) {
    return '$centre · Disponible avec réseau';
  }

  @override
  String mySectorsUnavailableSemantics(String title, String centre) {
    return '$title, $centre, disponible avec réseau';
  }

  @override
  String allSectorsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secteurs',
      one: '1 secteur',
      zero: 'aucun secteur',
    );
    return 'Administrateur · $_temp0';
  }

  @override
  String allSectorsMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
      zero: 'Aucun membre',
    );
    return '$_temp0';
  }

  @override
  String allSectorsMine(String members) {
    return '$members · vous en êtes membre';
  }

  @override
  String allSectorsWaiting(String details, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes en attente',
      one: '1 demande en attente',
    );
    return '$details · $_temp0';
  }

  @override
  String allSectorsRowSemantics(String title, String details) {
    return '$title, $details, ouvrir';
  }

  @override
  String get allSectorsOffline =>
      'Pas de réseau : la liste ne peut pas être affichée.';

  @override
  String get notAdminAnyMore => 'Vous n\'êtes plus administrateur.';

  @override
  String get allSectorsHint =>
      'Ouvrez un secteur pour le gérer : code, équipe, rues. Vous n\'y entrez comme membre que si vous le rejoignez.';

  @override
  String get allSectorsEmpty => 'Aucun secteur pour l\'instant.';

  @override
  String get adminBannerTitle => 'Administrateur · pas membre';

  @override
  String get adminBannerBody =>
      'Vous n\'êtes pas dans l\'équipe de ce secteur.';

  @override
  String get adminBannerJoin => 'Rejoindre';

  @override
  String get teamForgetVisit => 'Retirer de Mes secteurs';

  @override
  String get corbeilleAdmin => 'un administrateur';

  @override
  String get mapLabel => 'Carte du secteur';

  @override
  String get mapLocateMe => 'Me localiser';

  @override
  String get mapLocationServiceOff =>
      'La localisation du téléphone est désactivée.';

  @override
  String get mapLocationRefused =>
      'Autorisez la localisation pour vous situer sur la carte.';

  @override
  String get mapLocationRefusedForever =>
      'La localisation est refusée pour l\'application. Autorisez-la dans les réglages.';

  @override
  String get mapLocationSettings => 'Réglages';

  @override
  String get mapPositionUnavailable =>
      'Position introuvable pour l\'instant. Réessayez dans un moment.';

  @override
  String get galleryMap => 'Carte';

  @override
  String get galleryOpenMap => 'Ouvrir la carte';

  @override
  String get galleryMapSelectRoad => 'Sélectionner une route';

  @override
  String galleryMapStreetTapped(String street) {
    return 'Rue touchée : $street';
  }

  @override
  String galleryMapTapped(String latitude, String longitude) {
    return 'Touché en $latitude, $longitude';
  }

  @override
  String get communesLabel => 'Communes';

  @override
  String get communeAddHint => 'Ajouter une commune…';

  @override
  String communeRemove(String name) {
    return 'Retirer $name';
  }

  @override
  String teamCommunesHeader(int count) {
    return 'Communes ($count)';
  }

  @override
  String get teamAddCommune => 'Ajouter une commune';

  @override
  String get teamCommuneAlreadyIn => 'Cette commune est déjà dans le secteur.';

  @override
  String teamTooManyCommunes(int max) {
    return 'Un secteur a au plus $max communes.';
  }

  @override
  String get addStreetsTitle => 'Ajouter des rues';

  @override
  String get addStreetsModes => 'Ajouter depuis';

  @override
  String get addStreetsMapTab => 'Carte';

  @override
  String get addStreetsListTab => 'Liste';

  @override
  String get alreadyInSector => 'déjà dans le secteur';

  @override
  String addButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count rues',
      one: 'Ajouter 1 rue',
      zero: 'Ajouter',
    );
    return '$_temp0';
  }

  @override
  String addProgress(int done, int total) {
    return 'Ajout en cours… $done/$total';
  }

  @override
  String addDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rues ajoutées au secteur',
      one: '1 rue ajoutée au secteur',
      zero: 'Aucune nouvelle rue',
    );
    return '$_temp0';
  }

  @override
  String addDoneAndRestored(int added, int restored) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added rues ajoutées',
      one: '1 rue ajoutée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      restored,
      locale: localeName,
      other: '$restored restaurées',
      one: '1 restaurée',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String addPartial(int added, int failed, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added rues ajoutées',
      one: '1 rue ajoutée',
      zero: 'Aucune rue ajoutée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed en échec',
      one: '1 en échec',
    );
    return '$_temp0, $_temp1. $reason Les rues encore cochées restent à ajouter.';
  }

  @override
  String homeStreets(int done, int total) {
    return 'Rues · $done/$total';
  }

  @override
  String homeStreetsSemantics(int done, int total) {
    return 'Rues, $done sur $total faits';
  }

  @override
  String get homeNoStreet => 'Aucune rue dans le secteur pour l\'instant.';

  @override
  String get homePanelExpand => 'Afficher toute la liste';

  @override
  String get homePanelReduce => 'Réduire la liste';

  @override
  String get mapLegend => 'Légende';

  @override
  String get mapLegendShow => 'Afficher la légende';

  @override
  String get mapLegendHide => 'Masquer la légende';

  @override
  String get mapLegendStreetDone => 'faite';

  @override
  String get mapLegendStreetPartial => 'en partie';

  @override
  String get mapLegendStreetToDo => 'à faire';

  @override
  String get addStreetsSearchHint => 'Rechercher une rue';

  @override
  String get addStreetsSearchClear => 'Effacer la recherche';

  @override
  String get addStreetsSearchNone => 'Aucune rue trouvée.';

  @override
  String get addStreetsSearchNoNetwork =>
      'Connexion nécessaire pour chercher une rue.';

  @override
  String get addStreetsSearchError =>
      'Le service des adresses ne répond pas. Réessayez dans un moment.';

  @override
  String get streetCardClose => 'Fermer';

  @override
  String streetCardProgress(int done, int total) {
    return '$done/$total faits';
  }

  @override
  String streetCardProgressSemantics(int done, int total) {
    return '$done sur $total faits';
  }

  @override
  String get streetCardOpen => 'Ouvrir';

  @override
  String get manualTitle => 'Rue à la main';

  @override
  String get manualName => 'Nom de la rue';

  @override
  String get manualCommune => 'Commune';

  @override
  String get manualNoCommune =>
      'Le secteur n\'a pas encore de commune : cherchez celle de la rue.';

  @override
  String get manualFrom => 'Du n°';

  @override
  String get manualTo => 'Au n°';

  @override
  String get manualSides => 'Côtés';

  @override
  String get manualBothSides => 'Les deux';

  @override
  String get manualOddSide => 'Impairs';

  @override
  String get manualEvenSide => 'Pairs';

  @override
  String get manualExtras => 'Numéros en plus';

  @override
  String get manualExtrasHelper => 'Séparés par des virgules.';

  @override
  String get manualOffline =>
      'Fonctionne sans réseau. La rue n\'aura pas de tracé sur la carte.';

  @override
  String get manualAdd => 'Ajouter la rue';

  @override
  String manualAdded(String name) {
    return '« $name » ajoutée au secteur.';
  }

  @override
  String get roundStart => 'Commencer une tournée';

  @override
  String get roundAlreadyOnElsewhere =>
      'Une tournée est déjà en cours dans un autre secteur.';

  @override
  String get markingNeedsRound =>
      'Commencez une tournée pour marquer les maisons.';

  @override
  String get markingStartRound => 'Commencer';

  @override
  String get markingMembersOnly =>
      'Seuls les membres en tournée marquent les maisons.';

  @override
  String get roundElapsedJustStarted => 'moins d\'une minute';

  @override
  String roundElapsedMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String roundElapsedHours(int hours, String minutes) {
    return '$hours h $minutes';
  }

  @override
  String roundElapsedWholeHours(int hours) {
    return '$hours h';
  }

  @override
  String roundBandSince(String elapsed) {
    return 'En tournée · $elapsed';
  }

  @override
  String roundBandTotals(String totals) {
    return '$totals ›';
  }

  @override
  String roundBandSpoken(String elapsed, int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En tournée depuis $elapsed, $count dons, $amount. Voir les dons',
      one: 'En tournée depuis $elapsed, $count don, $amount. Voir les dons',
    );
    return '$_temp0';
  }

  @override
  String roundTotals(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dons · $amount',
      one: '$count don · $amount',
    );
    return '$_temp0';
  }

  @override
  String get roundFinish => 'Terminer';

  @override
  String get roundFinishSpoken => 'Terminer la tournée';

  @override
  String amountEuros(int euros) {
    final intl.NumberFormat eurosNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String eurosString = eurosNumberFormat.format(euros);

    return '$eurosString €';
  }

  @override
  String amountEurosCents(int euros, String cents) {
    final intl.NumberFormat eurosNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String eurosString = eurosNumberFormat.format(euros);

    return '$eurosString,$cents €';
  }

  @override
  String amountInputCents(int euros, String cents) {
    return '$euros,$cents';
  }

  @override
  String get donationStepTitle => 'Montant du don';

  @override
  String get donationCancelHouse => 'Annuler : la maison reprend son statut';

  @override
  String get donationCancelDoor => 'Annuler : la porte reprend son statut';

  @override
  String get paymentMethodGroup => 'Moyen de paiement';

  @override
  String get paymentCash => 'Espèces';

  @override
  String get paymentCheque => 'Chèque';

  @override
  String get paymentCard => 'Carte';

  @override
  String get paymentCardLong => 'Carte bancaire';

  @override
  String get paymentCheques => 'Chèques';

  @override
  String get donationOtherAmount => 'Autre montant';

  @override
  String get donationFreeCalendar => 'Calendrier offert';

  @override
  String get amountLabel => 'Montant';

  @override
  String get amountSuffix => '€';

  @override
  String get amountHint => 'Par exemple 7,50';

  @override
  String get amountEmpty => 'Écrivez un montant.';

  @override
  String get amountNotValid => 'Entrez un montant valide.';

  @override
  String get amountTooManyDecimals => 'Deux chiffres après la virgule au plus.';

  @override
  String get amountTooLarge => '1 000 € au plus par don.';

  @override
  String get donationValidate => 'Valider';

  @override
  String donationPaid(String amount, String method) {
    return '$amount en $method';
  }

  @override
  String get paymentCashWord => 'espèces';

  @override
  String get paymentChequeWord => 'chèque';

  @override
  String get paymentCardWord => 'carte';

  @override
  String get donationFreeWord => 'calendrier offert';

  @override
  String houseDoneWithDonation(String number, String donation) {
    return 'N° $number fait · $donation';
  }

  @override
  String doorDoneWithDonation(String label, String donation) {
    return 'Porte $label : fait · $donation';
  }

  @override
  String houseDonationAdded(String number, String donation) {
    return 'N° $number · $donation ajouté';
  }

  @override
  String doorDonationAdded(String label, String donation) {
    return 'Porte $label · $donation ajouté';
  }

  @override
  String get addDonation => 'Ajouter un don';

  @override
  String get donsTitle => 'Dons de la tournée';

  @override
  String get donsEmpty => 'Aucun don pour l\'instant.';

  @override
  String get donationNewTitle => 'Nouveau don';

  @override
  String get donationEditTitle => 'Modifier le don';

  @override
  String get donationRemove => 'Supprimer ce don';

  @override
  String get recapTitle => 'Bilan de la tournée';

  @override
  String recapWhen(DateTime day, String start, String end) {
    final intl.DateFormat dayDateFormat = intl.DateFormat.MMMMEEEEd(localeName);
    final String dayString = dayDateFormat.format(day);

    return '$dayString, de $start à $end';
  }

  @override
  String clockTime(int hour, String minute) {
    return '$hour h $minute';
  }

  @override
  String clockTimeWhole(int hour) {
    return '$hour h';
  }

  @override
  String recapHouses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'maisons visitées',
      one: 'maison visitée',
    );
    return '$_temp0';
  }

  @override
  String recapDons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dons',
      one: 'don',
    );
    return '$_temp0';
  }

  @override
  String recapFree(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'calendriers offerts',
      one: 'calendrier offert',
    );
    return '$_temp0';
  }

  @override
  String get recapMoney => 'Argent récolté';

  @override
  String donCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dons',
      one: '$count don',
    );
    return '$_temp0';
  }

  @override
  String get recapTotal => 'Total';

  @override
  String get recapSeeDons => 'Voir les dons';

  @override
  String get recapValidate => 'Valider la tournée';

  @override
  String get recapContinue => 'Continuer la tournée';

  @override
  String get recapConfirmTitle => 'Valider la tournée ?';

  @override
  String get recapConfirmBody => 'Vous ne pourrez plus la modifier.';

  @override
  String get recapConfirmOk => 'Valider';

  @override
  String collecteTitle(String campaign) {
    return 'Collecte $campaign';
  }

  @override
  String teamCollecteRaised(String amount) {
    return '$amount récoltés';
  }

  @override
  String teamCollecteDons(String dons, int rounds) {
    String _temp0 = intl.Intl.pluralLogic(
      rounds,
      locale: localeName,
      other: '$rounds tournées',
      one: '$rounds tournée',
    );
    return '$dons en $_temp0';
  }

  @override
  String teamCollecteSpoken(String title, String raised, String dons) {
    return '$title : $raised, $dons';
  }

  @override
  String collecteSubtitle(String number) {
    return 'Secteur $number · tournées validées';
  }

  @override
  String collecteTotalHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Total des $count tournées',
      one: 'Total de la tournée',
      zero: 'Total des tournées',
    );
    return '$_temp0';
  }

  @override
  String get collecteFree => 'Calendriers offerts';

  @override
  String get collecteRoundsHeader => 'Tournées';

  @override
  String collecteRoundWhen(DateTime day, DateTime start, DateTime end) {
    final intl.DateFormat dayDateFormat = intl.DateFormat.MMMEd(localeName);
    final String dayString = dayDateFormat.format(day);
    final intl.DateFormat startDateFormat = intl.DateFormat.Hm(localeName);
    final String startString = startDateFormat.format(start);
    final intl.DateFormat endDateFormat = intl.DateFormat.Hm(localeName);
    final String endString = endDateFormat.format(end);

    return '$dayString · $startString → $endString';
  }

  @override
  String collecteRoundLine(int houses, String dons) {
    String _temp0 = intl.Intl.pluralLogic(
      houses,
      locale: localeName,
      other: '$houses maisons',
      one: '$houses maison',
    );
    return '$_temp0, $dons';
  }

  @override
  String collecteRoundShow(String when, String amount) {
    return '$when, $amount, afficher le détail';
  }

  @override
  String collecteRoundHide(String when, String amount) {
    return '$when, $amount, masquer le détail';
  }

  @override
  String get collecteNeverChanged =>
      'Une tournée validée ne peut plus être modifiée. Les dons ne sont jamais associés à une adresse.';

  @override
  String get collecteUnavailable => 'La collecte ne peut pas être affichée.';

  @override
  String get addStreetsPickHint =>
      'Touchez les rues à ajouter ou tracez une zone.';

  @override
  String addStreetsPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rues sélectionnées',
      one: '1 rue sélectionnée',
    );
    return '$_temp0';
  }

  @override
  String addStreetsPickedFacts(String commune, String numbers) {
    return '$commune · $numbers';
  }

  @override
  String addStreetsNumbers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numéros',
      one: '1 numéro',
      zero: 'aucun numéro',
    );
    return '$_temp0';
  }

  @override
  String addStreetsUntick(String name) {
    return 'Retirer $name';
  }

  @override
  String get addStreetsFold => 'Réduire la sélection';

  @override
  String get addStreetsUnfold => 'Afficher la sélection';

  @override
  String get addStreetsLookingUp => 'Recherche de la rue…';

  @override
  String addStreetsAlreadyIn(String name) {
    return '$name est déjà dans le secteur.';
  }

  @override
  String get addStreetsNoNetwork =>
      'Connexion nécessaire pour ajouter une rue.';

  @override
  String get addStreetsNoStreetHere => 'Aucune rue connue ici.';

  @override
  String get addStreetsServiceError => 'Le service des adresses ne répond pas.';

  @override
  String get addStreetsManualAction => 'Saisir à la main';

  @override
  String get addStreetsManualLink =>
      'Rue absente de la carte ? Saisir à la main';

  @override
  String addStreetsAddFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rues n\'ont pas pu être ajoutées : la Base Adresse Nationale donne des numéros incohérents. Saisissez-les à la main.',
      one: '1 rue n\'a pas pu être ajoutée : la Base Adresse Nationale donne des numéros incohérents. Saisissez-la à la main.',
    );
    return '$_temp0';
  }

  @override
  String addStreetsAddFailedNoNetwork(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rues n\'ont pas pu être ajoutées : connexion nécessaire.',
      one: '1 rue n\'a pas pu être ajoutée : connexion nécessaire.',
    );
    return '$_temp0';
  }

  @override
  String addStreetsAddFailedService(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rues n\'ont pas pu être ajoutées : le service des adresses ne répond pas. Réessayez plus tard.',
      one: '1 rue n\'a pas pu être ajoutée : le service des adresses ne répond pas. Réessayez plus tard.',
    );
    return '$_temp0';
  }

  @override
  String get addStreetsZone => 'Zone';

  @override
  String get addStreetsZoneStart => 'Sélectionner une zone';

  @override
  String get addStreetsZoneStop => 'Zone en cours, annuler';

  @override
  String get addStreetsZoneHint =>
      'Faites glisser le doigt sur la carte pour tracer une zone.';

  @override
  String get addStreetsZoneLooking => 'Recherche des rues de la zone…';

  @override
  String addStreetsZoneStreets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rues dans la zone',
      one: '1 rue dans la zone',
      zero: 'Aucune rue dans la zone',
    );
    return '$_temp0';
  }

  @override
  String get addStreetsZoneInSector => 'Déjà dans le secteur';

  @override
  String get addStreetsZoneNoAddress => 'Aucune adresse connue';

  @override
  String get addStreetsZoomIn => 'Zoomez pour tracer une zone.';

  @override
  String addStreetsZoneTooLarge(int max) {
    return 'Zone trop grande : $max rues au plus.';
  }
}
