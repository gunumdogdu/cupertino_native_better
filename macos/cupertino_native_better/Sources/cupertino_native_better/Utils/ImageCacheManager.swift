import AppKit

/// Cache of the images `ImageUtils` loads from Flutter assets and raw bytes,
/// by source, size and colour. The AppKit counterpart of the iOS
/// `ImageCacheManager`; SVGs are cached here too, as `NSImage` reads them.
final class ImageCacheManager {
  static let shared = ImageCacheManager()

  private let cache = NSCache<NSString, NSImage>()

  private init() {
    cache.countLimit = 100
    cache.totalCostLimit = 50 * 1024 * 1024
    cache.name = "com.cupertino_native_better.ImageCache"
  }

  func cacheKey(for assetPath: String, size: CGSize?, color: NSColor?) -> String {
    "asset_\(assetPath)_\(Self.describe(size))_\(Self.describe(color))"
  }

  func cacheKey(for data: Data, size: CGSize?, color: NSColor?) -> String {
    "data_\(data.count)_\(Self.fnv1a(data))_\(Self.describe(size))_\(Self.describe(color))"
  }

  /// A hash of every byte: `Data.hashValue` reads only the first bytes, which
  /// two PNGs of the same size can share.
  private static func fnv1a(_ data: Data) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in data {
      hash ^= UInt64(byte)
      hash = hash &* 0x100000001b3
    }
    return hash
  }

  /// The image cached under `key`, or the one `creator` makes, which is then
  /// cached. Images are immutable once cached: callers copy before changing
  /// one.
  func image(for key: String, creator: () -> NSImage?) -> NSImage? {
    if let cached = cache.object(forKey: key as NSString) { return cached }
    guard let image = creator() else { return nil }
    let cost = Int(image.size.width * image.size.height * 4 * 4)
    cache.setObject(image, forKey: key as NSString, cost: cost)
    return image
  }

  func clearCache() {
    cache.removeAllObjects()
  }

  private static func describe(_ size: CGSize?) -> String {
    guard let s = size else { return "original" }
    return "\(s.width)x\(s.height)"
  }

  private static func describe(_ color: NSColor?) -> String {
    guard let c = color?.usingColorSpace(.sRGB) else { return "none" }
    return String(format: "%.3f,%.3f,%.3f,%.3f", c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
  }
}
