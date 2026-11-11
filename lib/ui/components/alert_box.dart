import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « ⚠ … » in a pale red box with a red edge (`.alert` of the mockups):
/// something the member must read before going on (a secteur that exists
/// already, a name taken, PLAN §5.2, §5.16). Read out as soon as it
/// shows.
final class AlertBox extends StatelessWidget {
  const AlertBox({super.key, this.title, required this.body});

  /// A first line in bold, when there is one.
  final String? title;

  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = AppTextStyles.body.copyWith(color: colors.ink, height: 1.4);
    final title = this.title;
    return Semantics(
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
                  if (title != null)
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
