import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// [spoken], the spoken status of a tile or a door, with the tries it
/// shows (« ×3 », #80): « personne, 3e passage » while nobody is home
/// ([nobodyHome]), « fait, 2 passages sans personne » on another status;
/// [spoken] alone when it shows none ([tries] null).
String spokenWithTries(
  AppLocalizations l10n,
  String spoken, {
  required bool nobodyHome,
  required int? tries,
}) => switch (tries) {
  null => spoken,
  final count when nobodyHome => '$spoken, ${l10n.tileTriesNobodyHome(count)}',
  final count => '$spoken, ${l10n.nobodyHomeTries(count)}',
};
