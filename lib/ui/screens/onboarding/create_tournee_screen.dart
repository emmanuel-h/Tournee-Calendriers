import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/presentation/new_tournee/new_tournee_notifier.dart';
import 'package:tournee_calendriers/presentation/new_tournee/new_tournee_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/join_code_text.dart';
import 'package:tournee_calendriers/ui/components/join_qr_code.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/account_line.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/onboarding_parts.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Nouvelle tournée » (PLAN §5.2, Create and CreateTaken mockups): the
/// centre de secours picked from the known ones (or added), the number,
/// checked as it is typed, and the year; « Créer », then the code and its
/// QR code to show the team on the same screen, and « Continuer » to the
/// start screen, where the new tournée is open.
final class CreateTourneeScreen extends ConsumerStatefulWidget {
  const CreateTourneeScreen({super.key});

  @override
  ConsumerState<CreateTourneeScreen> createState() =>
      _CreateTourneeScreenState();
}

/// A `State`: the screen keeps its fields' controllers and focus.
final class _CreateTourneeScreenState
    extends ConsumerState<CreateTourneeScreen> {
  final _centre = TextEditingController();
  final _number = TextEditingController();
  late final _year = TextEditingController(
    text: ref.read(newTourneeProvider).initialYear,
  );

  /// The list of centres shows while the centre field has the focus.
  final _centreFocus = FocusNode();
  final _numberFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _centreFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _centre.dispose();
    _number.dispose();
    _year.dispose();
    _centreFocus.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  void _choose(RescueCentre centre) {
    _centre.text = centre.name;
    ref.read(newTourneeProvider.notifier).chooseCentre(centre);
    _numberFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(newTourneeProvider);
    final notifier = ref.read(newTourneeProvider.notifier);
    final created = switch (state.run) {
      final TourneeCreated created => created,
      _ => null,
    };
    final taken = state.duplicate == DuplicateCheck.taken && created == null;
    final showCentres =
        _centreFocus.hasFocus &&
        (state.suggestions.isNotEmpty || state.newCentre != null);
    // Once created, going back opens the start screen on the new tournée:
    // the screen it came from (« Bienvenue ») has nothing more to offer.
    return PopScope(
      canPop: created == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.screenCreate), titleSpacing: 4),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                sliver: SliverList.list(
                  children: [
                    const AccountLine(),
                    const SizedBox(height: 12),
                    FieldLabel(l10n.createCentreLabel),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('create.centre'),
                      controller: _centre,
                      focusNode: _centreFocus,
                      enabled: created == null,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: colors.ink,
                      ),
                      decoration: InputDecoration(
                        suffixIcon: Icon(
                          Icons.keyboard_arrow_down,
                          color: colors.muted,
                        ),
                      ),
                      onChanged: notifier.typeCentre,
                    ),
                    if (showCentres) ...[
                      const SizedBox(height: 6),
                      _CentreList(state: state, onChoose: _choose),
                    ],
                    if (state.centreTooLong) ...[
                      const SizedBox(height: 6),
                      FieldProblem(
                        l10n.createCentreTooLong(RescueCentre.maxLength),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        Expanded(
                          child: _NumberField(
                            fieldKey: const Key('create.number'),
                            label: l10n.createNumberLabel,
                            controller: _number,
                            focusNode: _numberFocus,
                            enabled: created == null,
                            framed: taken,
                            problem: state.numberInvalid
                                ? l10n.createNumberInvalid(TourneeNumber.max)
                                : null,
                            onChanged: notifier.typeNumber,
                          ),
                        ),
                        Expanded(
                          child: _NumberField(
                            fieldKey: const Key('create.year'),
                            label: l10n.createYearLabel,
                            controller: _year,
                            enabled: created == null,
                            problem: state.yearInvalid
                                ? l10n.createYearInvalid(
                                    CampaignYear.first,
                                    CampaignYear.last,
                                  )
                                : null,
                            onChanged: notifier.typeYear,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (taken) ...[
                      _TakenAlert(
                        title: l10n.createTakenTitle(
                          '${state.number?.value}',
                          state.centre?.name ?? '',
                        ),
                        body: l10n.createTakenBody,
                      ),
                      const SizedBox(height: 16),
                    ],
                    PrimaryButton(
                      key: const Key('create.create'),
                      label: l10n.createAction,
                      onPressed: state.canCreate
                          ? () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              unawaited(notifier.create());
                            }
                          : null,
                    ),
                    if (state.run is CreateOffline) ...[
                      const SizedBox(height: 12),
                      ScreenMessage(l10n.onboardingOffline),
                    ],
                    if (state.run is CreateNotAdmin) ...[
                      const SizedBox(height: 12),
                      ScreenMessage(
                        l10n.notAdminAnyMore,
                        key: const Key('create.notAdmin'),
                      ),
                    ],
                    if (taken) ...[
                      const SizedBox(height: 12),
                      SecondaryButton(
                        key: const Key('create.joinWithCode'),
                        label: l10n.createJoinWithCode,
                        strong: true,
                        onPressed: () =>
                            context.pushReplacement(AppRoutes.join),
                      ),
                    ],
                    if (created != null) ...[
                      const SizedBox(height: 24),
                      _CodeCard(created: created),
                    ],
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: created == null
                        ? const SizedBox.shrink()
                        : SecondaryButton(
                            key: const Key('create.continue'),
                            label: l10n.createContinue,
                            onPressed: () => context.go(AppRoutes.home),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The known centres the text names, and « + Ajouter « … » » at the
/// bottom for a station the app does not know yet.
final class _CentreList extends StatelessWidget {
  const _CentreList({required this.state, required this.onChoose});

  final NewTourneeState state;
  final ValueChanged<RescueCentre> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final newCentre = state.newCentre;
    final rows = [
      for (final centre in state.suggestions)
        _CentreRow(
          key: ValueKey('create.centre.${centre.key.value}'),
          label: centre.name,
          onTap: () => onChoose(centre),
        ),
      if (newCentre != null)
        _CentreRow(
          key: const Key('create.centre.add'),
          label: l10n.createCentreAdd(newCentre.name),
          icon: Icons.add,
          color: colors.accent,
          onTap: () => onChoose(newCentre),
        ),
    ];
    return Semantics(
      container: true,
      label: l10n.createCentreListSemantics,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
        ),
        child: Column(
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0) Divider(height: 1, color: colors.divider),
              row,
            ],
          ],
        ),
      ),
    );
  }
}

/// One centre of the list, or « + Ajouter « … » ».
final class _CentreRow extends StatelessWidget {
  const _CentreRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// The accent red for « Ajouter », the ink otherwise.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ink = color ?? colors.ink;
    final icon = this.icon;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSizes.optionRowHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.fieldPadding,
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            spacing: 6,
            children: [
              if (icon != null)
                Icon(icon, size: AppSizes.smallIcon, color: ink),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    color: ink,
                    fontWeight: icon == null ? null : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « N° de tournée » or « Année »: a label, a field of digits, and what is
/// wrong with it under it.
final class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.enabled,
    required this.problem,
    required this.onChanged,
    this.focusNode,
    this.framed = false,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String? problem;
  final ValueChanged<String> onChanged;

  /// Framed in red: the number is taken (CreateTaken mockup).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final problem = this.problem;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          FieldLabel(label),
          TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
            decoration: InputDecoration(
              enabledBorder: framed
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
                      borderSide: BorderSide(
                        color: colors.accent,
                        width: AppSizes.borderWidth,
                      ),
                    )
                  : null,
            ),
            onChanged: onChanged,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          if (problem != null) FieldProblem(problem),
        ],
      ),
    );
  }
}

/// « ⚠ La tournée 49 du CS Villefranche existe déjà. Demandez le code… »
final class _TakenAlert extends StatelessWidget {
  const _TakenAlert({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = AppTextStyles.body.copyWith(color: colors.ink, height: 1.4);
    return Semantics(
      key: const Key('create.taken'),
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: colors.alert,
          border: Border.all(color: colors.accent, width: AppSizes.borderWidth),
          borderRadius: BorderRadius.circular(AppSizes.alertRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            // ⚠ drawn as an icon in the accent red: the text glyph shows
            // as a yellow emoji on Android. The words say it all.
            ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                size: AppSizes.alertGlyph,
                color: colors.accent,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    title,
                    style: text.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(body, style: text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tournée just created: « Tournée 49 · CS Villefranche est prête… »,
/// its QR code, its code with its copy button, and « Partager ».
final class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.created});

  final TourneeCreated created;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(AppSizes.codeCardRadius),
      ),
      child: Column(
        spacing: 14,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.createReady('${created.number}', created.centre),
              key: const Key('create.ready'),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: colors.muted),
            ),
          ),
          JoinQrCode(
            key: const Key('create.qr'),
            data: created.qrData,
            code: created.code,
            size: AppSizes.createdQrCode,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              // The code and its copy button stay together on one line
              // should « Partager » not fit beside them.
              JoinCodeText(
                code: created.code,
                style: AppTextStyles.createdCode,
                codeKey: const Key('create.code'),
                copyKey: const Key('create.copy'),
              ),
              PillButton(
                key: const Key('create.share'),
                label: l10n.teamShare,
                onPressed: () => shareJoinCode(
                  l10n,
                  number: created.number,
                  centre: created.centre,
                  code: created.code,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
