import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/settings/settings_state.dart';

/// The member's settings for the whole app. Not `autoDispose`: the app's
/// root draws every screen in the chosen theme.
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

/// Shows and changes the settings of Paramètres (PLAN §5.9): the member's
/// first name and the theme. On the phone only, offline always.
final class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // A record pattern: names the two fields of the record the use case
    // returns.
    final (:name, :theme) = ref.watch(readPhoneSettingsProvider)();
    return SettingsState(name: name?.text, theme: _shown(theme));
  }

  /// « Prénom »: keeps [text] as the member's name once cleaned. Returns
  /// why it is refused, or null once it is kept.
  Future<MemberNameFailure?> rename(String text) async {
    switch (await ref.read(changeMemberNameProvider)(text)) {
      case Ok(:final value):
        state = SettingsState(name: value.text, theme: state.theme);
        return null;
      case Err(:final failure):
        return failure;
    }
  }

  /// « Thème »: the app redraws in [theme] at once, then keeps it.
  Future<void> chooseTheme(AppTheme theme) {
    state = SettingsState(name: state.name, theme: theme);
    return ref.read(chooseThemeProvider)(switch (theme) {
      AppTheme.system => ThemeChoice.system,
      AppTheme.light => ThemeChoice.light,
      AppTheme.dark => ThemeChoice.dark,
    });
  }

  static AppTheme _shown(ThemeChoice theme) => switch (theme) {
    ThemeChoice.system => AppTheme.system,
    ThemeChoice.light => AppTheme.light,
    ThemeChoice.dark => AppTheme.dark,
  };
}
