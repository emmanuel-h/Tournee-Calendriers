import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// What every screen of one street shares: it follows the street on the
/// phone (`ObserveStreet`, which works offline) and draws its state again
/// each time the street changes, whoever changed it.
///
/// A mixin is a bundle of fields and methods a class takes in with `with`;
/// `on Notifier<S>` means only a notifier can take it, so the mixin may use
/// `ref` and `state`. The notifier calls [followStreet] from its `build`
/// and says how it draws itself in [render].
mixin FollowsStreet<S> on Notifier<S> {
  Street? _street;
  var _read = false;

  /// Whether the street has been read once; until then the screen shows
  /// its loading state.
  bool get streetRead => _read;

  /// The street as last read; null until it is read, when there is none, or
  /// when it is in the Corbeille: the screens show it as gone.
  Street? get street => switch (_street) {
    final street? when !street.isDeleted => street,
    _ => null,
  };

  /// The state for the street as it is now.
  S render();

  /// Starts following the street [id]; `build` then returns [render].
  void followStreet(StreetId id) {
    // `ref.watch` on the use case: should its repository be replaced, the
    // notifier is built again and listens to the new one.
    final subscription = ref.watch(observeStreetProvider)(id).listen((street) {
      _street = street;
      _read = true;
      state = render();
    });
    // The subscription lives as long as the notifier; Riverpod calls this
    // when the screen no longer needs it.
    ref.onDispose(subscription.cancel);
  }
}
