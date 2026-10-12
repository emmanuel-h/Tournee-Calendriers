/// Why a tournée of « Mes tournées » is no longer the member's, as the
/// server tells it (PLAN §5.3, §5.8): the phone then forgets it and says
/// so (« Vous avez été retiré de la tournée 49. »).
///
/// Leaving (« Quitter la tournée ») and deleting from this phone are not
/// losses: the member did it, the phone forgets the tournée at once and
/// has nothing to tell.
enum TourneeLoss {
  /// The creator removed the member (« Retirer »); the tournée goes on
  /// without them.
  removed,

  /// The tournée was deleted, with everything it held.
  deleted,
}
