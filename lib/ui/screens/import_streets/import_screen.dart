import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_notifier.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/filter_field.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_messages.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Importer des rues » (PLAN §5.0, `docs/mockups/Import.dc.html`), the
/// screen of a phone with no tournée open: type a commune, choose it among
/// the suggestions, tick its streets, import them. Needs the network.
final class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    // The mockup puts the title right after the back arrow.
    appBar: AppBar(
      title: Text(AppLocalizations.of(context).importStreetsAction),
      titleSpacing: 0,
    ),
    body: const SafeArea(child: ImportList()),
  );
}

/// The import checklist, shown by « Importer des rues » and by the
/// « Liste » tab of « Ajouter des rues » (PLAN §5.4, AddList mockup).
///
/// With a tournée open that has communes, there is no commune field: a
/// chip per commune when there are several, the streets of the one chosen,
/// « déjà dans la tournée » and « Ajouter N rues ». Otherwise the commune
/// is searched as in M1. Once every street ticked is stored, the screen
/// closes with a message.
///
/// A `ConsumerStatefulWidget`: like a `StatefulWidget`, plus `ref`. The
/// state object owns the commune field's `TextEditingController`, which
/// must live as long as the list.
final class ImportList extends ConsumerStatefulWidget {
  const ImportList({super.key});

  @override
  ConsumerState<ImportList> createState() => _ImportListState();
}

final class _ImportListState extends ConsumerState<ImportList> {
  final _commune = TextEditingController();

  @override
  void dispose() {
    _commune.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(importProvider);
    final notifier = ref.read(importProvider.notifier);

    // `ref.listen` runs a side effect on a change instead of redrawing:
    // here, going back to the list once every chosen street is imported.
    ref.listen(importProvider.select((state) => state.run), (_, run) {
      if (run case ImportFinished(:final summary) when summary.complete) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              importDoneMessage(l10n, summary, inTournee: state.inTournee),
            ),
          ),
        );
        context.pop();
      }
    });
    // The notifier writes the chosen commune's label in the field.
    if (_commune.text != state.query) _commune.text = state.query;
    final communes = state.tourneeCommunes;

    return PopScope(
      // No way back while streets are being written.
      canPop: !state.importing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (communes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
              child: _CommuneField(
                controller: _commune,
                state: state,
                onChanged: (text) => unawaited(notifier.typeCommune(text)),
              ),
            )
          else if (communes.length > 1)
            _CommuneChoice(state: state),
          Expanded(
            child: state.commune == null
                ? _Suggestions(state: state)
                : _Streets(state: state),
          ),
        ],
      ),
    );
  }
}

/// A chip per commune of the tournée, the chosen one in ink (AddList
/// mockup); screen readers hear radio buttons named « Commune ».
final class _CommuneChoice extends ConsumerWidget {
  const _CommuneChoice({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final chosen = state.commune?.inseeCode;
    return Semantics(
      container: true,
      label: l10n.communeLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final commune in state.tourneeCommunes)
              if (commune.inseeCode == chosen)
                _CommunePill(
                  key: ValueKey('import.commune.${commune.inseeCode.value}'),
                  name: commune.name,
                  selected: true,
                  background: colors.ink,
                  foreground: colors.surface,
                  onTap: null,
                )
              else
                _CommunePill(
                  key: ValueKey('import.commune.${commune.inseeCode.value}'),
                  name: commune.name,
                  selected: false,
                  background: colors.surface,
                  foreground: colors.ink,
                  onTap: state.importing
                      ? null
                      : () => unawaited(
                          ref
                              .read(importProvider.notifier)
                              .chooseCommune(commune, label: commune.name),
                        ),
                ),
          ],
        ),
      ),
    );
  }
}

/// One commune of [_CommuneChoice]: a pill of 48 dp at least.
final class _CommunePill extends StatelessWidget {
  const _CommunePill({
    super.key,
    required this.name,
    required this.selected,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    button: true,
    label: name,
    excludeSemantics: true,
    child: Material(
      color: background,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? background : AppColors.of(context).line,
          width: AppSizes.borderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: AppTextStyles.pill.copyWith(color: foreground)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// « Commune » and its field, darker once a commune is chosen.
final class _CommuneField extends StatelessWidget {
  const _CommuneField({
    required this.controller,
    required this.state,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ImportState state;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final chosen = state.commune != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          l10n.communeLabel,
          style: AppTextStyles.fieldLabel.copyWith(color: colors.ink),
        ),
        TextField(
          key: const Key('import.commune'),
          controller: controller,
          onChanged: onChanged,
          enabled: !state.importing,
          style: AppTextStyles.bodyLarge,
          textCapitalization: TextCapitalization.words,
          // Typing a commune is the first thing to do here.
          autofocus: !chosen,
          decoration: InputDecoration(
            hintText: l10n.communeHint,
            // Chosen: the ink outline of the mockup, focused or not.
            enabledBorder: chosen
                ? OutlineInputBorder(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppSizes.fieldRadius),
                    ),
                    borderSide: BorderSide(
                      color: colors.ink,
                      width: AppSizes.borderWidth,
                    ),
                  )
                : null,
            suffixIcon: state.searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// What shows under the field while no commune is chosen.
final class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (state.suggestions) {
      NoSuggestions() => const SizedBox.shrink(),
      CommuneSearchFailed(:final failure) => _Message(
        communeSearchFailureMessage(l10n, failure),
      ),
      CommunesFound(:final communes) when communes.isEmpty => _Message(
        l10n.communeNoneFound,
      ),
      CommunesFound(:final communes) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          8,
          AppSizes.gutter,
          AppSizes.gutter,
        ),
        children: [
          for (final match in communes)
            _Row(
              key: ValueKey('import.suggestion.${match.inseeCode.value}'),
              onTap: () {
                // Close the keyboard: the checklist needs the room.
                FocusManager.instance.primaryFocus?.unfocus();
                unawaited(
                  ref
                      .read(importProvider.notifier)
                      .chooseCommune(match, label: communeLabel(l10n, match)),
                );
              },
              child: Text(
                communeLabel(l10n, match),
                style: AppTextStyles.bodyLarge,
              ),
            ),
        ],
      ),
    };
  }
}

/// The streets of the chosen commune: loading, failed or the checklist.
final class _Streets extends ConsumerWidget {
  const _Streets({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(importProvider.notifier);
    return switch (state.streets) {
      NoCommuneChosen() => const SizedBox.shrink(),
      LoadingStreets() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            const CircularProgressIndicator(),
            Text(l10n.streetsLoading),
          ],
        ),
      ),
      StreetsFailed(:final failure) => _Message(
        addressFailureMessage(l10n, failure),
        action: SecondaryButton(
          key: const Key('import.retry'),
          label: l10n.retry,
          onPressed: () => unawaited(notifier.retryStreets()),
        ),
      ),
      StreetsLoaded() => _Checklist(state: state),
    };
  }
}

/// « 312 rues · 1 cochée » [Tout cocher], the filter, the rows, the footer.
final class _Checklist extends ConsumerWidget {
  const _Checklist({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final notifier = ref.read(importProvider.notifier);
    final visible = state.visibleStreets;
    final allChecked = state.allVisibleChecked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            14,
            AppSizes.gutter,
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: SectionHeader(
                  l10n.importStreetCount(state.streetCount, state.checkedCount),
                  padding: EdgeInsets.zero,
                ),
              ),
              OutlinedButton(
                key: const Key('import.checkAll'),
                onPressed: state.importing
                    ? null
                    : () => notifier.checkAllVisible(checked: !allChecked),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(
                    Size(0, AppSizes.pillHeight),
                  ),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 14),
                  ),
                  textStyle: WidgetStatePropertyAll(AppTextStyles.pill),
                ),
                child: Text(allChecked ? l10n.uncheckAll : l10n.checkAll),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            0,
            AppSizes.gutter,
            6,
          ),
          child: FilterField(
            key: const Key('import.filter'),
            onChanged: notifier.filter,
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? _Message(l10n.filterNoMatch(state.filter.trim()))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.gutter,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) => _ChoiceRow(
                    street: visible[index],
                    inTournee: state.inTournee,
                    enabled: !state.importing,
                    onToggle: notifier.toggle,
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            12,
            AppSizes.gutter,
            AppSizes.gutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              ..._outcome(l10n, colors),
              if (state.run case ImportRunning(:final done, :final total))
                _Progress(done: done, total: total, inTournee: state.inTournee)
              else
                PrimaryButton(
                  key: const Key('import.button'),
                  label: state.inTournee
                      ? l10n.addButton(state.checkedCount)
                      : l10n.importButton(state.checkedCount),
                  onPressed: state.canImport
                      ? () => unawaited(notifier.import())
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// What went wrong with the last import, if anything.
  List<Widget> _outcome(AppLocalizations l10n, AppColors colors) {
    final message = switch (state.run) {
      ImportFailed(:final failure) => addressFailureMessage(l10n, failure),
      ImportFinished(:final summary) when !summary.complete =>
        importPartialMessage(l10n, summary, inTournee: state.inTournee),
      ImportNotStarted() || ImportRunning() || ImportFinished() => null,
    };
    return [
      if (message != null)
        Text(
          message,
          key: const Key('import.outcome'),
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: colors.accent),
        ),
    ];
  }
}

/// One street of the checklist: « ☑ Rue Nationale  403 n° », greyed and
/// « déjà importée », or « dans la Corbeille ».
final class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.street,
    required this.inTournee,
    required this.enabled,
    required this.onToggle,
  });

  final StreetChoice street;

  /// « déjà dans la tournée » rather than « déjà importée ».
  final bool inTournee;
  final bool enabled;
  final ValueChanged<BanStreetId> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textColor = street.alreadyImported ? colors.muted : colors.ink;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      // A `CheckboxListTile` is one tap target of 56 dp at least, and tells
      // screen readers « case cochée / non cochée » with the title.
      child: CheckboxListTile(
        key: ValueKey('import.street.${street.id.value}'),
        value: street.checked,
        onChanged: enabled && street.selectable
            ? (_) => onToggle(street.id)
            : null,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        horizontalTitleGap: 12,
        title: Text(
          street.name,
          style: AppTextStyles.bodyLarge.copyWith(color: textColor),
        ),
        secondary: Text(
          street.alreadyImported
              ? (inTournee ? l10n.alreadyInTournee : l10n.alreadyImported)
              : street.inCorbeille
              ? l10n.inCorbeille
              : l10n.streetNumberCount(street.numberCount),
          style: AppTextStyles.small.copyWith(color: colors.muted),
        ),
      ),
    );
  }
}

/// A tappable row of at least 56 dp with a divider (a commune suggestion).
final class _Row extends StatelessWidget {
  const _Row({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: AppSizes.choiceRowHeight),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.of(context).divider),
        ),
      ),
      child: child,
    ),
  );
}

/// A centred message, with an optional button under it.
final class _Message extends StatelessWidget {
  const _Message(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSizes.gutter),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            color: AppColors.of(context).muted,
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// « Import en cours… 2/5 » over a bar, in place of the import button.
final class _Progress extends StatelessWidget {
  const _Progress({
    required this.done,
    required this.total,
    required this.inTournee,
  });

  final int done;
  final int total;

  /// « Ajout en cours… » rather than « Import en cours… ».
  final bool inTournee;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppSizes.buttonHeight,
    child: Column(
      key: const Key('import.progress'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          inTournee
              ? AppLocalizations.of(context).addProgress(done, total)
              : AppLocalizations.of(context).importProgress(done, total),
          textAlign: TextAlign.center,
          style: AppTextStyles.fieldLabel,
        ),
        LinearProgressIndicator(
          value: total == 0 ? null : done / total,
          minHeight: AppSizes.progressBarHeight,
        ),
      ],
    ),
  );
}
