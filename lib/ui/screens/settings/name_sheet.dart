import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
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

/// « Votre prénom » and « Enregistrer ». A name refused (blank, too long)
/// is said under the field until the next edit; the sheet closes once the
/// name is kept.
final class NameSheet extends ConsumerStatefulWidget {
  const NameSheet({super.key});

  @override
  ConsumerState<NameSheet> createState() => _NameSheetState();
}

/// A `State`: the sheet keeps the text typed and why it was refused.
final class _NameSheetState extends ConsumerState<NameSheet> {
  // `ref.read` in a field initialiser: the sheet starts from the name kept
  // now; it does not follow later changes while the member types.
  late final _field = TextEditingController(
    text: ref.read(settingsProvider).name ?? '',
  );

  /// Why the last « Enregistrer » was refused; cleared by the next edit.
  String? _refusal;

  @override
  void dispose() {
    _field.dispose();
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
          // `liveRegion`: TalkBack reads the refusal as soon as it shows.
          Semantics(
            liveRegion: true,
            child: Text(
              refusal,
              key: const Key('name.refusal'),
              style: AppTextStyles.small.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        PrimaryButton(
          key: const Key('name.save'),
          label: l10n.nameSave,
          compact: true,
          onPressed: () => unawaited(_save()),
        ),
      ],
    );
  }

  /// « Enregistrer »: closes the sheet once the name is kept; otherwise
  /// says why.
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final refusal = await ref
        .read(settingsProvider.notifier)
        .rename(_field.text);
    if (!mounted) return;
    switch (refusal) {
      case null:
        Navigator.of(context).pop();
      case MemberNameFailure.blank:
        setState(() => _refusal = l10n.nameBlank);
      case MemberNameFailure.tooLong:
        setState(() => _refusal = l10n.nameTooLong(MemberName.maxLength));
    }
  }
}
