import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Detects image format from asset path or image data.
///
/// Returns the format string ('png', 'svg', 'jpg', 'jpeg', etc.) based on:
/// 1. File extension from [assetPath] if provided
/// 2. Image data magic bytes if [imageData] is provided
/// 3. Returns null if format cannot be determined
String? detectImageFormat(String? assetPath, Uint8List? imageData) {
  // First, try to detect from file extension
  if (assetPath != null && assetPath.isNotEmpty) {
    final extension = assetPath.split('.').last.toLowerCase();
    if (extension == 'svg') return 'svg';
    if (extension == 'png') return 'png';
    if (extension == 'jpg' || extension == 'jpeg') return 'jpg';
    if (extension == 'gif') return 'gif';
    if (extension == 'webp') return 'webp';
  }

  // If no extension or format not detected, try to detect from image data magic bytes
  if (imageData != null && imageData.length >= 4) {
    // PNG: 89 50 4E 47 (PNG signature)
    if (imageData[0] == 0x89 &&
        imageData[1] == 0x50 &&
        imageData[2] == 0x4E &&
        imageData[3] == 0x47) {
      return 'png';
    }

    // JPEG: FF D8 FF
    if (imageData[0] == 0xFF && imageData[1] == 0xD8 && imageData[2] == 0xFF) {
      return 'jpg';
    }

    // GIF: 47 49 46 38 (GIF8)
    if (imageData[0] == 0x47 &&
        imageData[1] == 0x49 &&
        imageData[2] == 0x46 &&
        imageData[3] == 0x38) {
      return 'gif';
    }

    // SVG: Check if it starts with '<' or contains 'svg' in the first bytes
    // SVG files are XML, so they typically start with '<' or whitespace followed by '<'
    final firstBytes = String.fromCharCodes(imageData.take(100));
    if (firstBytes.trim().startsWith('<') &&
        (firstBytes.contains('<svg') || firstBytes.contains('SVG'))) {
      return 'svg';
    }
  }

  // Default to PNG if we have image data but can't determine format
  // (PNG is the most common format for icons)
  if (imageData != null) {
    return 'png';
  }

  return null;
}

/// Resolves asset path based on device pixel ratio, similar to Flutter's automatic asset selection.
///
/// Flutter automatically picks assets from folders like:
/// - `icons/` (1x)
/// - `icons/2.0x/` (2x)
/// - `icons/3.0x/` (3x)
///
/// This function does the same for native platform views:
/// 1. Tries to find asset at the exact pixel ratio (e.g., 3.0x for @3x devices)
/// 2. If not found, picks the closest bigger size
/// 3. Falls back to the original path if no resolution-specific asset is found
///
/// - [assetPath]: The base asset path (e.g., "assets/icons/checkcircle.png")
/// - [devicePixelRatio]: Optional device pixel ratio (defaults to current device)
/// - Returns: Resolved asset path or original path if no resolution-specific asset found
Future<String> resolveAssetPathForPixelRatio(
  String assetPath, {
  double? devicePixelRatio,
}) async {
  // Get device pixel ratio if not provided
  final pixelRatio =
      devicePixelRatio ??
      ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

  // Round to nearest 0.5 (1.0, 1.5, 2.0, 2.5, 3.0, etc.)
  final roundedRatio = (pixelRatio * 2).round() / 2.0;

  // Extract directory and filename from path
  final pathParts = assetPath.split('/');
  if (pathParts.isEmpty) return assetPath;

  final fileName = pathParts.last;
  final directory = pathParts.length > 1
      ? pathParts.sublist(0, pathParts.length - 1).join('/')
      : '';

  // Try exact ratio first (e.g., 3.0x)
  final exactRatioPath = roundedRatio == 1.0
      ? assetPath
      : '$directory/${roundedRatio}x/$fileName';

  if (await _assetExists(exactRatioPath)) {
    return exactRatioPath;
  }

  // If exact ratio not found, try to find closest bigger size
  // Common ratios: 1.0, 1.5, 2.0, 2.5, 3.0, 4.0
  final possibleRatios = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0];

  // Find all bigger ratios
  final biggerRatios = possibleRatios.where((r) => r > roundedRatio).toList()
    ..sort();

  // Try each bigger ratio until we find one that exists
  for (final ratio in biggerRatios) {
    final ratioPath = ratio == 1.0
        ? assetPath
        : '$directory/${ratio}x/$fileName';
    if (await _assetExists(ratioPath)) {
      return ratioPath;
    }
  }

  // Fallback to original path
  return assetPath;
}

/// Checks if an asset exists in the Flutter asset bundle.
Future<bool> _assetExists(String assetPath) async {
  try {
    await rootBundle.load(assetPath);
    return true;
  } catch (e) {
    return false;
  }
}

/// Renders an [IconData] to PNG bytes for use in native platform views.
///
/// The [size] parameter is the logical font size of the glyph. The returned
/// bitmap is sized to the glyph's actual painted bounds, not to a fixed
/// `size × size` box — square icon fonts (Material, Cupertino) round-trip at
/// `size × size`, while fonts whose glyphs overflow their em-box (e.g.
/// FontAwesome) get a bitmap large enough to contain the full glyph without
/// clipping.
///
/// The function works in two passes:
///   1. Lay out and paint the glyph onto a canvas with generous transparent
///      padding on every side, large enough to contain any overflow from
///      typical icon fonts.
///   2. Scan the alpha channel to find the non-transparent bounding box and
///      crop the bitmap down to that. This avoids per-font tuning and any
///      caller-visible "overflow margin" knob.
Future<Uint8List?> iconDataToImageBytes(
  IconData iconData, {
  double size = 25.0,
  Color color = CupertinoColors.black,
}) async {
  try {
    final double pixelRatio =
        ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          inherit: false,
          color: color,
          fontSize: size,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 100% of `size` of transparent headroom on every side. TextPainter
    // reports line-box metrics, not glyph-bounds metrics, so we can't ask
    // the engine ahead of time how far a given glyph will overflow. This
    // is a safe upper bound for every icon font we've encountered; the
    // overflow gets cropped away in the second pass below.
    final double padding = size;
    final double logicalWidth = painter.width + padding * 2;
    final double logicalHeight = painter.height + padding * 2;
    final int paddedPixelWidth = (logicalWidth * pixelRatio).ceil();
    final int paddedPixelHeight = (logicalHeight * pixelRatio).ceil();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)..scale(pixelRatio);
    painter.paint(canvas, Offset(padding, padding));
    final ui.Image paddedImage = await recorder.endRecording().toImage(
      paddedPixelWidth,
      paddedPixelHeight,
    );

    final ByteData? rgbaData = await paddedImage.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (rgbaData == null) {
      paddedImage.dispose();
      return null;
    }
    final Uint8List rgba = rgbaData.buffer.asUint8List();

    int minX = paddedPixelWidth;
    int minY = paddedPixelHeight;
    int maxX = -1;
    int maxY = -1;
    for (int y = 0; y < paddedPixelHeight; y++) {
      final int rowOffset = y * paddedPixelWidth * 4;
      for (int x = 0; x < paddedPixelWidth; x++) {
        if (rgba[rowOffset + x * 4 + 3] != 0) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < 0) {
      // Nothing was painted (e.g. unknown glyph for the requested font).
      paddedImage.dispose();
      return null;
    }

    final int croppedPixelWidth = maxX - minX + 1;
    final int croppedPixelHeight = maxY - minY + 1;

    final ui.PictureRecorder cropRecorder = ui.PictureRecorder();
    final Canvas cropCanvas = Canvas(cropRecorder);
    cropCanvas.drawImageRect(
      paddedImage,
      Rect.fromLTWH(
        minX.toDouble(),
        minY.toDouble(),
        croppedPixelWidth.toDouble(),
        croppedPixelHeight.toDouble(),
      ),
      Rect.fromLTWH(
        0,
        0,
        croppedPixelWidth.toDouble(),
        croppedPixelHeight.toDouble(),
      ),
      Paint(),
    );
    final ui.Image croppedImage = await cropRecorder.endRecording().toImage(
      croppedPixelWidth,
      croppedPixelHeight,
    );
    paddedImage.dispose();

    final ByteData? pngData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    croppedImage.dispose();

    return pngData?.buffer.asUint8List();
  } catch (e) {
    debugPrint('Error rendering icon to image: $e');
    return null;
  }
}
