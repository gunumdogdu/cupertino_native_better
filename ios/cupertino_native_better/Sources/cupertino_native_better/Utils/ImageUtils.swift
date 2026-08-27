import UIKit
import Flutter
import SVGKit

/// Shared utility functions for image loading, color conversion, and image processing
final class ImageUtils {
  
  // MARK: - Color Conversion
  
  /// Converts ARGB integer to UIColor
  /// - Parameter argb: ARGB color as integer (0xAARRGGBB format)
  /// - Returns: UIColor instance
  static func colorFromARGB(_ argb: Int) -> UIColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return UIColor(red: r, green: g, blue: b, alpha: a)
  }
  
  /// Converts UIColor to ARGB integer
  /// - Parameter color: UIColor instance
  /// - Returns: ARGB integer (0xAARRGGBB format) or nil if color components can't be extracted
  static func colorToARGB(_ color: UIColor) -> Int? {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    
    guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
      return nil
    }
    
    let a = Int(alpha * 255.0) & 0xFF
    let r = Int(red * 255.0) & 0xFF
    let g = Int(green * 255.0) & 0xFF
    let b = Int(blue * 255.0) & 0xFF
    
    return (a << 24) | (r << 16) | (g << 8) | b
  }
  
  // MARK: - Image Format Detection
  
  /// Detects image format from file path or provided format string
  /// - Parameters:
  ///   - assetPath: Optional asset path to check extension
  ///   - providedFormat: Optional format string that was explicitly provided
  ///   - imageData: Optional image data to check magic bytes
  /// - Returns: Format string ("svg", "png", "jpg", "jpeg") or nil if unknown
  static func detectImageFormat(assetPath: String?, providedFormat: String? = nil, imageData: Data? = nil) -> String? {
    // First, use provided format if available
    if let format = providedFormat?.lowercased() {
      return format
    }
    
    // Then, try to detect from file extension
    if let path = assetPath {
      let lowerPath = path.lowercased()
      if lowerPath.hasSuffix(".svg") {
        return "svg"
      } else if lowerPath.hasSuffix(".png") {
        return "png"
      } else if lowerPath.hasSuffix(".jpg") || lowerPath.hasSuffix(".jpeg") {
        return "jpg"
      }
    }
    
    // If no path or extension doesn't match, try magic bytes from data
    if let data = imageData, data.count >= 4 {
      let bytes = [UInt8](data.prefix(4))
      
      // PNG magic bytes: 89 50 4E 47
      if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
        return "png"
      }
      
      // JPEG magic bytes: FF D8 FF
      if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
        return "jpg"
      }
      
      // SVG magic bytes: Check for XML declaration or <svg tag
      if let string = String(data: data.prefix(1024), encoding: .utf8),
         (string.hasPrefix("<?xml") || string.trimmingCharacters(in: .whitespaces).hasPrefix("<svg")) {
        return "svg"
      }
    }
    
    return nil
  }
  
  // MARK: - Image Loading
  
  /// Loads an image from Flutter asset path with format detection and optional tinting
  /// - Parameters:
  ///   - assetPath: Flutter asset path (e.g., "assets/icons/home.svg")
  ///   - size: Optional size for the image (defaults to 24x24 for SVG, original for raster)
  ///   - format: Optional format string (if nil, will be auto-detected)
  ///   - color: Optional color to tint the image
  ///   - scale: Image scale (defaults to main screen scale)
  /// - Returns: UIImage or nil if failed
  static func loadFlutterAsset(
    _ assetPath: String,
    size: CGSize? = nil,
    format: String? = nil,
    color: UIColor? = nil,
    scale: CGFloat = UIScreen.main.scale
  ) -> UIImage? {
    let flutterKey = FlutterDartProject.lookupKey(forAsset: assetPath)
    guard let path = Bundle.main.path(forResource: flutterKey, ofType: nil) else {
      return nil
    }
    
    // Detect format
    let detectedFormat = format ?? detectImageFormat(assetPath: assetPath)
    
    var image: UIImage?
    
    if detectedFormat == "svg" {
      // Use SVGImageLoader for SVG files
      let svgSize = size ?? CGSize(width: 24, height: 24)
      image = SVGImageLoader.shared.loadSVG(from: assetPath, size: svgSize)
    } else {
      // Use UIImage for raster images (PNG, JPG, etc.)
      image = UIImage(contentsOfFile: path)
    }
    
    // Apply tinting if color is provided
    if let img = image, let col = color, #available(iOS 13.0, *) {
      let targetSize = size ?? img.size
      let isSVG = detectedFormat == "svg"
      return tintImage(img, with: col, size: targetSize, isSVG: isSVG, scale: scale)
    }
    
    return image
  }
  
  /// Creates an image from raw data with format detection and optional tinting
  /// - Parameters:
  ///   - data: Image data bytes
  ///   - format: Optional format string (if nil, will be auto-detected)
  ///   - size: Optional size for SVG images
  ///   - color: Optional color to tint the image
  ///   - scale: Image scale (defaults to main screen scale)
  /// - Returns: UIImage or nil if failed
  static func createImageFromData(
    _ data: Data,
    format: String? = nil,
    size: CGSize? = nil,
    color: UIColor? = nil,
    scale: CGFloat = UIScreen.main.scale
  ) -> UIImage? {
    // Detect format
    let detectedFormat = format ?? detectImageFormat(assetPath: nil, imageData: data)
    
    var image: UIImage?
    
    if detectedFormat == "svg" {
      let svgSize = size ?? CGSize(width: 24, height: 24)
      image = SVGImageLoader.shared.loadSVG(from: data, size: svgSize)
    } else {
      // Try as raster image
      image = UIImage(data: data, scale: scale)
    }
    
    // Apply tinting if color is provided
    if let img = image, let col = color, #available(iOS 13.0, *) {
      let targetSize = size ?? img.size
      let isSVG = detectedFormat == "svg"
      return tintImage(img, with: col, size: targetSize, isSVG: isSVG, scale: scale)
    }
    
    return image
  }
  
  // MARK: - Image Scaling
  
  /// Scales an image to target size
  /// - Parameters:
  ///   - image: Source image
  ///   - size: Target size
  ///   - scale: Image scale (defaults to source image scale)
  /// - Returns: Scaled UIImage or original if scaling fails
  static func scaleImage(_ image: UIImage, to size: CGSize, scale: CGFloat? = nil) -> UIImage? {
    // If already correct size, return original
    if image.size == size {
      return image
    }
    
    let imageScale = scale ?? image.scale
    UIGraphicsBeginImageContextWithOptions(size, false, imageScale)
    defer { UIGraphicsEndImageContext() }
    
    // Use UIImage.draw(in:) which handles coordinate system correctly
    image.draw(in: CGRect(origin: .zero, size: size))
    return UIGraphicsGetImageFromCurrentImageContext() ?? image
  }
  
  // MARK: - Image Tinting
  
  /// Applies a color tint to an image using mask-based approach
  /// - Parameters:
  ///   - image: Source image to tint
  ///   - color: Color to apply
  ///   - size: Target size for the tinted image (defaults to original size)
  ///   - isSVG: Whether the image is SVG (affects coordinate transformation)
  ///   - scale: Image scale (defaults to source image scale)
  /// - Returns: Tinted UIImage or original image if tinting fails
  @available(iOS 13.0, *)
  static func tintImage(
    _ image: UIImage,
    with color: UIColor,
    size: CGSize? = nil,
    isSVG: Bool = false,
    scale: CGFloat? = nil
  ) -> UIImage? {
    guard let cgImage = image.cgImage else {
      return image
    }
    
    let cgColor = color.cgColor
    
    let targetSize = size ?? image.size
    let imageScale = scale ?? image.scale
    
    // Scale image to target size first if needed
    var scaledCGImage: CGImage? = nil
    if image.size == targetSize {
      scaledCGImage = cgImage
    } else {
      UIGraphicsBeginImageContextWithOptions(targetSize, false, imageScale)
      defer { UIGraphicsEndImageContext() }
      // Use UIImage.draw(in:) which handles coordinate system correctly
      image.draw(in: CGRect(origin: .zero, size: targetSize))
      scaledCGImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    }
    
    guard let scaledImage = scaledCGImage else {
      return image
    }
    
    // Apply color tint using mask
    UIGraphicsBeginImageContextWithOptions(targetSize, false, imageScale)
    defer { UIGraphicsEndImageContext() }
    
    guard let context = UIGraphicsGetCurrentContext() else {
      return image
    }
    
    // Core Graphics uses bottom-left origin, but masks need to be flipped for UIKit (top-left origin)
    // SVG images from SVGKit are already flipped, so we need to flip them back
    // PNG/JPG images are correctly oriented, so we need to flip them for the mask
    if isSVG {
      // SVG: SVGKit renders with flipped coordinates, so we flip back
      context.translateBy(x: 0, y: targetSize.height)
      context.scaleBy(x: 1.0, y: -1.0)
    } else {
      // PNG/JPG: Need to flip for mask (Core Graphics uses bottom-left origin)
      context.translateBy(x: 0, y: targetSize.height)
      context.scaleBy(x: 1.0, y: -1.0)
    }
    
    context.clip(to: CGRect(origin: .zero, size: targetSize), mask: scaledImage)
    context.setFillColor(cgColor)
    context.fill(CGRect(origin: .zero, size: targetSize))
    
    return UIGraphicsGetImageFromCurrentImageContext() ?? image
  }
  
  // MARK: - Complete Image Loading with Tinting
  
  /// Loads and optionally tints an image from asset path (all-in-one function)
  /// This is a convenience method that combines format detection, loading, and tinting
  /// - Parameters:
  ///   - assetPath: Flutter asset path
  ///   - iconSize: Optional icon size (will create CGSize from this)
  ///   - iconColor: Optional ARGB color integer to tint the image
  ///   - providedFormat: Optional format string
  ///   - scale: Image scale (defaults to main screen scale)
  /// - Returns: UIImage or nil if failed
  static func loadAndTintImage(
    from assetPath: String,
    iconSize: CGFloat? = nil,
    iconColor: Int? = nil,
    providedFormat: String? = nil,
    scale: CGFloat = UIScreen.main.scale
  ) -> UIImage? {
    let detectedFormat = detectImageFormat(assetPath: assetPath, providedFormat: providedFormat)
    let size: CGSize?
    
    if let iconSize = iconSize {
      size = CGSize(width: iconSize, height: iconSize)
    } else {
      size = nil
    }
    
    let color: UIColor?
    if let argb = iconColor {
      color = colorFromARGB(argb)
    } else {
      color = nil
    }
    
    return loadFlutterAsset(assetPath, size: size, format: detectedFormat, color: color, scale: scale)
  }
  
  /// Creates and optionally tints an image from raw data (all-in-one function)
  /// - Parameters:
  ///   - data: Image data bytes
  ///   - iconSize: Optional icon size (will create CGSize from this)
  ///   - iconColor: Optional ARGB color integer to tint the image
  ///   - providedFormat: Optional format string
  ///   - scale: Image scale (defaults to main screen scale)
  /// - Returns: UIImage or nil if failed
  static func createAndTintImage(
    from data: Data,
    iconSize: CGFloat? = nil,
    iconColor: Int? = nil,
    providedFormat: String? = nil,
    scale: CGFloat = UIScreen.main.scale
  ) -> UIImage? {
    let detectedFormat = detectImageFormat(assetPath: nil, providedFormat: providedFormat, imageData: data)
    let size: CGSize?
    
    if let iconSize = iconSize {
      size = CGSize(width: iconSize, height: iconSize)
    } else {
      size = nil
    }
    
    let color: UIColor?
    if let argb = iconColor {
      color = colorFromARGB(argb)
    } else {
      color = nil
    }
    
    return createImageFromData(data, format: detectedFormat, size: size, color: color, scale: scale)
  }

  // MARK: - Template Suitability

  /// Whether every opaque pixel in `image` shares one colour.
  ///
  /// Used to decide if an uncoloured `imageAsset` may be rendered as a
  /// template. Template rendering keeps only the alpha channel, so it is
  /// lossless for single-colour artwork (a black glyph, a grey stroked SVG)
  /// and destructive for anything else — a four-colour logo would flatten to
  /// a silhouette. Single-colour art is the case that needs adapting to
  /// Liquid Glass; multi-colour art is deliberate and must be left alone.
  ///
  /// Only near-opaque pixels are compared, so antialiased edges — which vary
  /// in alpha but not in colour — do not count as a second colour. The scan
  /// is capped at a 32x32 sample grid and returns as soon as it finds a
  /// second colour, so cost stays flat regardless of source resolution.
  static func isEffectivelyMonochrome(_ image: UIImage) -> Bool {
    guard let cgImage = image.cgImage else {
      // No bitmap to inspect (e.g. a CIImage-backed UIImage). Leave the image
      // alone rather than guessing at its colours. SVGs do reach here with a
      // cgImage — SVGKit rasterises through a CGContext.
      return false
    }

    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return false }

    // Render into a known layout — the source may be any colour space,
    // bit depth, or alpha arrangement.
    let sampleWidth = min(width, 32)
    let sampleHeight = min(height, 32)
    let bytesPerRow = sampleWidth * 4
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * sampleHeight)

    guard let context = CGContext(
      data: &buffer,
      width: sampleWidth,
      height: sampleHeight,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      // Straight (non-premultiplied) alpha keeps edge pixels at their true
      // colour instead of fading them toward black.
      bitmapInfo: CGImageAlphaInfo.last.rawValue
    ) else {
      return false
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

    var found: (UInt8, UInt8, UInt8)? = nil
    // Tolerance absorbs resampling noise without merging distinct hues.
    let tolerance: Int = 12

    for y in 0..<sampleHeight {
      let row = y * bytesPerRow
      for x in 0..<sampleWidth {
        let i = row + x * 4
        guard buffer[i + 3] >= 250 else { continue }
        let pixel = (buffer[i], buffer[i + 1], buffer[i + 2])
        guard let first = found else {
          found = pixel
          continue
        }
        if abs(Int(pixel.0) - Int(first.0)) > tolerance
            || abs(Int(pixel.1) - Int(first.1)) > tolerance
            || abs(Int(pixel.2) - Int(first.2)) > tolerance {
          return false
        }
      }
    }

    // No opaque pixel at all (a fully translucent image) is not something we
    // should reinterpret as a template.
    return found != nil
  }

  /// Returns `image` as a template when that is lossless, otherwise unchanged.
  ///
  /// Callers use this for artwork supplied without an explicit colour, so the
  /// control's tint — and on iOS 26 the glass material's automatic foreground
  /// adaptation — can apply. See `isEffectivelyMonochrome(_:)` for why
  /// multi-colour artwork is left as-is.
  static func templatedIfMonochrome(_ image: UIImage?) -> UIImage? {
    guard let image = image else { return nil }
    guard isEffectivelyMonochrome(image) else { return image }
    return image.withRenderingMode(.alwaysTemplate)
  }
}

