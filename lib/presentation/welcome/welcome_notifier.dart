import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
import 'package:tournee_calendriers/presentation/welcome/welcome_state.dart';

/// « Bienvenue ». `autoDispose`: each visit starts from the name kept.
final welcomeProvider =
    NotifierProvider.autoDispose<WelcomeNotifier, WelcomeState>(
      WelcomeNotifier.new,
    );

/// The first-launch screen (PLAN §5.1): the member's first name, then
/// « Créer » or « Rejoindre ». Both wait for a valid name, which is kept on
/// the phone before either opens (Paramètres → Prénom shows it after).
final class WelcomeNotifier extends Notifier<WelcomeState> {
  @override
  WelcomeState build() => _stateOf(ref.read(settingsProvider).name ?? '');

  /// « Votre prénom » changed to [text].
  void type(String text) => state = _stateOf(text);

  /// « Créer une tournée » or « Rejoindre une tournée »: keeps the name.
  /// True once kept; false when the name is not valid.
  Future<bool> confirm() async {
    if (!state.canGoOn) return false;
    // Through Paramètres' notifier, so the name it shows is this one.
    return await ref.read(settingsProvider.notifier).rename(state.name) == null;
  }

  static WelcomeState _stateOf(String text) =>
      switch (MemberName.create(text)) {
        Ok() => WelcomeState(name: text, canGoOn: true, tooLong: false),
        Err(:final failure) => WelcomeState(
          name: text,
          canGoOn: false,
          tooLong: failure == MemberNameFailure.tooLong,
        ),
      };
}
