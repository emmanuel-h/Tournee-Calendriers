import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/team_roster.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';

/// Follows the open tournée's team (`ObserveTeam`, from the phone's copy,
/// offline too), so a street card names who covers the street (« Faite
/// par Manu »), and the map draws « libre » a street whose every assignee
/// left the team (#91).
///
/// A `mixin` adds these members to the notifiers that need them; `on
/// Notifier<S>` lets it use their `ref` and `state`.
mixin FollowsTeam<S> on Notifier<S> {
  Sector? _team;

  /// The open tournée as last read; null while none is open, or while it
  /// cannot be read (offline and never seen, the member removed).
  Sector? get team => _team;

  /// Who still covers a street, as last read: every assignee while the
  /// [team] is not known (see [TeamRoster]).
  TeamRoster get roster =>
      TeamRoster.of(_team, me: ref.read(readCurrentMemberProvider)());

  /// The state from what the notifier knows, again each time the team
  /// changes.
  S render();

  /// Starts following; called from `build`.
  void followTeam() {
    // Riverpod keeps the notifier when it builds again (another tournée
    // opened): the old team must not name anyone.
    _team = null;
    // `select`: built again when another tournée opens, not when the one
    // open changes otherwise.
    final sector = ref.watch(
      currentSectorProvider.select((sector) => sector?.id),
    );
    if (sector == null) return;
    final subscription = ref.watch(observeTeamProvider)(sector).listen(
      (team) {
        _team = team;
        state = render();
      },
      // The team cannot be read: the cards name nobody, nothing else
      // changes.
      onError: (Object _) {},
    );
    ref.onDispose(subscription.cancel);
  }
}
