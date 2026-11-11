import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/presentation/street_part/street_part_notifier.dart';
import 'package:tournee_calendriers/presentation/street_part/street_part_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/close_icon_button.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/components/street_part_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/map/map_view.dart';
import 'package:tournee_calendriers/ui/map/street_part_map.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Opens « Partie de la rue » on [request], over the current screen.
/// Returns the part chosen with « Valider », or null when it was left with
/// ✕ or back: then nothing changes.
///
/// A route of its own rather than a path of the router: what it shows
/// (the numbers, the road) comes from the screen that opens it, and the
/// part goes back to it, which `Navigator.push` carries as its result.
Future<StreetPart?> showStreetPart(
  BuildContext context,
  StreetPartRequest request,
) => Navigator.of(context).push<StreetPart>(
  MaterialPageRoute(builder: (context) => StreetPartScreen(request: request)),
);

/// « Partie de la rue » (PLAN §5.15, `docs/mockups/StreetPart.dc.html`):
/// « Les deux | Impairs | Pairs », the map with its two marks, and the
/// sheet with the part, its count, the quick buttons and « Valider ». A
/// street without positions has « Du n° » and « Au n° » instead of the
/// map. Works offline: the numbers came with the [request].
final class StreetPartScreen extends ConsumerStatefulWidget {
  const StreetPartScreen({super.key, required this.request});

  final StreetPartRequest request;

  @override
  ConsumerState<StreetPartScreen> createState() => _StreetPartScreenState();
}

/// A `State`: the screen owns the text of « Du n° » and « Au n° ».
final class _StreetPartScreenState extends ConsumerState<StreetPartScreen> {
  final _from = TextEditingController();
  final _to = TextEditingController();

  StreetPartNotifier get _notifier =>
      ref.read(streetPartProvider(widget.request).notifier);

  @override
  void initState() {
    super.initState();
    _showBounds(ref.read(streetPartProvider(widget.request)));
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  /// Fills « Du n° » and « Au n° » from what [view] holds of its side.
  void _showBounds(StreetPartView view) {
    _from.text = view.bounds.from?.toString() ?? '';
    _to.text = view.bounds.to?.toString() ?? '';
  }

  void _chooseSide(Sides side) {
    _notifier.chooseSide(side);
    _showBounds(ref.read(streetPartProvider(widget.request)));
  }

  void _typeBounds() => _notifier.typeBounds(from: _from.text, to: _to.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(streetPartProvider(widget.request));
    final notifier = _notifier;
    final drawing = view.drawing;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        toolbarHeight: AppSizes.titleBarWithSubtitleHeight,
        leading: CloseIconButton(
          key: const Key('part.close'),
          tooltip: l10n.streetPartClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _Title(view: view),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.gutter,
              10,
              AppSizes.gutter,
              10,
            ),
            child: SegmentedChoice<Sides>(
              key: const Key('part.sides'),
              groupLabel: l10n.streetPartSides,
              height: AppSizes.minTapTarget,
              selected: view.side,
              onSelected: _chooseSide,
              segments: [
                Segment(
                  value: Sides.both,
                  label: l10n.streetPartSideBoth,
                  key: const Key('part.sides.both'),
                ),
                Segment(
                  value: Sides.odd,
                  label: l10n.streetPartSideOdd,
                  key: const Key('part.sides.odd'),
                ),
                Segment(
                  value: Sides.even,
                  label: l10n.streetPartSideEven,
                  key: const Key('part.sides.even'),
                ),
              ],
            ),
          ),
          if (drawing != null)
            Expanded(
              child: ref.watch(streetPartMapViewProvider)(
                StreetPartMap(drawing: drawing, onMarkMoved: notifier.moveMark),
              ),
            )
          else ...[
            _BoundFields(from: _from, to: _to, onChanged: _typeBounds),
            const Spacer(),
          ],
          _ResultSheet(
            view: view,
            onAll: () {
              notifier.holdAll();
              _showBounds(ref.read(streetPartProvider(widget.request)));
            },
            onNothing: () {
              notifier.holdNothing();
              _showBounds(ref.read(streetPartProvider(widget.request)));
            },
            onValidate: () => Navigator.of(context).pop(notifier.chosen),
          ),
        ],
      ),
    );
  }
}

/// « Partie de la rue » over « Rue Nationale · n° 1 à 41 ».
final class _Title extends StatelessWidget {
  const _Title({required this.view});

  final StreetPartView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final StreetPartView(:streetName, :lowest, :highest) = view;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSizes.titleSubtitleGap,
      children: [
        Text(l10n.streetPartTitle),
        Text(
          lowest != null && highest != null
              ? l10n.streetPartSubtitle(streetName, lowest, highest)
              : streetName,
          key: const Key('part.subtitle'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.small.copyWith(
            color: AppColors.of(context).muted,
          ),
        ),
      ],
    );
  }
}

/// « Du n° » and « Au n° », for a street whose numbers have no position:
/// the part is chosen by number, for the side shown.
final class _BoundFields extends StatelessWidget {
  const _BoundFields({
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final TextEditingController from;
  final TextEditingController to;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.gutter,
        6,
        AppSizes.gutter,
        16,
      ),
      child: Row(
        spacing: AppSizes.columnGap,
        children: [
          Expanded(
            child: _NumberField(
              key: const Key('part.from'),
              label: l10n.streetPartFrom,
              controller: from,
              onChanged: onChanged,
            ),
          ),
          Expanded(
            child: _NumberField(
              key: const Key('part.to'),
              label: l10n.streetPartTo,
              controller: to,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// A bound, digits only, with its label above it, said together by screen
/// readers.
final class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(
            label,
            style: AppTextStyles.fieldLabel.copyWith(color: colors.ink),
          ),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            // Five digits: no house number goes beyond 99999.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            textInputAction: TextInputAction.next,
            style: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

/// The white sheet under the map: the part, « 23 numéros gardés sur 41 »,
/// the two quick buttons of the side shown and « Valider ».
final class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.view,
    required this.onAll,
    required this.onNothing,
    required this.onValidate,
  });

  final StreetPartView view;
  final VoidCallback onAll;
  final VoidCallback onNothing;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final (all, nothing) = switch (view.side) {
      Sides.both => (l10n.streetPartWholeAction, l10n.streetPartNothingAction),
      Sides.odd => (l10n.streetPartAllOdd, l10n.streetPartNoOdd),
      Sides.even => (l10n.streetPartAllEven, l10n.streetPartNoEven),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.sheetRadius),
        ),
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Center(
                child: SizedBox(
                  width: AppSizes.dragHandleWidth,
                  height: AppSizes.dragHandleHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.line,
                      borderRadius: BorderRadius.circular(
                        AppSizes.dragHandleHeight / 2,
                      ),
                    ),
                  ),
                ),
              ),
              // `liveRegion`: TalkBack says the new part as a mark moves.
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streetPartText(l10n, view.part),
                      key: const Key('part.result'),
                      style: AppTextStyles.partResult.copyWith(
                        color: colors.ink,
                      ),
                    ),
                    Text(
                      l10n.streetPartKept(view.keptCount, view.numberCount),
                      key: const Key('part.count'),
                      style: AppTextStyles.small.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: SecondaryButton(
                      key: const Key('part.all'),
                      label: all,
                      compact: true,
                      onPressed: onAll,
                    ),
                  ),
                  Expanded(
                    child: SecondaryButton(
                      key: const Key('part.nothing'),
                      label: nothing,
                      compact: true,
                      onPressed: onNothing,
                    ),
                  ),
                ],
              ),
              if (view.overlaps.isNotEmpty) _OverlapWarning(view: view),
              PrimaryButton(
                key: const Key('part.validate'),
                label: l10n.streetPartValidate,
                onPressed: onValidate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The amber block above « Valider » (PLAN §5.15 « Other secteurs »): the
/// numbers kept that other secteurs hold too, one line per secteur. A
/// warning only: « Valider » stays, since the index may be out of date and
/// a centre may want two secteurs on the same numbers.
final class _OverlapWarning extends StatelessWidget {
  const _OverlapWarning({required this.view});

  final StreetPartView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final style = AppTextStyles.body.copyWith(color: colors.ink, height: 1.35);
    // `liveRegion`: TalkBack says it when it appears or changes, as a mark
    // moves onto a number another secteur holds.
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        key: const Key('part.overlaps'),
        decoration: BoxDecoration(
          color: colors.nobodyHomePale,
          border: Border.all(
            color: colors.nobodyHomeBorder,
            width: AppSizes.partWarningBorder,
          ),
          borderRadius: BorderRadius.circular(AppSizes.tileRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              ExcludeSemantics(
                child: Text(
                  '⚠',
                  style: style.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    for (final line in view.overlaps)
                      Text(overlapText(l10n, line), style: style),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
