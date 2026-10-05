import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/staircase.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/presentation/street/follows_street.dart';

/// The staircase control of a building's screens (the grid, « Modifier les
/// portes »): one staircase is shown at a time.
///
/// `on FollowsStreet<S>`: only a notifier that follows its street can take
/// it, so a choice draws the screen again with `render`.
mixin ChoosesStaircase<S> on FollowsStreet<S> {
  /// The staircase chosen; null until one is, then the first is shown.
  StaircaseName? _chosen;

  /// The staircase control: shows the floors of [name].
  void selectStaircase(StaircaseName name) {
    _chosen = name;
    state = render();
  }

  /// The staircase of [building] to show: the one chosen, or the first when
  /// none was chosen or the chosen one went with a new layout.
  Staircase shownIn(Building building) => building.staircases.firstWhere(
    (staircase) => staircase.name == _chosen,
    orElse: () => building.staircases.first,
  );
}
