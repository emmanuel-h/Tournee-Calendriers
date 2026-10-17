import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/create_tournee.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/presentation/account/account_notifier.dart';
import 'package:tournee_calendriers/presentation/account/account_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/new_tournee/new_tournee_state.dart';

/// How long the duplicate check waits after the last change of the centre
/// or the number, so typing « 149 » asks the server once, not three times.
/// A provider so tests can set it to zero.
final duplicateCheckDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 300),
);

/// « Nouvelle tournée ». `autoDispose`: each visit starts afresh.
final newTourneeProvider =
    NotifierProvider.autoDispose<NewTourneeNotifier, NewTourneeState>(
      NewTourneeNotifier.new,
    );

/// « Nouvelle tournée » (PLAN §5.2): the centre de secours picked from the
/// known ones or added, the number checked as it is typed, the year, then
/// « Créer », which shows the code and the QR code once done.
///
/// Everything asked of the server waits for the phone's account
/// (`accountProvider`): after an offline first start, « Réessayer » there
/// is enough, no restart.
final class NewTourneeNotifier extends Notifier<NewTourneeState> {
  /// Raised by each change of the centre or the number, and by « Créer ».
  /// A check remembers the value it started with and gives up when it has
  /// changed: that is both the pause in the typing and the guard against a
  /// late answer about an older number.
  var _checks = 0;

  @override
  NewTourneeState build() {
    // `listen`, not `watch`: the account signing in must not start the
    // form again, only let it ask the server.
    ref.listen(accountProvider, (_, account) => _follow(account));
    final signedIn = ref.read(accountProvider) is AccountSignedIn;
    if (signedIn) {
      // After `build` has returned: the state does not exist before.
      scheduleMicrotask(_askServer);
    }
    return NewTourneeState.start(
      // The year on the phone's calendar.
      initialYear: '${ref.read(clockProvider).now().toLocal().year}',
      signedIn: signedIn,
      hasName: ref.read(readPhoneSettingsProvider)().name != null,
    );
  }

  void _follow(AccountState account) {
    final signedIn = account is AccountSignedIn;
    if (signedIn == state.signedIn) return;
    state = state.copyWith(signedIn: signedIn);
    if (signedIn) _askServer();
  }

  /// Now that the phone has its account: the known centres, and whether
  /// what is typed already exists.
  void _askServer() {
    if (!ref.mounted) return;
    unawaited(_listCentres());
    unawaited(_check());
  }

  Future<void> _listCentres() async {
    state = state.copyWith(known: const CentresLoading());
    final listed = await ref.read(listRescueCentresProvider)();
    if (!ref.mounted) return;
    state = state.copyWith(
      known: switch (listed) {
        Ok(:final value) => CentresLoaded(value),
        Err() => const CentresUnavailable(),
      },
    );
  }

  /// « Centre de secours » changed to [text]: nothing is picked any more.
  void typeCentre(String text) {
    state = state.copyWith(centreQuery: text, centre: () => null);
    unawaited(_check());
  }

  /// A known centre, or the one « Ajouter « … » » offers, is picked.
  void chooseCentre(RescueCentre centre) {
    state = state.copyWith(centreQuery: centre.name, centre: () => centre);
    unawaited(_check());
  }

  /// « N° de tournée » changed to [text].
  void typeNumber(String text) {
    final number = TourneeNumber.parse(text);
    state = state.copyWith(
      number: () => _valueOf(number),
      numberInvalid: text.trim().isNotEmpty && number is Err,
    );
    unawaited(_check());
  }

  /// « Année » changed to [text].
  void typeYear(String text) {
    final year = CampaignYear.parse(text);
    state = state.copyWith(
      year: () => _valueOf(year),
      yearInvalid: text.trim().isNotEmpty && year is Err,
    );
  }

  /// Asks, after a pause in the typing, whether the number exists in the
  /// picked centre.
  Future<void> _check() async {
    final check = ++_checks;
    final (centre, number) = (state.centre, state.number);
    state = state.copyWith(duplicate: DuplicateCheck.unknown);
    if (centre == null || number == null || !state.signedIn) return;
    await Future<void>.delayed(ref.read(duplicateCheckDelayProvider));
    if (!ref.mounted || check != _checks) return;
    final taken = await ref.read(checkTourneeTakenProvider)(centre, number);
    if (!ref.mounted || check != _checks) return;
    state = state.copyWith(
      duplicate: switch (taken) {
        Ok(value: true) => DuplicateCheck.taken,
        Ok(value: false) => DuplicateCheck.free,
        // Not known: « Créer » still asks the server, which refuses a
        // duplicate.
        Err() => DuplicateCheck.unknown,
      },
    );
  }

  /// « Créer »: creates the tournée and opens it on the phone; the screen
  /// then shows its code. A number taken meanwhile shows as taken.
  Future<void> create() async {
    final name = ref.read(readPhoneSettingsProvider)().name;
    if (!state.canCreate || name == null) return;
    // An answer to a check started before must not overwrite this one's.
    _checks++;
    final (centre, number, year) = (state.centre!, state.number!, state.year!);
    state = state.copyWith(run: const CreateInProgress());
    final created = await ref.read(createTourneeProvider)(
      centre: centre,
      number: number,
      campaign: year,
      creatorName: name,
    );
    if (!ref.mounted) return;
    state = switch (created) {
      Ok(:final value) => state.copyWith(run: TourneeCreated.of(value)),
      Err(failure: CreateTourneeFailure.alreadyExists) => state.copyWith(
        run: const CreateIdle(),
        duplicate: DuplicateCheck.taken,
      ),
      Err(failure: CreateTourneeFailure.noNetwork) => state.copyWith(
        run: const CreateOffline(),
      ),
      Err(failure: CreateTourneeFailure.notAdmin) => state.copyWith(
        run: const CreateNotAdmin(),
      ),
    };
  }
}

/// The value of [result], or null when it failed.
T? _valueOf<T, F>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err() => null,
};
