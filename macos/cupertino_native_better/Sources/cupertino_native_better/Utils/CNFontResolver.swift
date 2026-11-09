import AppKit
import CoreText
import FlutterMacOS

/// Resolves a font family a Flutter widget passes by name (`labelFontFamily`
/// and the like) to an `NSFont`, at a weight (#142, macOS).
///
/// A font declared under `fonts:` in `pubspec.yaml` is a Flutter asset that
/// AppKit doesn't know, so `NSFont(name:)` alone returned nil for it and the
/// view silently fell back to the system font. When AppKit doesn't know the
/// family, this reads Flutter's `FontManifest.json`, registers the family's
/// font files for the process (`CTFontManagerRegisterFontsForURL`, as the
/// image helpers resolve Flutter assets), and picks the face whose weight is
/// nearest the one asked for. A family AppKit does know (a font the app
/// bundles itself or a system family such as "Avenir Next") is matched by weight too.
///
/// A family found nowhere logs one line in debug builds and returns nil, so
/// the caller keeps its system font.
enum CNFontResolver {
  /// A registered face of a pubspec family.
  private struct Face {
    let name: String
    /// Flutter's weight, 100 to 900.
    let weight: Int
    let italic: Bool
  }

  /// The faces registered so far, by family as Flutter names it.
  private static var faces: [String: [Face]] = [:]
  /// Families looked up and not found, so the warning is logged once.
  private static var missing: Set<String> = []
  /// Flutter's font manifest: each family's font assets and their weights.
  private static var manifest: [String: [(asset: String, weight: Int, italic: Bool)]]?

  /// The font for [family] at [size] and [weight], or nil when the family
  /// can't be found.
  static func font(family: String, size: CGFloat, weight: NSFont.Weight? = nil, italic: Bool = false) -> NSFont? {
    let wanted = weight.map(flutterWeight) ?? 400
    // A family AppKit knows, or a PostScript / full font name.
    if NSFontManager.shared.availableMembers(ofFontFamily: family)?.isEmpty == false {
      return systemFamilyFont(family, size: size, weight: weight ?? .regular, italic: italic)
    }
    if weight == nil, let named = NSFont(name: family, size: size) { return named }
    // A pubspec family: register it once, then pick a face.
    if let face = pick(registeredFaces(of: family), weight: wanted, italic: italic),
       let font = NSFont(name: face.name, size: size) {
      return font
    }
    if let named = NSFont(name: family, size: size) { return named }
    if !missing.contains(family) {
      missing.insert(family)
      #if DEBUG
      NSLog("[cupertino_native_better] Font family '%@' was not found: it is neither known to AppKit nor declared under fonts: in pubspec.yaml. The system font is used instead.", family)
      #endif
    }
    return nil
  }

  /// AppKit's weight for Flutter's `FontWeight.value` (100 to 900), or nil.
  static func weight(fromFlutterValue value: Int?) -> NSFont.Weight? {
    guard var v = value else { return nil }
    if v >= 100 { v = min(max((v + 50) / 100 - 1, 0), 8) }
    switch v {
    case 0: return .ultraLight
    case 1: return .thin
    case 2: return .light
    case 3: return .regular
    case 4: return .medium
    case 5: return .semibold
    case 6: return .bold
    case 7: return .heavy
    case 8: return .black
    default: return nil
    }
  }

  // MARK: - Families AppKit knows

  private static func systemFamilyFont(_ family: String, size: CGFloat, weight: NSFont.Weight, italic: Bool) -> NSFont {
    var traits: [NSFontDescriptor.TraitKey: Any] = [.weight: weight]
    if italic { traits[.symbolic] = NSFontDescriptor.SymbolicTraits.italic.rawValue }
    let descriptor = NSFontDescriptor(fontAttributes: [.family: family, .traits: traits])
    return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
  }

  // MARK: - Families from pubspec.yaml

  private static func pick(_ faces: [Face], weight: Int, italic: Bool) -> Face? {
    guard !faces.isEmpty else { return nil }
    let styled = faces.filter { $0.italic == italic }
    let pool = styled.isEmpty ? faces : styled
    // Nearest weight; between two equally near, the heavier for a bold ask
    // and the lighter otherwise, as CSS font matching does.
    return pool.min { a, b in
      let da = abs(a.weight - weight), db = abs(b.weight - weight)
      if da != db { return da < db }
      return weight >= 500 ? a.weight > b.weight : a.weight < b.weight
    }
  }

  private static func registeredFaces(of family: String) -> [Face] {
    if let known = faces[family] { return known }
    var registered: [Face] = []
    for entry in manifestEntries(for: family) {
      guard let url = assetURL(entry.asset) else { continue }
      var error: Unmanaged<CFError>?
      // "Already registered" is fine: the app or another view did it.
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
      guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { continue }
      for descriptor in descriptors {
        guard let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else { continue }
        registered.append(Face(name: name, weight: entry.weight, italic: entry.italic))
      }
    }
    faces[family] = registered
    return registered
  }

  /// The manifest's fonts for [family], also when the manifest names it
  /// `packages/<package>/<family>`.
  private static func manifestEntries(for family: String) -> [(asset: String, weight: Int, italic: Bool)] {
    let all = loadManifest()
    if let exact = all[family] { return exact }
    let suffix = "/" + family
    return all.first { $0.key.hasPrefix("packages/") && $0.key.hasSuffix(suffix) }?.value ?? []
  }

  private static func loadManifest() -> [String: [(asset: String, weight: Int, italic: Bool)]] {
    if let manifest { return manifest }
    var result: [String: [(asset: String, weight: Int, italic: Bool)]] = [:]
    if let url = assetURL("FontManifest.json"),
       let data = try? Data(contentsOf: url),
       let families = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
      for family in families {
        guard let name = family["family"] as? String,
              let fonts = family["fonts"] as? [[String: Any]] else { continue }
        result[name] = fonts.compactMap { font in
          guard let asset = font["asset"] as? String else { return nil }
          let weight = (font["weight"] as? NSNumber)?.intValue ?? 400
          let italic = (font["style"] as? String) == "italic"
          return (asset, weight, italic)
        }
      }
    }
    manifest = result
    return result
  }

  private static func assetURL(_ asset: String) -> URL? {
    ImageUtils.flutterAssetFilePath(asset).map { URL(fileURLWithPath: $0) }
  }

  private static func flutterWeight(_ weight: NSFont.Weight) -> Int {
    switch weight {
    case .ultraLight: return 100
    case .thin: return 200
    case .light: return 300
    case .regular: return 400
    case .medium: return 500
    case .semibold: return 600
    case .bold: return 700
    case .heavy: return 800
    case .black: return 900
    default: return weight.rawValue > 0 ? 700 : 400
    }
  }
}
