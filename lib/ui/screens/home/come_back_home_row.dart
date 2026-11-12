import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/come_backs/come_backs_notifier.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/come_backs/come_back_words.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// « ↻ À repasser (5) › » with « Prochain : aujourd'hui vers 19 h » under
/// it, in Accueil's panel under « Commencer une tournée » (first under the
/// band during a tournée; PLAN §5.17, HomeComeBack mockup). Only when the
/// secteur has at least one « repasser »; « Prochain » only when one has a
/// day from today on. A tap opens « À repasser ».
final class ComeBackHomeRow extends ConsumerWidget {
  const ComeBackHomeRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(comeBacksProvider);
    if (!view.shown) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final next = view.next;
    final when = next == null ? null : comeBackRowWhen(l10n, next);
    return Semantics(
      button: true,
      label: l10n.comeBacksRowSemantics(view.count),
      excludeSemantics: true,
      child: InkWell(
        key: const Key('home.comeBacks'),
        onTap: () => context.push(AppRoutes.comeBacks),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSizes.choiceRowHeight,
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: AppSizes.comeBackHomeSquare,
                height: AppSizes.comeBackHomeSquare,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.comeBack,
                  borderRadius: BorderRadius.circular(
                    AppSizes.comeBackSquareRadius,
                  ),
                ),
                child: StatusGlyph(
                  StatusGlyphs.comeBack,
                  size: AppSizes.tileGlyph,
                  color: colors.onComeBack,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      l10n.comeBacksTitle(view.count),
                      style: AppTextStyles.streetName.copyWith(
                        color: colors.ink,
                      ),
                    ),
                    if (when != null)
                      Text(
                        l10n.comeBacksNext(lowerFirst(when)),
                        key: const Key('home.comeBacks.next'),
                        style: AppTextStyles.small.copyWith(
                          color: colors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: AppSizes.smallIcon,
                color: colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
