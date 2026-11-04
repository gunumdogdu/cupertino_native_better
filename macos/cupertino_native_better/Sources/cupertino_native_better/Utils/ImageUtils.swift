import AppKit
import FlutterMacOS

/// Image loading for the macOS views: Flutter assets and raw bytes (PNG, JPG,
/// GIF, SVG), custom icons rendered by Flutter, SF Symbols, tinting and
/// template detection. The AppKit counterpart of the iOS `ImageUtils`.
///
/// SVG needs no third-party parser here: `NSImage` reads SVG itself (the
/// system's CoreSVG), keeps it as a vector representation and draws it sharp
/// at any size. Where a macOS release cannot read SVG, the image comes back
/// nil and the view shows nothing, as for a missing asset.
enum ImageUtils {

  // MARK: - Colours

  /// An sRGB colour from Flutter's 0xAARRGGBB integer.
  static func colorFromARGB(_ argb: Int) -> NSColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
  }

  // MARK: - Format detection

  /// "svg", "png", "jpg", "gif" or nil: the format Flutter sent, else the
  /// extension of `assetPath`, else the leading bytes of `imageData`.
  static func detectImageFormat(assetPath: String?, providedFormat: String? = nil, imageData: Data? = nil) -> String? {
    if let format = providedFormat?.lowercased(), !format.isEmpty {
      return format == "jpeg" ? "jpg" : format
    }
    if let path = assetPath?.lowercased() {
      if path.hasSuffix(".svg") { return "svg" }
      if path.hasSuffix(".png") { return "png" }
      if path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") { return "jpg" }
      if path.hasSuffix(".gif") { return "gif" }
    }
    if let data = imageData, data.count >= 4 {
      let b = [UInt8](data.prefix(4))
      if b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 { return "png" }
      if b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF { return "jpg" }
      if b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 { return "gif" }
      if let head = String(data: data.prefix(1024), encoding: .utf8),
         head.contains("<svg") {
        return "svg"
      }
    }
    return nil
  }

  // MARK: - Flutter assets

  /// The file of the Flutter asset `assetPath` in the app bundle. On macOS
  /// the assets live in `App.framework/Resources/flutter_assets`, and the
  /// lookup key is relative to that framework's bundle.
  static func flutterAssetFilePath(_ assetPath: String) -> String? {
    let key = FlutterDartProject.lookupKey(forAsset: assetPath)
    let appBundle = Bundle(identifier: FlutterDartProject.defaultBundleIdentifier())
    for bundle in [appBundle, Bundle.main].compactMap({ $0 }) {
      if let path = bundle.path(forResource: key, ofType: nil) { return path }
    }
    // A host app that embeds the Flutter framework under another name.
    if let frameworks = Bundle.main.privateFrameworksPath {
      let path = (frameworks as NSString)
        .appendingPathComponent("App.framework/Resources/flutter_assets/\(assetPath)")
      if FileManager.default.fileExists(atPath: path) { return path }
    }
    return nil
  }

  /// The Flutter asset `assetPath` at `size` points, tinted with `color` when
  /// given. Cached by path, size and colour.
  static func loadFlutterAsset(
    _ assetPath: String,
    size: CGSize? = nil,
    format: String? = nil,
    color: NSColor? = nil
  ) -> NSImage? {
    let key = ImageCacheManager.shared.cacheKey(for: assetPath, size: size, color: color)
    return ImageCacheManager.shared.image(for: key) {
      guard let path = flutterAssetFilePath(assetPath),
            let image = NSImage(contentsOfFile: path) else {
        logMissing("asset \(assetPath)", format: detectImageFormat(assetPath: assetPath, providedFormat: format))
        return nil
      }
      return prepared(image, size: size, color: color)
    }
  }

  /// An image from raw bytes at `size` points, tinted with `color` when given.
  static func createImageFromData(
    _ data: Data,
    format: String? = nil,
    size: CGSize? = nil,
    color: NSColor? = nil
  ) -> NSImage? {
    let key = ImageCacheManager.shared.cacheKey(for: data, size: size, color: color)
    return ImageCacheManager.shared.image(for: key) {
      guard let image = NSImage(data: data) else {
        logMissing("image data (\(data.count) bytes)", format: detectImageFormat(assetPath: nil, providedFormat: format, imageData: data))
        return nil
      }
      return prepared(image, size: size, color: color)
    }
  }

  /// A custom icon (`IconData`) Flutter rendered to PNG at the screen's pixel
  /// ratio, as a template at `pointSize` points so the control colours it.
  static func customIconImage(_ data: Data, pointSize: CGFloat?) -> NSImage? {
    guard let image = NSImage(data: data) else { return nil }
    if let pointSize = pointSize, pointSize > 0,
       let rep = image.representations.first, rep.pixelsHigh > 0 {
      // Keep the aspect ratio of the glyph Flutter drew.
      let aspect = CGFloat(rep.pixelsWide) / CGFloat(rep.pixelsHigh)
      image.size = CGSize(width: pointSize * aspect, height: pointSize)
    }
    image.isTemplate = true
    return image
  }

  /// One image from whichever source a view received, by the iOS priority:
  /// raw bytes, then an asset path, then a custom icon. A source without an
  /// explicit colour is returned as a template when it is single-coloured,
  /// so the control's foreground colour applies.
  static func image(
    assetPath: String?,
    imageData: Data?,
    format: String?,
    customIconBytes: Data?,
    size: CGFloat?,
    color: NSColor?
  ) -> NSImage? {
    let target = size.flatMap { $0 > 0 ? CGSize(width: $0, height: $0) : nil }
    var image: NSImage? = nil
    if let data = imageData {
      image = createImageFromData(data, format: format, size: target, color: color)
    } else if let path = assetPath, !path.isEmpty {
      image = loadFlutterAsset(path, size: target, format: format, color: color)
    } else if let bytes = customIconBytes {
      image = customIconImage(bytes, pointSize: size)
      if let image = image, let color = color { return tinted(image, with: color) }
      return image
    }
    if color == nil { image = templatedIfMonochrome(image) }
    return image
  }

  // MARK: - Sizing and tinting

  /// `image` drawn at `size` (its aspect ratio kept inside that box), then
  /// tinted with `color`.
  static func prepared(_ image: NSImage, size: CGSize?, color: NSColor?) -> NSImage {
    var result = image
    if let size = size {
      result = fitted(image, in: size)
    }
    if let color = color {
      result = tinted(result, with: color)
    }
    return result
  }

  /// A copy of `image` whose point size fits `box`, keeping its aspect
  /// ratio. Vector (SVG, PDF) representations stay vector.
  static func fitted(_ image: NSImage, in box: CGSize) -> NSImage {
    let source = image.size
    guard source.width > 0, source.height > 0 else { return image }
    let scale = min(box.width / source.width, box.height / source.height)
    let copy = (image.copy() as? NSImage) ?? image
    copy.size = CGSize(width: source.width * scale, height: source.height * scale)
    return copy
  }

  /// `image` with every opaque pixel painted `color`, as a resolution-
  /// independent image (drawn again at each backing scale).
  static func tinted(_ image: NSImage, with color: NSColor) -> NSImage {
    let out = NSImage(size: image.size, flipped: false) { rect in
      image.draw(in: rect)
      color.set()
      rect.fill(using: .sourceAtop)
      return true
    }
    out.isTemplate = false
    return out
  }

  // MARK: - SF Symbols

  /// An SF Symbol configured as Flutter asked: point size, rendering mode,
  /// colour and palette. Without a mode, a colour paints the symbol in that
  /// colour; without either, the symbol stays a template for the control to
  /// colour.
  static func symbolImage(
    name: String,
    size: CGFloat?,
    color: NSColor?,
    mode: String?,
    palette: [NSColor] = [],
    weight: NSFont.Weight = .regular,
    accessibilityDescription: String? = nil
  ) -> NSImage? {
    guard var image = NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription) else {
      return nil
    }
    if let size = size, size > 0 {
      image = image.withSymbolConfiguration(.init(pointSize: size, weight: weight)) ?? image
    }
    switch mode {
    case "hierarchical":
      if let c = color {
        image = image.withSymbolConfiguration(.init(hierarchicalColor: c)) ?? image
      }
    case "palette":
      if !palette.isEmpty {
        image = image.withSymbolConfiguration(.init(paletteColors: palette)) ?? image
      } else if let c = color {
        image = image.withSymbolConfiguration(.init(paletteColors: [c])) ?? image
      }
    case "multicolor":
      image = image.withSymbolConfiguration(.preferringMulticolor()) ?? image
    default:
      // Monochrome, or no mode: one colour for the whole symbol.
      if let c = color {
        image = image.withSymbolConfiguration(.init(paletteColors: [c])) ?? image
      }
    }
    return image
  }

  // MARK: - Template suitability

  /// Whether every opaque pixel of `image` shares one colour, so rendering it
  /// as a template (alpha only) loses nothing. See the iOS `ImageUtils`.
  static func isEffectivelyMonochrome(_ image: NSImage) -> Bool {
    // Drawn into a fixed 48 px square rather than read at the image's own
    // size: an 18 pt line icon at 1x has too few fully opaque pixels to judge.
    let side = 48
    let bytesPerRow = side * 4
    var buffer = [UInt8](repeating: 0, count: bytesPerRow * side)
    let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
      guard let context = CGContext(
        data: raw.baseAddress,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else { return false }
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
      image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
      NSGraphicsContext.restoreGraphicsState()
      return true
    }
    guard drawn else { return false }

    var found: (Int, Int, Int)? = nil
    let tolerance = 12
    for y in 0..<side {
      for x in 0..<side {
        let i = y * bytesPerRow + x * 4
        // Near-opaque pixels only, so premultiplied values equal the colour
        // and antialiased edges do not count as a second colour.
        guard buffer[i + 3] >= 250 else { continue }
        let pixel = (Int(buffer[i]), Int(buffer[i + 1]), Int(buffer[i + 2]))
        guard let first = found else { found = pixel; continue }
        if abs(pixel.0 - first.0) > tolerance
            || abs(pixel.1 - first.1) > tolerance
            || abs(pixel.2 - first.2) > tolerance {
          return false
        }
      }
    }
    return found != nil
  }

  /// `image` as a template when that is lossless, otherwise unchanged.
  static func templatedIfMonochrome(_ image: NSImage?) -> NSImage? {
    guard let image = image else { return nil }
    guard !image.isTemplate else { return image }
    guard isEffectivelyMonochrome(image) else { return image }
    let copy = (image.copy() as? NSImage) ?? image
    copy.isTemplate = true
    return copy
  }

  // MARK: - Diagnostics

  private static var loggedMissing = Set<String>()

  private static func logMissing(_ what: String, format: String?) {
    guard !loggedMissing.contains(what) else { return }
    loggedMissing.insert(what)
    if format == "svg", !NSImage.imageTypes.contains("public.svg-image") {
      NSLog("[cupertino_native_better] \(what): this macOS cannot read SVG with NSImage; use PNG or an SF Symbol")
    } else {
      NSLog("[cupertino_native_better] could not load \(what)")
    }
  }
}
