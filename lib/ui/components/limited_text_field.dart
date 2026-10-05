import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// A text field that never holds more than its [limit] allows, with a
/// « 9/20 » counter under it.
///
/// Flutter's own `maxLength` counts symbols as the eye sees them, not the
/// code points the domain counts, and it cuts what is pasted. Here an edit
/// that would pass the limit is refused whole (the text stays as it was)
/// and [tooLongMessage] says why, until the next edit that fits.
final class LimitedTextField extends StatefulWidget {
  const LimitedTextField({
    super.key,
    required this.name,
    required this.controller,
    required this.focusNode,
    required this.limit,
    required this.tooLongMessage,
    this.label,
    this.placeholder,
    this.borderColor,
    this.enabled = true,
  });

  /// Names the parts of the field for tests: `<name>.field`,
  /// `<name>.count`, `<name>.tooLong`.
  final String name;

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextLimit limit;
  final String tooLongMessage;

  /// Written above the field (« Quand repasser ? »); also its name for
  /// screen readers.
  final String? label;

  /// Shown in the empty field; also its name for screen readers when it
  /// has no [label].
  final String? placeholder;

  /// The outline when not focused; the theme's by default.
  final Color? borderColor;

  /// False greys the label and the field, which then takes no text; the
  /// field keeps its place, so the sheet does not move.
  final bool enabled;

  @override
  State<LimitedTextField> createState() => _LimitedTextFieldState();
}

final class _LimitedTextFieldState extends State<LimitedTextField> {
  /// The last edit was refused: the message shows.
  var _refused = false;

  /// A `TextInputFormatter` sees each edit before the field takes it, and
  /// returns the value the field keeps: here the new one, or the old one.
  late final _formatter = TextInputFormatter.withFunction((old, edited) {
    final fits = widget.limit.accepts(edited.text);
    if (_refused == fits) setState(() => _refused = !fits);
    return fits ? edited : old;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final label = widget.label;
    final borderColor = widget.borderColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        // `MergeSemantics`: the label and the field are one node, so
        // TalkBack names the field « Quand repasser ? ».
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              if (label != null)
                Text(
                  label,
                  style: AppTextStyles.fieldLabel.copyWith(
                    color: widget.enabled ? colors.ink : colors.muted,
                  ),
                ),
              TextField(
                key: ValueKey('${widget.name}.field'),
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled,
                inputFormatters: [_formatter],
                style: AppTextStyles.bodyLarge,
                textCapitalization: TextCapitalization.sentences,
                // « OK » on the keyboard closes it, which stores the
                // text.
                textInputAction: TextInputAction.done,
                // A short hint: one line.
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  fillColor: widget.enabled ? null : colors.ground,
                  enabledBorder: borderColor == null
                      ? null
                      : OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(AppSizes.fieldRadius),
                          ),
                          borderSide: BorderSide(
                            color: borderColor,
                            width: AppSizes.borderWidth,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        if (_refused)
          // `liveRegion`: TalkBack reads the message as soon as it shows.
          Semantics(
            liveRegion: true,
            child: Text(
              widget.tooLongMessage,
              key: ValueKey('${widget.name}.tooLong'),
              style: AppTextStyles.small.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        // Redrawn at each edit: a controller notifies its listeners
        // whenever its text changes.
        ValueListenableBuilder(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            final count = widget.limit.count(value.text);
            return Semantics(
              label: l10n.textCountSemantics(count, widget.limit.max),
              excludeSemantics: true,
              child: Text(
                l10n.textCount(count, widget.limit.max),
                key: ValueKey('${widget.name}.count'),
                // `end`: right-aligned under the field, as in the mockup.
                textAlign: TextAlign.end,
                style: AppTextStyles.helper.copyWith(color: colors.muted),
              ),
            );
          },
        ),
      ],
    );
  }
}
