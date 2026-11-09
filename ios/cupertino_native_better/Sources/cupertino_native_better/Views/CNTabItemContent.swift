import Flutter
import UIKit

/// The items `CNTabBar` sends (in its creation params and `setItems`), read
/// the way the plain bar reads them: an image asset first, then a custom
/// icon, then an SF Symbol, each at the item's icon size, plus the badge and
/// the accessibility name. The bar with a search tab builds its items from
/// this, so its items look like the plain bar's (#136).
struct CNTabItemContent {
  var labels: [String] = []
  var symbols: [String] = []
  var activeSymbols: [String] = []
  var badges: [String] = []
  var customIconBytes: [Data?] = []
  var activeCustomIconBytes: [Data?] = []
  var imageAssetPaths: [String] = []
  var activeImageAssetPaths: [String] = []
  var imageAssetData: [Data?] = []
  var activeImageAssetData: [Data?] = []
  var imageAssetFormats: [String] = []
  var activeImageAssetFormats: [String] = []
  var sizes: [CGFloat?] = []
  /// `CNTabBarItem.semanticLabel` per item ("" for none).
  var semanticLabels: [String] = []
  var iconScale: CGFloat = UIScreen.main.scale

  init() {}

  init(_ dict: [String: Any]) {
    labels = (dict["labels"] as? [String]) ?? []
    symbols = (dict["sfSymbols"] as? [String]) ?? []
    activeSymbols = (dict["activeSfSymbols"] as? [String]) ?? []
    badges = (dict["badges"] as? [Any] ?? []).map { ($0 as? String) ?? "" }
    customIconBytes = Self.bytes(dict["customIconBytes"])
    activeCustomIconBytes = Self.bytes(dict["activeCustomIconBytes"])
    imageAssetPaths = (dict["imageAssetPaths"] as? [Any] ?? []).map { ($0 as? String) ?? "" }
    activeImageAssetPaths = (dict["activeImageAssetPaths"] as? [Any] ?? []).map { ($0 as? String) ?? "" }
    imageAssetData = Self.bytes(dict["imageAssetData"])
    activeImageAssetData = Self.bytes(dict["activeImageAssetData"])
    imageAssetFormats = (dict["imageAssetFormats"] as? [Any] ?? []).map { ($0 as? String) ?? "" }
    activeImageAssetFormats = (dict["activeImageAssetFormats"] as? [Any] ?? []).map { ($0 as? String) ?? "" }
    sizes = (dict["sfSymbolSizes"] as? [Any] ?? []).map {
      guard let n = $0 as? NSNumber, n.doubleValue > 0 else { return nil }
      return CGFloat(n.doubleValue)
    }
    semanticLabels = (dict["semanticLabels"] as? [Any] ?? []).map { ($0 as? String) ?? "" }
    if let scale = dict["iconScale"] as? NSNumber { iconScale = CGFloat(truncating: scale) }
  }

  private static func bytes(_ value: Any?) -> [Data?] {
    (value as? [Any] ?? []).map { ($0 as? FlutterStandardTypedData)?.data }
  }

  var count: Int { max(labels.count, symbols.count) }

  func title(at i: Int) -> String? {
    i < labels.count && !labels[i].isEmpty ? labels[i] : nil
  }

  func badge(at i: Int) -> String? {
    i < badges.count ? badges[i] : nil
  }

  func semanticLabel(at i: Int) -> String? {
    i < semanticLabels.count && !semanticLabels[i].isEmpty ? semanticLabels[i] : nil
  }

  /// The item's image and selected image, in the plain bar's order.
  func images(at i: Int) -> (image: UIImage?, selected: UIImage?) {
    let size = i < sizes.count ? sizes[i] : nil
    let box = size.map { CGSize(width: $0, height: $0) }
    let image = pickImage(
      at: i, data: imageAssetData, formats: imageAssetFormats, paths: imageAssetPaths,
      custom: customIconBytes, symbols: symbols, size: size, box: box)
    let selected = pickImage(
      at: i, data: activeImageAssetData, formats: activeImageAssetFormats, paths: activeImageAssetPaths,
      custom: activeCustomIconBytes, symbols: activeSymbols, size: size, box: box)
    return (image, selected ?? image)
  }

  private func pickImage(
    at i: Int, data: [Data?], formats: [String], paths: [String], custom: [Data?],
    symbols: [String], size: CGFloat?, box: CGSize?
  ) -> UIImage? {
    if i < data.count, let bytes = data[i] {
      let format = i < formats.count && !formats[i].isEmpty ? formats[i] : nil
      return CupertinoTabBarPlatformView.createImageFromData(bytes, format: format, scale: iconScale, size: box)
    }
    if i < paths.count, !paths[i].isEmpty {
      return CupertinoTabBarPlatformView.loadFlutterAsset(paths[i], size: box)
    }
    if i < custom.count, let bytes = custom[i] {
      return UIImage(data: bytes, scale: iconScale)?.withRenderingMode(.alwaysTemplate)
    }
    if i < symbols.count, !symbols[i].isEmpty {
      if let size {
        return UIImage(systemName: symbols[i], withConfiguration: UIImage.SymbolConfiguration(pointSize: size))
      }
      return UIImage(systemName: symbols[i])
    }
    return nil
  }
}
