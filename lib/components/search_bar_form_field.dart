import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../style/sf_symbol.dart';
import 'search_bar.dart';

/// A [CNSearchBar] in a [Form] (#192): it takes a [validator], is checked
/// with [FormState.validate], saved with [FormState.save] and cleared with
/// [FormState.reset].
///
/// Like the system search field, the bar has no error state: it shows no
/// error text or error styling. [FormState.validate] returns whether the
/// field is valid, and the app shows any message itself.
///
/// The bar is a single-line text field here, for example to name or rename
/// something, so it is not expandable and has no Cancel button by default.
///
/// Example:
/// ```dart
/// Form(
///   key: formKey,
///   child: CNSearchBarFormField(
///     initialValue: 'Porsche 911',
///     placeholder: 'Name',
///     maxLength: 150,
///     validator: (value) =>
///         (value ?? '').trim().isEmpty ? 'Please enter a name' : null,
///     onSaved: (value) => name = value!,
///   ),
/// )
/// ```
class CNSearchBarFormField extends FormField<String> {
  /// Creates a [CNSearchBar] that takes part in a [Form].
  ///
  /// [initialValue] is the text the bar opens with, as
  /// [CNSearchBar.initialText]; the other parameters are those of
  /// [CNSearchBar].
  CNSearchBarFormField({
    super.key,
    this.controller,
    String? initialValue,
    super.onSaved,
    super.validator,
    super.autovalidateMode,
    super.enabled,
    super.restorationId,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    String placeholder = 'Search',
    bool expandable = false,
    bool initiallyExpanded = true,
    double expandedHeight = 36.0,
    Color? tint,
    Color? backgroundColor,
    Color? textColor,
    Color? placeholderColor,
    Color? clearButtonColor,
    bool showShadow = true,
    bool showCancelButton = false,
    String cancelText = 'Cancel',
    bool autofocus = false,
    CNSymbol? searchIcon,
    CNSymbol? clearIcon,
    bool autoHideOnModal = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool autocorrect = true,
    TextInputType keyboardType = TextInputType.text,
    String? clearButtonSemanticLabel,
    TextDirection? textDirection,
    String? labelFontFamily,
    double? labelFontSize,
    FontWeight? labelFontWeight,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) : super(
         initialValue: initialValue ?? '',
         builder: (field) {
           final state = field as _CNSearchBarFormFieldState;
           return CNSearchBar(
             controller: state._effectiveController,
             initialText: initialValue,
             onChanged: (value) {
               field.didChange(value);
               onChanged?.call(value);
             },
             onSubmitted: onSubmitted,
             placeholder: placeholder,
             expandable: expandable,
             initiallyExpanded: initiallyExpanded,
             expandedHeight: expandedHeight,
             tint: tint,
             backgroundColor: backgroundColor,
             textColor: textColor,
             placeholderColor: placeholderColor,
             clearButtonColor: clearButtonColor,
             showShadow: showShadow,
             showCancelButton: showCancelButton,
             cancelText: cancelText,
             autofocus: autofocus,
             searchIcon: searchIcon,
             clearIcon: clearIcon,
             autoHideOnModal: autoHideOnModal,
             textCapitalization: textCapitalization,
             autocorrect: autocorrect,
             keyboardType: keyboardType,
             clearButtonSemanticLabel: clearButtonSemanticLabel,
             textDirection: textDirection,
             labelFontFamily: labelFontFamily,
             labelFontSize: labelFontSize,
             labelFontWeight: labelFontWeight,
             maxLength: maxLength,
             inputFormatters: inputFormatters,
           );
         },
       );

  /// Controls the bar, as [CNSearchBar.controller]. Null uses a controller
  /// of the field's own, which [FormState.reset] uses to put the initial
  /// text back.
  final CNSearchBarController? controller;

  @override
  FormFieldState<String> createState() => _CNSearchBarFormFieldState();
}

class _CNSearchBarFormFieldState extends FormFieldState<String> {
  CNSearchBarController? _ownController;

  CNSearchBarFormField get _field => widget as CNSearchBarFormField;

  CNSearchBarController get _effectiveController =>
      _field.controller ?? (_ownController ??= CNSearchBarController());

  @override
  void reset() {
    super.reset();
    // The bar keeps its own text: give it the initial text back.
    _effectiveController.setText(widget.initialValue ?? '');
  }
}
