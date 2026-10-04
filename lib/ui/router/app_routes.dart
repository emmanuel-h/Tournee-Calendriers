import 'package:tournee_calendriers/domain/street/street_id.dart';

/// The paths of every screen of PLAN §5, so no path string is typed twice.
///
/// Sheets (Fiche maison, Immeuble, Mes tournées, Ajouter des numéros…) are
/// not routes: they open over the screen that owns them.
abstract final class AppRoutes {
  /// Where the app starts: « Mes rues », the temporary start screen of M1
  /// (§5.0); Accueil (§5.3) from M3.
  static const home = '/';

  /// « Importer des rues », the temporary import screen of M1 (§5.0).
  static const importStreets = '/importer-des-rues';
  static const welcome = '/bienvenue';
  static const create = '/creer';
  static const join = '/rejoindre';
  static const joinPending = '/rejoindre/attente';
  static const addStreets = '/ajouter-des-rues';
  static const manualStreet = '/rue-a-la-main';
  static const street = '/rue';

  /// The street screen of the street [id]: `/rue?id=…`.
  static String streetOf(StreetId id) =>
      Uri(path: street, queryParameters: {'id': id.value}).toString();
  static const editStreet = '/rue/modifier';

  /// The edit mode of the street [id]: `/rue/modifier?id=…`.
  static String editStreetOf(StreetId id) =>
      Uri(path: editStreet, queryParameters: {'id': id.value}).toString();
  static const team = '/equipe';
  static const settings = '/parametres';
  static const newCampaign = '/nouvelle-campagne';
  static const trash = '/corbeille';

  /// Debug builds only: every shared component on one screen.
  static const gallery = '/composants';
}
