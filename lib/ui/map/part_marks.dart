import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/ui/components/street_part_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

// The two marks of « Partie de la rue » (PLAN §5.15, StreetPart mockup),
// drawn over the map as Flutter widgets: a round handle on the road, a
// stem, a dark label (« entre 5 et 7 »). They snap to the places the
// domain gives (`PartDrawing.gaps`), measured on screen once by the map.

/// The index of the place of [places] nearest to [finger], all on screen:
/// where a mark dragged there snaps. [places] is not empty.
int nearestPlace(List<Offset> places, Offset finger) {
  var nearest = 0;
  for (var i = 1; i < places.length; i++) {
    if ((places[i] - finger).distanceSquared <
        (places[nearest] - finger).distanceSquared) {
      nearest = i;
    }
  }
  return nearest;
}

/// The mark a drag of the [grabbed] one towards place [gap] moves: the
/// grabbed one, unless both stand together at [first] (= [last]); then
/// the first when the finger goes towards the start, the last otherwise,
/// so two marks that met can always part again.
PartMark markToMove({
  required PartMark grabbed,
  required int first,
  required int last,
  required int gap,
}) {
  if (first != last) return grabbed;
  return gap < first ? PartMark.first : PartMark.last;
}

/// The two marks of [drawing] at their places on screen ([places], one per
/// [PartDrawing.gaps]), dragged along them: [onMoved] says which mark goes
/// to which place. Screen readers hear « Première marque, entre 5 et 7 »
/// and move it with a swipe up or down.
final class PartMarks extends StatefulWidget {
  const PartMarks({
    super.key,
    required this.drawing,
    required this.places,
    required this.onMoved,
  });

  final PartDrawing drawing;
  final List<Offset> places;
  final void Function(PartMark mark, int gap) onMoved;

  @override
  State<PartMarks> createState() => _PartMarksState();
}

final class _PartMarksState extends State<PartMarks> {
  /// The mark the finger moves, once it left its place; null between
  /// drags.
  PartMark? _moving;

  void _drag(PartMark grabbed, Offset globalPosition) {
    final box = context.findRenderObject()! as RenderBox;
    final gap = nearestPlace(widget.places, box.globalToLocal(globalPosition));
    final first = widget.drawing.first!.gap;
    final last = widget.drawing.last!.gap;
    final mark =
        _moving ??
        markToMove(grabbed: grabbed, first: first, last: last, gap: gap);
    final at = mark == PartMark.first ? first : last;
    if (gap == at) return;
    _moving = mark;
    widget.onMoved(mark, gap);
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.drawing.first;
    final last = widget.drawing.last;
    if (first == null || last == null) return const SizedBox.expand();
    return Stack(
      fit: StackFit.expand,
      children: [
        // The last mark on top: two marks together at the start (nothing
        // kept) are first pulled apart towards the end.
        for (final (mark, at) in [
          (PartMark.first, first),
          (PartMark.last, last),
        ])
          _positioned(mark, at),
      ],
    );
  }

  Widget _positioned(PartMark mark, PartMarkAt at) {
    final l10n = AppLocalizations.of(context);
    final place = markPlaceText(l10n, at.place);
    final centre = widget.places[at.gap];
    const width = AppSizes.partMarkLabelWidth;
    const above = AppSizes.partMarkLabelHeight + AppSizes.partMarkStemHeight;
    return Positioned(
      key: ValueKey('part.mark.${mark.name}'),
      left: centre.dx - width / 2,
      top: centre.dy - above - AppSizes.minTapTarget / 2,
      width: width,
      child: Semantics(
        label: switch (mark) {
          PartMark.first => l10n.streetPartFirstMark(place),
          PartMark.last => l10n.streetPartLastMark(place),
        },
        excludeSemantics: true,
        // A swipe up or down with TalkBack moves the mark by one place.
        onIncrease: at.gap < widget.places.length - 1
            ? () => widget.onMoved(mark, at.gap + 1)
            : null,
        onDecrease: at.gap > 0 ? () => widget.onMoved(mark, at.gap - 1) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Label(text: place),
            const _Stem(height: AppSizes.partMarkStemHeight),
            GestureDetector(
              // A drag from anywhere around the handle, as soon as the
              // finger moves: the map under it does not move.
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => _moving = null,
              onPanUpdate: (details) => _drag(mark, details.globalPosition),
              onPanEnd: (_) => _moving = null,
              child: const SizedBox.square(
                dimension: AppSizes.minTapTarget,
                // The stem goes on down to the handle's centre, under it.
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: _Stem(height: AppSizes.minTapTarget / 2),
                    ),
                    _Handle(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « entre 5 et 7 », white on a dark pill.
final class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: AppSizes.partMarkLabelHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.mapSelectedCasing,
        borderRadius: BorderRadius.circular(AppSizes.partMarkLabelHeight / 2),
      ),
      // `widthFactor: 1`: as wide as the text, centred in its height.
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          maxLines: 1,
          style: AppTextStyles.partMarkLabel.copyWith(
            color: colors.mapSelectedCore,
          ),
        ),
      ),
    );
  }
}

final class _Stem extends StatelessWidget {
  const _Stem({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppSizes.partMarkStem,
    height: height,
    child: ColoredBox(color: AppColors.of(context).mapSelectedCasing),
  );
}

/// The round handle on the road, with its two grip lines.
final class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: AppSizes.partMarkHandle,
      height: AppSizes.partMarkHandle,
      decoration: BoxDecoration(
        color: colors.mapSelectedCore,
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.mapSelectedCasing,
          width: AppSizes.partMarkBorder,
        ),
      ),
      // `drag_handle` is two flat lines: turned a quarter, they stand
      // upright, as in the mockup.
      child: RotatedBox(
        quarterTurns: 1,
        child: Icon(
          Icons.drag_handle,
          size: AppSizes.partMarkGrip,
          color: colors.mapSelectedCasing,
        ),
      ),
    );
  }
}
