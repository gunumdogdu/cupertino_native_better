import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
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
    if (imageData[0] == 0xFF && 
        imageData[1] == 0xD8 && 
        imageData[2] == 0xFF) {
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
  final pixelRatio = devicePixelRatio ?? 
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
  final biggerRatios = possibleRatios
      .where((r) => r > roundedRatio)
      .toList()
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

/// Renders an IconData to PNG bytes for use in native platform views.
/// 
/// The [size] parameter controls the logical pixel size of the icon.
/// This function renders the icon at the native size and proper pixel density.
Future<Uint8List?> iconDataToImageBytes(
  IconData iconData, {
  double size = 25.0,
  Color color = CupertinoColors.black,
}) async {
  try {
    final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();
    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());

    final RenderView renderView = RenderView(
      view: ui.PlatformDispatcher.instance.views.first,
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: repaintBoundary,
      ),
      configuration: ViewConfiguration.fromView(
        ui.PlatformDispatcher.instance.views.first,
      ),
    );

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> rootElement =
        RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Icon(
          iconData,
          size: size,
          color: color, // Will be tinted by native platform
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final ui.Image image = await repaintBoundary.toImage(
      pixelRatio: ui.PlatformDispatcher.instance.views.first.devicePixelRatio,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData?.buffer.asUint8List();
  } catch (e) {
    debugPrint('Error rendering icon to image: $e');
    return null;
  }
}

