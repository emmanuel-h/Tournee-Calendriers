import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

/// The paths of every screen of PLAN §5, so no path string is typed twice.
///
/// Sheets (Fiche maison, Immeuble, Mes secteurs, Ajouter des numéros…) are
/// not routes: they open over the screen that owns them.
abstract final class AppRoutes {
  /// Where the app starts: Accueil (§5.3) while a secteur is open,
  /// « Aucun secteur ouvert » (§5.0) otherwise.
  static const home = '/';

  /// « Ajouter des rues », « Carte | Liste » (§5.4), pushed from Secteur
  /// (§5.14).
  static const addStreets = '/ajouter-des-rues';

  /// « Rue à la main », pushed from « Ajouter des rues » (§5.5).
  static const manualStreet = '/ajouter-des-rues/a-la-main';

  /// « Bienvenue », where a phone the app knows nothing of opens (§5.1).
  static const welcome = '/bienvenue';

  /// « Nouveau secteur » and « Rejoindre un secteur » (§5.2).
  static const create = '/creer';
  static const join = '/rejoindre';
  static const joinPending = '/rejoindre/attente';

  /// « Demande envoyée » for the request to join [sector]:
  /// `/rejoindre/attente?id=…`.
  static String joinPendingOf(SectorId sector) =>
      Uri(path: joinPending, queryParameters: {'id': sector.value}).toString();
  static const street = '/rue';

  /// The street screen of the street [id]: `/rue?id=…`.
  static String streetOf(StreetId id) =>
      Uri(path: street, queryParameters: {'id': id.value}).toString();

  /// The street of [place], scrolled to its house, ringed for a moment
  /// (PLAN §5.17); with a door, its building's grid opens at that door:
  /// `/rue?id=…&numero=12` or `/rue?id=…&numero=8&porte=A5-51`.
  static String streetAt(ComeBackPlace place) => Uri(
    path: street,
    queryParameters: {
      'id': place.street.value,
      'numero': place.number.label,
      if (place.door case final door?) 'porte': door.id,
    },
  ).toString();
  static const editStreet = '/rue/modifier';

  /// The edit mode of the street [id]: `/rue/modifier?id=…`.
  static String editStreetOf(StreetId id) =>
      Uri(path: editStreet, queryParameters: {'id': id.value}).toString();
  static const adjustDoors = '/rue/modifier/portes';

  /// « Modifier les portes » of the building [number] of the street [id]:
  /// `/rue/modifier/portes?id=…&numero=8`.
  static String adjustDoorsOf(StreetId id, HouseNumber number) => Uri(
    path: adjustDoors,
    queryParameters: {'id': id.value, 'numero': number.label},
  ).toString();

  /// Secteur (§5.8, §5.14), pushed by Accueil's title (#135).
  static const team = '/equipe';

  /// « Tous les secteurs », for admins, pushed from « Mes secteurs »
  /// (§5.12).
  static const allSectors = '/tous-les-secteurs';
  static const settings = '/parametres';

  /// « Confidentialité », pushed from Paramètres.
  static const privacy = '/parametres/confidentialite';

  /// « Nouveautés », pushed by the version row of Paramètres.
  static const changelog = '/parametres/nouveautes';
  static const trash = '/corbeille';

  /// « Dons de la tournée » (§5.13), pushed by « Voir les dons › ».
  static const roundDons = '/tournee/dons';

  /// « Bilan de la tournée » (§5.13), pushed by « ■ Terminer ».
  static const roundRecap = '/tournee/bilan';

  /// « Collecte 2026 » (§5.13), pushed by Secteur's « COLLECTE 2026 » row.
  static const collecte = '/equipe/collecte';

  /// « À repasser » (§5.17), pushed by its row on Accueil or a reminder.
  static const comeBacks = '/a-repasser';

  /// Debug builds only: every shared component on one screen.
  static const gallery = '/composants';

  /// Debug builds only: the map widget on sample streets, pushed from the
  /// gallery.
  static const galleryMap = '/composants/carte';
}
