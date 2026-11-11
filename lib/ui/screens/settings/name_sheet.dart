import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
import 'package:tournee_calendriers/presentation/settings/settings_state.dart';
import 'package:tournee_calendriers/ui/components/alert_box.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/keep_focus.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Opens the sheet that changes the member's first name (Paramètres →
/// Prénom, PLAN §5.9).
Future<void> showNameSheet(BuildContext context) => showAppBottomSheet<void>(
  context: context,
  builder: (_) => const NameSheet(),
);

/// « Votre prénom » and « Enregistrer ». A name refused (blank, too long,
/// no network) is said under the field until the next edit; the sheet
/// closes once the name is kept.
///
/// Where a secteur's member already holds the new prénom (#148, PLAN
/// §5.16, SettingsNameTaken mockup), the sheet stays open: « « Paul » est
/// déjà pris dans le secteur 49 : vous y gardez « Paul D. ». Il est
/// enregistré partout ailleurs. », with a field « Votre nom dans le
/// secteur 49 » per such secteur, which « Enregistrer » then gives there.
final class NameSheet extends ConsumerStatefulWidget {
  const NameSheet({super.key});

  @override
  ConsumerState<NameSheet> createState() => _NameSheetState();
}

/// A `State`: the sheet keeps the text typed, why it was refused, and the
/// secteurs where the old name was kept.
final class _NameSheetState extends ConsumerState<NameSheet> {
  // `ref.read` in a field initialiser: the sheet starts from the name kept
  // now; it does not follow later changes while the member types.
  late final _field = TextEditingController(
    text: ref.read(settingsProvider).name ?? '',
  );

  /// Why the last « Enregistrer » was refused; cleared by the next edit.
  String? _refusal;

  /// The secteurs where the prénom was taken, with the name kept there, in
  /// order; empty until then.
  var _kept = <SectorNameLine>[];

  /// The prénom those secteurs refused: « « Paul » est déjà pris… ».
  String _takenName = '';

  /// The field of each secteur of [_kept], and why its name was refused.
  final _sectorFields = <SectorId, TextEditingController>{};
  final _sectorProblems = <SectorId, String>{};

  @override
  void dispose() {
    _field.dispose();
    for (final field in _sectorFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return SheetScaffold(
      title: l10n.settingsName,
      spacing: 14,
      children: [
        // `MergeSemantics`: TalkBack names the field « Votre prénom ».
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text(
                l10n.nameFieldLabel,
                style: AppTextStyles.fieldLabel.copyWith(color: colors.ink),
              ),
              TextField(
                key: const Key('name.field'),
                controller: _field,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                style: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
                onChanged: (_) {
                  if (_refusal != null) setState(() => _refusal = null);
                },
                onEditingComplete: keepFocusOnSubmit,
                onSubmitted: (_) => unawaited(_save()),
              ),
            ],
          ),
        ),
        if (_refusal case final refusal?)
          _Problem(key: const Key('name.refusal'), text: refusal),
        if (_kept.isNotEmpty)
          AlertBox(
            key: const Key('name.kept'),
            body: [
              for (final kept in _kept)
                l10n.nameKeptIn(_takenName, '${kept.number}', kept.name ?? ''),
              l10n.nameKeptElsewhere,
            ].join(' '),
          ),
        for (final kept in _kept) ...[
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Text(
                  l10n.nameSectorFieldLabel('${kept.number}'),
                  style: AppTextStyles.fieldLabel.copyWith(color: colors.ink),
                ),
                TextField(
                  key: ValueKey('name.sector.${kept.id.value}'),
                  controller: _sectorFields[kept.id],
                  textCapitalization: TextCapitalization.words,
                  style: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
                  onChanged: (_) {
                    if (_sectorProblems.containsKey(kept.id)) {
                      setState(() => _sectorProblems.remove(kept.id));
                    }
                  },
                ),
              ],
            ),
          ),
          if (_sectorProblems[kept.id] case final problem?)
            _Problem(
              key: ValueKey('name.sector.${kept.id.value}.problem'),
              text: problem,
            ),
        ],
        PrimaryButton(
          key: const Key('name.save'),
          label: l10n.nameSave,
          compact: true,
          onPressed: () => unawaited(_save()),
        ),
      ],
    );
  }

  /// « Enregistrer »: gives the prénom typed, or, once it was taken in some
  /// secteurs and left as it is, the name typed for each of them. Closes
  /// the sheet once nothing is left to say.
  Future<void> _save() async {
    final kept = ref.read(settingsProvider).name;
    if (_kept.isEmpty || _field.text.trim() != kept) {
      await _savePrenom();
    } else {
      await _saveSectorNames();
    }
  }

  Future<void> _savePrenom() async {
    final l10n = AppLocalizations.of(context);
    final outcome = await ref
        .read(settingsProvider.notifier)
        .rename(_field.text);
    if (!mounted) return;
    switch (outcome) {
      case NameKeptIn(:final kept):
        setState(() {
          _refusal = null;
          _takenName = ref.read(settingsProvider).name ?? '';
          _kept = kept;
          _sectorProblems.clear();
          for (final line in kept) {
            (_sectorFields[line.id] ??= TextEditingController()).text =
                line.name ?? '';
          }
        });
      case NameNotValid(:final reason):
        setState(() => _refusal = _refusalOf(l10n, reason));
      case NameOffline():
        setState(() => _refusal = l10n.nameOffline);
      // A prénom is never refused for one secteur: these are
      // `renameIn`'s.
      case NameSaved() || NameTakenThere() || NameSectorGone():
        Navigator.of(context).pop();
    }
  }

  Future<void> _saveSectorNames() async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(settingsProvider.notifier);
    final left = <SectorNameLine>[];
    final problems = <SectorId, String>{};
    for (final line in _kept) {
      final typed = _sectorFields[line.id]!.text;
      // Left as it was: the member keeps that name there.
      if (typed.trim() == line.name) continue;
      final String problem;
      switch (await notifier.renameIn(line.id, typed)) {
        case NameSaved() || NameKeptIn() || NameSectorGone():
          continue;
        case NameNotValid(:final reason):
          problem = _refusalOf(l10n, reason);
        case NameTakenThere():
          problem = l10n.nameTakenThere(typed.trim(), '${line.number}');
        case NameOffline():
          problem = l10n.nameOffline;
      }
      left.add(line);
      problems[line.id] = problem;
    }
    if (!mounted) return;
    if (left.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _kept = left;
      _sectorProblems
        ..clear()
        ..addAll(problems);
    });
  }

  static String _refusalOf(AppLocalizations l10n, MemberNameFailure reason) =>
      switch (reason) {
        MemberNameFailure.blank => l10n.nameBlank,
        MemberNameFailure.tooLong => l10n.nameTooLong(MemberName.maxLength),
      };
}

/// Why a name typed was refused, under its field, in red; read out as soon
/// as it shows.
final class _Problem extends StatelessWidget {
  const _Problem({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    // `liveRegion`: TalkBack reads the refusal as soon as it shows.
    liveRegion: true,
    child: Text(
      text,
      style: AppTextStyles.small.copyWith(
        color: AppColors.of(context).accent,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
