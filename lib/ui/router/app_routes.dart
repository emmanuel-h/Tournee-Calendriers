/// The paths of every screen of PLAN §5, so no path string is typed twice.
///
/// Sheets (Fiche maison, Immeuble, Mes tournées, Ajouter des numéros…) are
/// not routes: they open over the screen that owns them.
abstract final class AppRoutes {
  /// Accueil (§5.3), where the app starts.
  static const home = '/';
  static const welcome = '/bienvenue';
  static const create = '/creer';
  static const join = '/rejoindre';
  static const joinPending = '/rejoindre/attente';
  static const addStreets = '/ajouter-des-rues';
  static const manualStreet = '/rue-a-la-main';
  static const street = '/rue';
  static const editStreet = '/rue/modifier';
  static const team = '/equipe';
  static const settings = '/parametres';
  static const newCampaign = '/nouvelle-campagne';
  static const trash = '/corbeille';

  /// Debug builds only: every shared component on one screen.
  static const gallery = '/composants';
}
