import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/presentation/welcome/welcome_notifier.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/onboarding/onboarding_parts.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Bienvenue » (PLAN §5.1, Welcome mockup): where a phone the app knows
/// nothing of opens. The member's first name, then « Créer une tournée »
/// or « Rejoindre une tournée », both disabled until the name is valid.
/// The name is kept on the phone before either opens.
final class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

/// A `State`: the screen keeps the text field's controller.
final class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  // Starts from the name kept, when the phone has one (back from a
  // request refused).
  late final _name = TextEditingController(
    text: ref.read(welcomeProvider).name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Keeps the name, then opens [location] above this screen.
  Future<void> _goOn(String location) async {
    if (await ref.read(welcomeProvider.notifier).confirm() && mounted) {
      await context.push(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(welcomeProvider);
    final goOn = state.canGoOn;
    return Scaffold(
      body: SafeArea(
        // The content, then the buttons at the bottom of the screen; it
        // scrolls when the keyboard leaves too little room.
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 0),
              sliver: SliverList.list(
                children: [
                  _Logo(colors: colors),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.appTitle,
                      style: AppTextStyles.welcomeTitle.copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.welcomeIntro,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // `MergeSemantics`: TalkBack names the field « Votre
                  // prénom ».
                  MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        FieldLabel(l10n.nameFieldLabel),
                        TextField(
                          key: const Key('welcome.name'),
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: colors.ink,
                          ),
                          decoration: const InputDecoration(
                            constraints: BoxConstraints(
                              minHeight: AppSizes.tallFieldHeight,
                            ),
                          ),
                          onChanged: ref.read(welcomeProvider.notifier).type,
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.tooLong)
                    FieldProblem(l10n.nameTooLong(MemberName.maxLength))
                  else
                    Text(
                      l10n.welcomeNameHelp,
                      style: AppTextStyles.small.copyWith(color: colors.muted),
                    ),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      PrimaryButton(
                        key: const Key('welcome.create'),
                        label: l10n.createTourneeAction,
                        onPressed: goOn ? () => _goOn(AppRoutes.create) : null,
                      ),
                      SecondaryButton(
                        key: const Key('welcome.join'),
                        label: l10n.joinTourneeAction,
                        onPressed: goOn ? () => _goOn(AppRoutes.join) : null,
                      ),
                    ],
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

/// The red square with a ticked calendar above the app's name.
final class _Logo extends StatelessWidget {
  const _Logo({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    // Decoration: the app's name follows.
    child: ExcludeSemantics(
      child: Container(
        width: AppSizes.welcomeLogo,
        height: AppSizes.welcomeLogo,
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(AppSizes.welcomeLogoRadius),
        ),
        child: Icon(
          Icons.event_available_outlined,
          size: AppSizes.welcomeLogoIcon,
          color: colors.onAccent,
        ),
      ),
    ),
  );
}
