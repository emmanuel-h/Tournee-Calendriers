import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/application/use_cases/phone_settings.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/settings/settings_state.dart';

/// The member's settings for the whole app. Not `autoDispose`: the app's
/// root draws every screen in the chosen theme.
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

/// Shows and changes the settings of Paramètres (PLAN §5.9, §5.16): the
/// member's first name, which also reaches the team of each of the
/// member's tournées where it is free, the name they go by in each, and
/// the theme. The theme works offline; a name needs the network once the
/// member is in a secteur.
final class SettingsNotifier extends Notifier<SettingsState> {
  /// « Mes secteurs » as last heard, for the names per secteur.
  MySectors _mine = MySectors.none;

  @override
  SettingsState build() {
    // A record pattern: names the two fields of the record the use case
    // returns.
    final (:name, :theme) = ref.watch(readPhoneSettingsProvider)();
    _mine = ref.watch(readMySectorsProvider)();
    // `listen` on the stream, not `watch`: a new list of tournées redraws
    // the names, without reading the settings again.
    final changes = ref.watch(observeMySectorsProvider)().listen((mine) {
      _mine = mine;
      state = _shown(state.name, state.theme);
    });
    ref.onDispose(changes.cancel);
    return _shown(name?.text, _shownTheme(theme));
  }

  /// « Prénom »: keeps [text] as the member's name once cleaned, and gives
  /// it to them in their tournées where it is free. Says how it went.
  Future<NameOutcome> rename(String text) async {
    switch (await ref.read(changeMemberNameProvider)(text)) {
      case Ok(:final value):
        state = _shown(value.name.text, state.theme);
        if (value.kept.isEmpty) return const NameSaved();
        return NameKeptIn([
          for (final kept in value.kept)
            _line(kept.sector, name: kept.name.text),
        ]);
      case Err(:final failure):
        return _outcomeOf(failure);
    }
  }

  /// « Votre nom dans le secteur 49 »: the member goes by [text] in the
  /// tournée [sector] only (#148).
  Future<NameOutcome> renameIn(SectorId sector, String text) async =>
      switch (await ref.read(changeSectorNameProvider)(sector, text)) {
        Ok() => const NameSaved(),
        Err(:final failure) => _outcomeOf(failure),
      };

  /// « Thème »: the app redraws in [theme] at once, then keeps it.
  Future<void> chooseTheme(AppTheme theme) {
    state = _shown(state.name, theme);
    return ref.read(chooseThemeProvider)(switch (theme) {
      AppTheme.system => ThemeChoice.system,
      AppTheme.light => ThemeChoice.light,
      AppTheme.dark => ThemeChoice.dark,
    });
  }

  SettingsState _shown(String? name, AppTheme theme) => SettingsState(
    name: name,
    theme: theme,
    sectorNames: [
      for (final sector in _mine.sectors)
        // An admin's visit holds no name of theirs.
        if (!sector.isVisiting)
          _line(sector, name: sector.memberName?.text ?? name),
    ],
  );

  static SectorNameLine _line(SectorSummary sector, {required String? name}) =>
      SectorNameLine(
        id: sector.id,
        number: sector.number.value,
        centre: sector.centre.name,
        name: name,
      );

  static NameOutcome _outcomeOf(RenameFailure failure) => switch (failure) {
    NameRefused(:final reason) => NameNotValid(reason),
    RenameProblem.noNetwork => const NameOffline(),
    RenameProblem.nameTaken => const NameTakenThere(),
    RenameProblem.sectorGone => const NameSectorGone(),
  };

  static AppTheme _shownTheme(ThemeChoice theme) => switch (theme) {
    ThemeChoice.system => AppTheme.system,
    ThemeChoice.light => AppTheme.light,
    ThemeChoice.dark => AppTheme.dark,
  };
}
