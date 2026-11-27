/// What an administrator may do in one centre de secours (PLAN §5.23):
/// each admin holds some of these per CS, given by the super admin.
///
/// The security rules check the same permission against the secteur's
/// `centreKey`, so the app only uses them to show or hide a command.
enum Permission {
  /// « Campagne »: end and start the CS's year (PLAN §5.22, the copy of
  /// the streets of #39), correct its validated tournées.
  campaign,

  /// « Secteurs »: « + Nouveau secteur » in the CS, « Supprimer le
  /// secteur », « Nouveau code ».
  sectors,

  /// « Équipes »: accept and refuse requests, « Retirer » a member, and
  /// « Rejoindre » a secteur without a code.
  teams,

  /// « Rues »: the streets and communes of a secteur the admin is not a
  /// member of (add, change, remove), and later the CS's Couverture.
  streets,
}

/// What an administrator may do outside any centre de secours (PLAN
/// §5.23): written only by hand in the Firebase console, never by the app.
/// Neither gives any power over a secteur: those come from [Permission]s.
enum GlobalPermission {
  /// Manage the admins (the Administrateurs screen) and « Rouvrir » a
  /// year. Its holder is the « Super administrateur ».
  admins,

  /// Create a new centre de secours (with its first secteur).
  centres,
}
