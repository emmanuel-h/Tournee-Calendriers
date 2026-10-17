import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// The paths of every screen of PLAN §5, so no path string is typed twice.
///
/// Sheets (Fiche maison, Immeuble, Mes tournées, Ajouter des numéros…) are
/// not routes: they open over the screen that owns them.
abstract final class AppRoutes {
  /// Where the app starts: Accueil (§5.3) while a tournée is open, the
  /// phone's own « Mes rues » (§5.0) otherwise.
  static const home = '/';

  /// « Importer des rues », with no tournée open (§5.0).
  static const importStreets = '/importer-des-rues';

  /// « Ajouter des rues », « Carte | Liste », while a tournée is open
  /// (§5.4).
  static const addStreets = '/ajouter-des-rues';

  /// « Rue à la main », pushed from « Ajouter des rues » (§5.5).
  static const manualStreet = '/ajouter-des-rues/a-la-main';

  /// « Bienvenue », where a phone the app knows nothing of opens (§5.1).
  static const welcome = '/bienvenue';

  /// « Nouvelle tournée » and « Rejoindre une tournée » (§5.2).
  static const create = '/creer';
  static const join = '/rejoindre';
  static const joinPending = '/rejoindre/attente';

  /// « Demande envoyée » for the request to join [tournee]:
  /// `/rejoindre/attente?id=…`.
  static String joinPendingOf(TourneeId tournee) =>
      Uri(path: joinPending, queryParameters: {'id': tournee.value}).toString();
  static const street = '/rue';

  /// The street screen of the street [id]: `/rue?id=…`.
  static String streetOf(StreetId id) =>
      Uri(path: street, queryParameters: {'id': id.value}).toString();
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
  static const team = '/equipe';

  /// « Toutes les tournées », for admins, pushed from « Mes tournées »
  /// (§5.12).
  static const allTournees = '/toutes-les-tournees';
  static const settings = '/parametres';

  /// « Confidentialité », pushed from Paramètres.
  static const privacy = '/parametres/confidentialite';

  /// « Nouveautés », pushed by the version row of Paramètres.
  static const changelog = '/parametres/nouveautes';
  static const trash = '/corbeille';

  /// Debug builds only: every shared component on one screen.
  static const gallery = '/composants';

  /// Debug builds only: the map widget on sample streets, pushed from the
  /// gallery.
  static const galleryMap = '/composants/carte';
}
