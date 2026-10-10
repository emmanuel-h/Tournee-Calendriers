/// The themes Paramètres offers (PLAN §5.9). The screens' own copy of the
/// application's `ThemeChoice`: `ui/` may not name the application layer.
enum AppTheme {
  /// « Système »: light or dark as the phone is set.
  system,

  /// « Clair ».
  light,

  /// « Sombre ».
  dark,
}

/// What Paramètres shows of the member's settings (PLAN §5.9), and the
/// theme the whole app is drawn in. Immutable: the notifier replaces it.
final class SettingsState {
  const SettingsState({required this.name, required this.theme});

  /// The member's first name; null until they give one.
  final String? name;
  final AppTheme theme;

  @override
  bool operator ==(Object other) =>
      other is SettingsState && other.name == name && other.theme == theme;

  @override
  int get hashCode => Object.hash(name, theme);
}
