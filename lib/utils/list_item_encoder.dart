import '../style/native_list.dart';

/// Encodes [item] for the native side, as `CNNativeSheet` and `CNPopover`
/// send their rows. The keys are read by `CNSheetConfig.parseItems` on iOS
/// and by the popover's row parser on both platforms.
Map<String, Object?> encodeListItem(CNListItem item) {
  final image = item.leadingImage;
  return {
    'title': item.title,
    if (item.subtitle != null) 'subtitle': item.subtitle,
    if (item.trailingText != null) 'trailingText': item.trailingText,
    if (item.leadingSymbol != null) 'leadingSfSymbol': item.leadingSymbol!.name,
    if (image != null)
      'leadingImage': {
        'path': image.assetPath,
        if (image.imageData != null) 'data': image.imageData,
        if (image.imageFormat != null) 'format': image.imageFormat,
      },
    'showChevron': item.showChevron,
  };
}
