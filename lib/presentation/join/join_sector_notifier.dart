import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/sector_directory.dart';
import 'package:tournee_calendriers/application/use_cases/join_sector.dart';
import 'package:tournee_calendriers/domain/sector/join_code.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/presentation/account/account_notifier.dart';
import 'package:tournee_calendriers/presentation/account/account_state.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/join/join_sector_state.dart';

/// « Rejoindre un secteur ». `autoDispose`: each visit starts afresh.
final joinSectorProvider =
    NotifierProvider.autoDispose<JoinSectorNotifier, JoinSectorState>(
      JoinSectorNotifier.new,
    );

/// « Rejoindre un secteur » (PLAN §5.2): the code typed in two boxes of
/// three characters or scanned, the tournée it shows, then « Demander à
/// rejoindre », which sends the request and leaves the screen to « Demande
/// envoyée ».
///
/// The server is asked only once the phone has its account
/// (`accountProvider`).
final class JoinSectorNotifier extends Notifier<JoinSectorState> {
  /// The characters of a box: half a code.
  static const _half = JoinCode.length ~/ 2;

  /// What a person may type around a code and that carries no meaning.
  static final _ignored = RegExp(r'[\s-]');

  /// The complete, valid code typed; null otherwise.
  JoinCode? _code;

  /// The tournée [_code] shows, once the server said so.
  JoinPreview? _preview;

  /// Raised by each code typed: an answer about an older code is dropped.
  var _lookups = 0;

  @override
  JoinSectorState build() {
    ref.listen(accountProvider, (_, account) => _follow(account));
    return JoinSectorState(
      signedIn: ref.read(accountProvider) is AccountSignedIn,
      defaultName: ref.read(readPhoneSettingsProvider)().name?.text,
      first: '',
      second: '',
      invalidCharacter: false,
      scanRefused: false,
      lookup: const NoLookup(),
      run: const JoinIdle(),
    );
  }

  void _follow(AccountState account) {
    final signedIn = account is AccountSignedIn;
    if (signedIn == state.signedIn) return;
    state = state.copyWith(signedIn: signedIn);
    if (_code case final code? when signedIn) unawaited(_lookUp(code));
  }

  /// The first box changed to [text]. A whole code typed or pasted there
  /// (« K7P-2QX ») fills both boxes.
  void typeFirstHalf(String text) {
    final typed = _cleaned(text);
    if (typed.length <= _half) return _typed(typed, state.second);
    _typed(typed.substring(0, _half), _cut(typed.substring(_half)));
  }

  /// The second box changed to [text].
  void typeSecondHalf(String text) => _typed(state.first, _cut(_cleaned(text)));

  /// The camera read [text] from a QR code: a tournée's holds its code
  /// alone (PLAN §5.2); anything else is refused.
  void scanned(String text) {
    switch (JoinCode.parse(text)) {
      case Ok(:final value):
        _typed(value.value.substring(0, _half), value.value.substring(_half));
      case Err():
        state = state.copyWith(scanRefused: true);
    }
  }

  /// « Réessayer » after the server could not be reached.
  Future<void> retryLookup() async {
    if (_code case final code? when state.lookup is LookupOffline) {
      await _lookUp(code);
    }
  }

  /// Upper case, without the dash and the spaces.
  static String _cleaned(String text) =>
      text.replaceAll(_ignored, '').toUpperCase();

  /// At most a box's worth: what is typed past it is dropped.
  static String _cut(String text) =>
      text.length <= _half ? text : text.substring(0, _half);

  void _typed(String first, String second) {
    if (first == state.first && second == state.second) return;
    _lookups++;
    _preview = null;
    final code = JoinCode.parse('$first$second');
    _code = switch (code) {
      Ok(:final value) => value,
      Err() => null,
    };
    state = state.copyWith(
      first: first,
      second: second,
      // An incomplete code is no mistake yet; a character no code has is.
      invalidCharacter: switch (code) {
        Err(failure: JoinCodeFailure.invalidCharacter) => true,
        Ok() || Err() => false,
      },
      scanRefused: false,
      lookup: const NoLookup(),
      run: const JoinIdle(),
      // Another secteur: the prénom may be free there.
      keepNameTaken: false,
    );
    if (_code case final code? when state.signedIn) unawaited(_lookUp(code));
  }

  Future<void> _lookUp(JoinCode code) async {
    final lookup = ++_lookups;
    state = state.copyWith(lookup: const LookingUp());
    final found = await ref.read(previewJoinProvider)(code);
    if (!ref.mounted || lookup != _lookups) return;
    _preview = switch (found) {
      Ok(:final value) => value,
      Err() => null,
    };
    state = state.copyWith(
      lookup: switch (found) {
        Ok(:final value) => SectorFound.of(value),
        Err(failure: JoinFailure.unknownCode) => const CodeUnknown(),
        Err(failure: JoinFailure.noNetwork) => const LookupOffline(),
      },
    );
  }

  /// « Votre nom dans ce secteur » changed to [text] (#148).
  void typeSectorName(String text) {
    if (state.nameTaken case final taken?) {
      state = state.copyWith(
        nameTaken: JoinNameTaken(taken: taken.taken, typed: text),
      );
    }
  }

  /// « Demander à rejoindre »: sends the request under the phone's prénom,
  /// or under the name typed for this secteur once the prénom was taken
  /// there (#148); once sent, the screen leaves for « Demande envoyée ».
  Future<void> request() async {
    final preview = _preview;
    final prenom = ref.read(readPhoneSettingsProvider)().name;
    if (!state.canRequest || preview == null || prenom == null) return;
    var name = prenom;
    if (state.nameTaken case final taken?) {
      switch (MemberName.create(taken.typed)) {
        case Ok(:final value):
          name = value;
        case Err(:final failure):
          state = state.copyWith(
            nameTaken: JoinNameTaken(
              taken: taken.taken,
              typed: taken.typed,
              problem: failure,
            ),
          );
          return;
      }
    }
    state = state.copyWith(run: const JoinSending());
    final sent = await ref.read(requestToJoinProvider)(preview, name);
    if (!ref.mounted) return;
    switch (sent) {
      case Ok(:final value):
        state = state.copyWith(run: JoinSent(value.id));
      case Err(failure: RequestToJoinFailure.alreadyJoined):
        state = state.copyWith(run: const JoinAlreadyJoined());
      case Err(failure: RequestToJoinFailure.noNetwork):
        state = state.copyWith(run: const JoinOffline());
      case Err(failure: RequestToJoinFailure.nameTaken):
        state = state.copyWith(
          run: const JoinIdle(),
          nameTaken: JoinNameTaken(
            taken: name.text,
            typed: state.nameTaken?.typed ?? name.text,
          ),
        );
      case Err(failure: RequestToJoinFailure.unknownCode):
        // The code stopped working since it showed the secteur: said as
        // for a code that never did.
        _preview = null;
        state = state.copyWith(
          run: const JoinIdle(),
          lookup: const CodeUnknown(),
          keepNameTaken: false,
        );
    }
  }
}
