/// Why a tournée of « Mes secteurs » is no longer the member's, as the
/// server tells it (PLAN §5.3, §5.8): the phone then forgets it and says
/// so (« Vous avez été retiré du secteur 49. »).
///
/// Leaving (« Quitter le secteur ») and deleting from this phone are not
/// losses: the member did it, the phone forgets the tournée at once and
/// has nothing to tell.
enum SectorLoss {
  /// An admin removed the member (« Retirer »); the tournée goes on
  /// without them.
  removed,

  /// The tournée was deleted, with everything it held.
  deleted,

  /// The phone is no longer an admin, and it only visited the tournée
  /// (PLAN §5.12): it may not read it any more.
  adminRevoked,
}
