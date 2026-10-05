/// The `onEditingComplete` of a field whose value can be refused on the
/// keyboard's « OK » (a door name, a number, a street name).
///
/// By default, « OK » (`TextInputAction.done`) takes the focus off the
/// field before `onSubmitted` even runs, so the keyboard closes and the
/// person has to tap the field again to fix a refused value. Giving the
/// field any `onEditingComplete` replaces that default: this one does
/// nothing, so the focus and the keyboard stay. The field's `onSubmitted`
/// then decides: a refused value leaves the field as it is, under its
/// message; a value taken closes the sheet, or lets the focus go itself.
void keepFocusOnSubmit() {}
