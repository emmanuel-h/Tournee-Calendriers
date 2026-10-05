import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/arrow_text.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// « Appui : ○ → ✓ → ✗ → ○ · [hold] », glyphs and arrows drawn, one
/// sentence ([semanticsLabel]) for screen readers. Under the tiles of the
/// street screen and the doors of the Immeuble grid.
final class TapHintText extends StatelessWidget {
  const TapHintText({
    super.key,
    required this.hold,
    required this.semanticsLabel,
  });

  /// What a long press does (« Appui long : détails »).
  final String hold;
  final String semanticsLabel;

  static const _glyphSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    WidgetSpan glyph(StatusGlyphs which) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: StatusGlyph(which, size: _glyphSize, color: colors.muted),
    );
    // The spaces stay text, so they are as wide as the other spaces.
    final arrow = TextSpan(
      children: [
        const TextSpan(text: ' '),
        arrowSpan(size: AppTextStyles.small.fontSize!, color: colors.muted),
        const TextSpan(text: ' '),
      ],
    );
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${l10n.tapHintTap} '),
            glyph(StatusGlyphs.toDo),
            arrow,
            glyph(StatusGlyphs.done),
            arrow,
            glyph(StatusGlyphs.nobodyHome),
            arrow,
            glyph(StatusGlyphs.toDo),
            TextSpan(text: ' · $hold'),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.small.copyWith(color: colors.muted),
      ),
    );
  }
}
