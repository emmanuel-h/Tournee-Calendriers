import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/join/join_tournee_notifier.dart';
import 'package:tournee_calendriers/presentation/join/join_tournee_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/dashed_outline.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/account_line.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/onboarding_parts.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/qr_scanner_screen.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Rejoindre une tournée » (PLAN §5.2, Join mockup): « Scanner le QR
/// code » or the code typed in two boxes of three characters, the tournée
/// it shows to confirm, then « Demander à rejoindre », which leaves for
/// « Demande envoyée ».
final class JoinTourneeScreen extends ConsumerStatefulWidget {
  const JoinTourneeScreen({super.key});

  @override
  ConsumerState<JoinTourneeScreen> createState() => _JoinTourneeScreenState();
}

/// A `State`: the screen keeps the boxes' controllers and focus.
final class _JoinTourneeScreenState extends ConsumerState<JoinTourneeScreen> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  final _secondFocus = FocusNode();

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    _secondFocus.dispose();
    super.dispose();
  }

  /// Shows [text] in the box of [controller] when the notifier changed it
  /// (a code pasted whole, a code scanned), the cursor at its end.
  static void _show(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Sends what [box] now holds to the notifier ([typed]), then shows in
  /// both boxes what it kept: upper case, at most three characters, a code
  /// typed whole spread over both. Shown even when the notifier's state did
  /// not change (a fourth character dropped), which `ref.listen` would not
  /// tell.
  void _typed(void Function(String text) typed, String text) {
    typed(text);
    final kept = ref.read(joinTourneeProvider);
    _show(_first, kept.first);
    _show(_second, kept.second);
  }

  /// Opens the camera; the code read is the notifier's to judge.
  Future<void> _scan() async {
    final read = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const QrScannerScreen(),
      ),
    );
    if (read != null && mounted) {
      ref.read(joinTourneeProvider.notifier).scanned(read);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(joinTourneeProvider);
    final notifier = ref.read(joinTourneeProvider.notifier);
    // `listen`: reacts once to each change, without redrawing.
    ref.listen(joinTourneeProvider, (previous, next) {
      // A code scanned fills the boxes too.
      _show(_first, next.first);
      _show(_second, next.second);
      // Three characters in the first box: on to the second, unless one
      // is refused, which the member must correct there.
      if (next.first.length == 3 &&
          previous?.first.length != 3 &&
          next.second.isEmpty &&
          !next.invalidCharacter) {
        _secondFocus.requestFocus();
      }
      if (next.run case JoinSent(:final tournee)) {
        context.go(AppRoutes.joinPendingOf(tournee));
      }
    });
    return Scaffold(
      appBar: AppBar(title: Text(l10n.screenJoin), titleSpacing: 4),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              sliver: SliverList.list(
                children: [
                  const AccountLine(),
                  const SizedBox(height: 12),
                  _ScanButton(onPressed: () => unawaited(_scan())),
                  const SizedBox(height: 20),
                  _OrTypeIt(text: l10n.joinOrType),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 10,
                    children: [
                      Expanded(
                        child: _CodeBox(
                          fieldKey: const Key('join.first'),
                          label: l10n.teamCodeLabel,
                          controller: _first,
                          onChanged: (text) =>
                              _typed(notifier.typeFirstHalf, text),
                        ),
                      ),
                      // The dash of `K7P-2QX`, drawn: never typed.
                      ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '-',
                            style: AppTextStyles.codeBox.copyWith(
                              color: colors.ink,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _CodeBox(
                          fieldKey: const Key('join.second'),
                          semanticsLabel: l10n.joinCodeSecondSemantics,
                          controller: _second,
                          focusNode: _secondFocus,
                          onChanged: (text) =>
                              _typed(notifier.typeSecondHalf, text),
                        ),
                      ),
                    ],
                  ),
                  if (state.invalidCharacter) ...[
                    const SizedBox(height: 8),
                    FieldProblem(l10n.joinInvalidCharacter),
                  ] else if (state.scanRefused) ...[
                    const SizedBox(height: 8),
                    FieldProblem(l10n.joinScanRefused),
                  ],
                  const SizedBox(height: 20),
                  _Lookup(
                    lookup: state.lookup,
                    onRetry: () => unawaited(notifier.retryLookup()),
                  ),
                  ...switch (state.run) {
                    JoinOffline() => [
                      const SizedBox(height: 12),
                      ScreenMessage(l10n.onboardingOffline),
                    ],
                    JoinAlreadyJoined() => [
                      const SizedBox(height: 12),
                      ScreenMessage(l10n.joinAlreadyJoined),
                    ],
                    JoinIdle() || JoinSending() || JoinSent() => const [],
                  },
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: PrimaryButton(
                    key: const Key('join.request'),
                    label: l10n.joinRequest,
                    onPressed: state.canRequest
                        ? () => unawaited(notifier.request())
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Scanner le QR code »: a tall dashed button, the normal way in.
final class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).joinScan,
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: DashedOutlinePainter(
          colors.editTileBorder,
          radius: AppSizes.scanButtonRadius,
        ),
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.scanButtonRadius),
          child: InkWell(
            key: const Key('join.scan'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppSizes.scanButtonRadius),
            child: SizedBox(
              height: AppSizes.scanButtonHeight,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: AppSizes.scanIcon,
                    color: colors.ink,
                  ),
                  Text(
                    AppLocalizations.of(context).joinScan,
                    style: AppTextStyles.button.copyWith(color: colors.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « ── ou saisir le code ── ».
final class _OrTypeIt extends StatelessWidget {
  const _OrTypeIt({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final line = Expanded(child: Divider(height: 1, color: colors.line));
    return Row(
      spacing: 12,
      children: [
        line,
        Text(text, style: AppTextStyles.small.copyWith(color: colors.muted)),
        line,
      ],
    );
  }
}

/// A box of three characters of the code.
final class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.fieldKey,
    required this.controller,
    required this.onChanged,
    this.label,
    this.semanticsLabel,
    this.focusNode,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// « Code » above the first box; the second has none drawn.
  final String? label;

  /// What screen readers call a box without [label] (« Code, suite »).
  final String? semanticsLabel;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = this.label;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
      borderSide: BorderSide(color: colors.ink, width: AppSizes.borderWidth),
    );
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          if (label != null)
            Text(
              label,
              style: AppTextStyles.helper.copyWith(
                color: colors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          Semantics(
            label: semanticsLabel,
            child: TextField(
              key: fieldKey,
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              // A code is no word: no capital forced by the keyboard, no
              // correction, no suggestion. The notifier upper-cases it.
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              textCapitalization: TextCapitalization.characters,
              style: AppTextStyles.codeBox.copyWith(color: colors.ink),
              decoration: InputDecoration(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.codeBoxHeight,
                ),
                enabledBorder: border,
                focusedBorder: border,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the code shows: the tournée to confirm, or why there is none.
final class _Lookup extends StatelessWidget {
  const _Lookup({required this.lookup, required this.onRetry});

  final JoinLookup lookup;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (lookup) {
      NoLookup() => const SizedBox.shrink(),
      LookingUp() => const Center(
        child: SizedBox.square(
          dimension: AppSizes.minTapTarget,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      TourneeFound(:final number, :final centre, :final campaign) =>
        TourneePreviewCard(
          key: const Key('join.preview'),
          number: number,
          title: l10n.joinPreviewTitle('$number', centre),
          subtitle: l10n.joinPreviewCampaign('$campaign'),
        ),
      CodeUnknown() => ScreenMessage(
        l10n.joinUnknownCode,
        key: const Key('join.unknown'),
      ),
      LookupOffline() => ScreenMessage(
        l10n.joinLookupOffline,
        key: const Key('join.offline'),
        action: PillButton(
          key: const Key('join.retry'),
          label: l10n.retry,
          onPressed: onRetry,
        ),
      ),
    };
  }
}
