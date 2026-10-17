import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/street/progress_level.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/map/house_dot_image.dart';
import 'package:tournee_calendriers/ui/map/map_style.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The legend chip over Accueil's map (PLAN §5.3, Home and HomeZoom
/// mockups): what the street colours mean (« faite », « en partie », « à
/// faire », « libre »), or, once the map shows the house dots, what the
/// dots mean (« fait », « personne », « repasser », « à faire »).
///
/// A tap folds it into a small « Légende » chip, out of the way of the
/// map; a tap on the chip unfolds it. Whether it is folded only matters to
/// this screen, so the widget keeps it itself (a `StatefulWidget`).
final class MapLegend extends StatefulWidget {
  const MapLegend({super.key, required this.houses});

  /// The map shows the house dots: explain them rather than the streets.
  final bool houses;

  @override
  State<MapLegend> createState() => _MapLegendState();
}

final class _MapLegendState extends State<MapLegend> {
  var _folded = false;

  void _toggle() => setState(() => _folded = !_folded);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textStyle = AppTextStyles.legend.copyWith(color: colors.ink);
    return Semantics(
      button: true,
      // The words of the entries are read with it; the hint says what a
      // tap does.
      onTapHint: _folded ? l10n.mapLegendShow : l10n.mapLegendHide,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.legendRadius),
          side: BorderSide(color: colors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('map.legend'),
          onTap: _toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _folded
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Icon(
                          Icons.legend_toggle,
                          size: AppSizes.smallIcon,
                          color: colors.ink,
                        ),
                        Text(l10n.mapLegend, style: textStyle),
                      ],
                    )
                  : Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final (sample, word) in _entries(l10n, colors))
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 6,
                            children: [
                              sample,
                              Text(word, style: textStyle),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Each entry: its sample and its word, in the mockups' order.
  List<(Widget, String)> _entries(AppLocalizations l10n, AppColors colors) =>
      widget.houses
      ? [
          (_dot(HouseDotStatus.done, colors), l10n.tileStatusDone),
          (_dot(HouseDotStatus.nobodyHome, colors), l10n.tileStatusNobodyHome),
          (_dot(HouseDotStatus.comeBack, colors), l10n.tileStatusComeBack),
          (_dot(HouseDotStatus.toDo, colors), l10n.tileStatusToDo),
        ]
      : [
          (_line(ProgressLevel.done, colors), l10n.mapLegendStreetDone),
          (_line(ProgressLevel.partial, colors), l10n.mapLegendStreetPartial),
          (_line(ProgressLevel.toDo, colors), l10n.mapLegendStreetToDo),
          (_line(ProgressLevel.free, colors), l10n.mapLegendStreetFree),
        ];

  /// A house dot as the map draws it, made smaller.
  static Widget _dot(HouseDotStatus status, AppColors colors) =>
      SizedBox.square(
        dimension: AppSizes.legendDot,
        // `FittedBox` scales the full-size dot down, glyph and ring together.
        child: FittedBox(
          child: CustomPaint(
            size: const Size.square(AppSizes.houseDot),
            painter: HouseDotPainter(HouseDotLook.of(status, colors)),
          ),
        ),
      );

  /// A short piece of street line, dashed for « libre » as on the map.
  static Widget _line(ProgressLevel level, AppColors colors) => CustomPaint(
    size: const Size(AppSizes.legendLineSample, 8),
    painter: _LinePainter(
      streetLineColor(level, colors),
      dashed: level == ProgressLevel.free,
    ),
  );
}

/// Paints a horizontal line across its box: solid and round-capped, or
/// dashed and thinner, as the map draws a street and a « libre » one.
final class _LinePainter extends CustomPainter {
  const _LinePainter(this.color, {required this.dashed});

  final Color color;
  final bool dashed;

  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = dashed ? 4 : 6
      ..strokeCap = dashed ? StrokeCap.butt : StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), paint);
      return;
    }
    for (var x = 2.0; x < size.width - 2; x += _dash + _gap) {
      final end = (x + _dash).clamp(x, size.width - 2);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
