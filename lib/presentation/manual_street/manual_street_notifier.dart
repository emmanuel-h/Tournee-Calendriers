import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_commune.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/manual_street/manual_street_state.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';

export 'package:tournee_calendriers/presentation/manual_street/manual_street_state.dart';

/// The state of « Rue à la main ». `autoDispose`: the form starts empty
/// each time the screen opens.
final manualStreetProvider =
    NotifierProvider.autoDispose<ManualStreetNotifier, ManualStreetState>(
      ManualStreetNotifier.new,
    );

/// « Rue à la main » (PLAN §5.5): reads the form at each key (the domain's
/// `manualStreetNumbers` and [StreetName]) and adds the street through
/// `AddManualStreet`, for the member who types it. Needs no network.
final class ManualStreetNotifier extends Notifier<ManualStreetState> {
  var _tourneeCommunes = const <TourneeCommune>[];
  var _streets = const <Street>[];

  /// The commune chosen in the list, or found by the search.
  Commune? _chosen;

  var _name = '';
  var _from = '';
  var _to = '';
  var _sides = Sides.both;
  var _extras = '';
  var _adding = false;

  @override
  ManualStreetState build() {
    _tourneeCommunes = const [];
    _streets = const [];
    _chosen = null;
    _name = '';
    _from = '';
    _to = '';
    _sides = Sides.both;
    _extras = '';
    _adding = false;
    final streets = ref.watch(observeStreetsProvider)().listen(
      (streets) {
        _streets = streets;
        _show();
      },
      // The streets cannot be read: they name no commune.
      onError: (Object _) {},
    );
    ref.onDispose(streets.cancel);
    if (ref.watch(currentTourneeProvider) case final tournee?) {
      final communes = ref
          .watch(observeTourneeCommunesProvider)(tournee.id)
          .listen(
            (communes) {
              _tourneeCommunes = communes;
              _show();
            },
            // The tournée can no longer be read (the member was removed):
            // the communes last read stay.
            onError: (Object _) {},
          );
      ref.onDispose(communes.cancel);
    }
    return _view();
  }

  /// « Nom de la rue » changed.
  void setName(String text) {
    _name = text;
    _show();
  }

  /// A commune of the list was chosen.
  void chooseCommune(InseeCode commune) {
    _chosen = _communes().where((c) => c.inseeCode == commune).firstOrNull;
    _show();
  }

  /// A commune found by the search (a tournée with no commune known).
  void pickCommune(Commune commune) {
    _chosen = commune;
    _show();
  }

  /// « Du n° » changed.
  void setFrom(String text) {
    _from = text;
    _show();
  }

  /// « Au n° » changed.
  void setTo(String text) {
    _to = text;
    _show();
  }

  /// « Les deux | Impairs | Pairs ».
  void setSides(Sides sides) {
    _sides = sides;
    _show();
  }

  /// « Numéros en plus » changed.
  void setExtras(String text) {
    _extras = text;
    _show();
  }

  /// « Ajouter la rue »: stores the street, given to the member, and
  /// returns its name for the message; null when the form cannot add one
  /// yet (the button is then disabled anyway).
  Future<String?> add() async {
    final view = _view();
    if (!view.canAdd) return null;
    // `canAdd` promises a valid name, a commune and some numbers: the
    // casts and the `!` below cannot fail.
    final name = StreetName.create(_name) as Ok<StreetName, StreetNameFailure>;
    final commune = view.commune!;
    final numbers = (view.preview as NumbersPreviewed).numbers;
    _adding = true;
    _show();
    final street = await ref.read(addManualStreetProvider)(
      name: name.value,
      commune: commune,
      numbers: numbers,
      // So the street is not lost to nobody's « Mes rues »: the member
      // who types it knows it is to be done.
      assignToMe: true,
    );
    if (ref.mounted) {
      _adding = false;
      _show();
    }
    return street.name.text;
  }

  /// The tournée's communes, else those of its streets, each once.
  List<Commune> _communes() => _tourneeCommunes.isNotEmpty
      ? [for (final commune in _tourneeCommunes) commune.commune]
      : {
          for (final street in _streets)
            street.commune.inseeCode: street.commune,
        }.values.toList();

  void _show() => state = _view();

  ManualStreetState _view() {
    final communes = _communes();
    final name = StreetName.create(_name);
    return ManualStreetState(
      communes: communes,
      commune: _chosen ?? communes.firstOrNull,
      sides: _sides,
      nameProblem: switch (name) {
        Err(failure: StreetNameFailure.tooLong) => StreetNameFailure.tooLong,
        _ => null,
      },
      nameIsValid: name is Ok,
      preview: switch (manualStreetNumbers(
        from: _from,
        to: _to,
        sides: _sides,
        extras: _extras,
      )) {
        Err(:final failure) => NumbersRefused(failure),
        Ok(value: final numbers) when numbers.isEmpty => const NothingTyped(),
        Ok(value: final numbers) => NumbersPreviewed(
          numbers: numbers,
          alreadyThere: const [],
          fromCorbeille: const [],
        ),
      },
      adding: _adding,
    );
  }
}
