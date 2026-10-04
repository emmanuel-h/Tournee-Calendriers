import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/mark.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/note.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';

/// Which house a sheet shows. A record: two records with the same fields
/// are equal, so `houseSheetProvider(key)` finds the same notifier for the
/// same house.
typedef HouseSheetKey = ({StreetId street, HouseNumber number});

/// The state of the Fiche maison of one house (PLAN §5.7).
///
/// `family`: one notifier per house; `autoDispose`: it stops following the
/// street once the sheet is closed.
final houseSheetProvider = NotifierProvider.autoDispose
    .family<HouseSheetNotifier, HouseSheetState, HouseSheetKey>(
      HouseSheetNotifier.new,
    );

/// Follows one house of a street on the phone (`ObserveStreet`, offline)
/// and stores each control of its sheet through `SetHouseDetails`: the
/// status, the « repasser » and its hint, the note.
///
/// - **Nothing changed, nothing stored.** The sheet saves its text fields
///   whenever they could be lost (closed, sent to the background…); a text
///   equal to the stored one, or a status the house already has, stores
///   nothing, so opening and closing a sheet does not stamp the house.
/// - **One change at a time.** Each change waits for the previous one to be
///   stored, then decides on the house as it then is. Started together (the
///   note leaves its field as « Fait » is tapped), two changes would both
///   start from the same street, and the second would erase the first.
final class HouseSheetNotifier extends Notifier<HouseSheetState> {
  HouseSheetNotifier(this.key);

  final HouseSheetKey key;

  /// The street last read; null until read, or when there is none.
  Street? _street;
  var _read = false;

  /// The last change asked; the next one starts when it ends.
  Future<void> _pending = Future.value();

  @override
  HouseSheetState build() {
    final subscription = ref.watch(observeStreetProvider)(key.street).listen((
      street,
    ) {
      _street = street;
      _read = true;
      state = _view();
    });
    ref.onDispose(subscription.cancel);
    return _view();
  }

  /// The status control: gives the house [status]. « Fait » also clears
  /// the « repasser » (a done house has none, PLAN §6.1).
  Future<void> setStatus(VisitStatus status) =>
      _change((house) => house.status == status ? null : StatusMark(status));

  /// The « Repasser » box, ticked ([on]) or not. Ticking gives a
  /// « repasser » without hint, which the hint field then completes;
  /// unticking drops the hint too. Refused on a done house: nothing
  /// changes.
  Future<void> setComeBack({required bool on}) => _change(
    (house) => (house.comeBack != null) == on
        ? null
        : ComeBackMark(on ? ComeBack.withoutHint : null),
  );

  /// The hint field (« après 19h »), stored once trimmed. Nothing happens
  /// when « Repasser » is not ticked or the hint is too long (the field
  /// refuses such a text first, see [TextLimit]).
  Future<void> saveComeBackHint(String text) => _change(
    (house) => switch ((house.comeBack, ComeBack.create(text))) {
      (null, _) || (_, Err()) => null,
      (final stored, Ok(:final value)) =>
        value == stored ? null : ComeBackMark(value),
    },
  );

  /// The note field, stored once trimmed; a blank text erases the note.
  /// Nothing happens when it is too long.
  Future<void> saveNote(String text) => _change(
    (house) => switch (Note.create(text)) {
      Ok(:final value) => value == house.note ? null : NoteMark(value),
      Err() => null,
    },
  );

  /// Queues the change [markFor] makes on the house as it is when its turn
  /// comes (null: nothing to change). A refused change leaves the house as
  /// it is; the sheet shows it.
  Future<void> _change(Mark? Function(House house) markFor) {
    // Read now, not when the turn comes: the sheet saves its fields as it
    // closes, and this notifier may be disposed by then.
    final setHouseDetails = ref.read(setHouseDetailsProvider);
    final step = _pending.then((_) async {
      final house = _house;
      if (house == null) return;
      final mark = markFor(house);
      if (mark == null) return;
      await setHouseDetails(key.street, key.number, mark);
    });
    // A change that failed to be stored (a full disk) must not block the
    // ones after it; its caller still gets the error through `step`.
    _pending = step.then<void>((_) {}, onError: (Object _) {});
    return step;
  }

  /// The single house the sheet shows, or null when there is none.
  House? get _house {
    final street = _street;
    if (street == null || street.isDeleted) return null;
    for (final house in street.houses) {
      if (house.number == key.number) {
        return house.isBuilding ? null : house;
      }
    }
    return null;
  }

  HouseSheetState _view() {
    if (!_read) return const HouseSheetLoading();
    final house = _house;
    if (house == null) return const HouseSheetGone();
    final stamp = house.lastChange;
    return HouseSheetShown(
      streetName: _street!.name,
      number: house.number,
      status: house.status,
      comeBack: house.comeBack != null,
      comeBackHint: house.comeBack?.hint ?? '',
      note: house.note.text,
      // The clock tells « today » from « earlier »; reading it here, and
      // not `DateTime.now()`, lets the tests fix the day.
      lastChange: stamp == null
          ? null
          : LastChange.of(stamp.at, now: ref.read(clockProvider).now()),
    );
  }
}
