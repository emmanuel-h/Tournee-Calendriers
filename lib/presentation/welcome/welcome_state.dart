/// What « Bienvenue » shows (PLAN §5.1): the name typed and whether it may
/// go on. Immutable: the notifier replaces it.
final class WelcomeState {
  const WelcomeState({
    required this.name,
    required this.canGoOn,
    required this.tooLong,
  });

  /// The text of « Votre prénom », as typed.
  final String name;

  /// « Créer une tournée » and « Rejoindre une tournée » are enabled: the
  /// text is a valid first name.
  final bool canGoOn;

  /// The name is longer than `MemberName.maxLength`: said under the field.
  /// A blank one only keeps the buttons disabled.
  final bool tooLong;

  @override
  bool operator ==(Object other) =>
      other is WelcomeState &&
      other.name == name &&
      other.canGoOn == canGoOn &&
      other.tooLong == tooLong;

  @override
  int get hashCode => Object.hash(name, canGoOn, tooLong);

  @override
  String toString() => 'WelcomeState($name, $canGoOn, $tooLong)';
}
