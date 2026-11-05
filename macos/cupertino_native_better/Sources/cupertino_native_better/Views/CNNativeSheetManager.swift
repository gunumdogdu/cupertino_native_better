import Cocoa
import FlutterMacOS
import SwiftUI

/// `CNNativeSheet` on macOS: the sheet's pages in the window's inspector
/// (`MacSplitWindow`), the panel at the trailing side of a Mac window, driven
/// over `cn_native_sheet` with the same calls and events as on iOS.
///
/// The page model is the iOS one: a title, toolbar buttons and `CNListItem`
/// rows per page, and a segmented switcher at the top of the inspector when
/// there is more than one page. Detents have no Mac meaning. A dismissible
/// sheet has a close button and can be closed by dragging the inspector's
/// divider; either reports `onDismissed`. A sheet that is not dismissible
/// stays open until `CNNativeSheet.dismiss()`.
final class CNNativeSheetManager: NSObject {
  static let shared = CNNativeSheetManager()

  private var channel: FlutterMethodChannel?
  private var store: MacSheetStore?
  private var host: NSHostingController<MacSheetInspector>?

  func setup(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "cn_native_sheet", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    // A hot restart starts a Dart side that knows nothing of the sheet: the
    // inspector goes away.
    MacEngineRestart.observe(messenger)
    NotificationCenter.default.addObserver(
      self, selector: #selector(engineRestarted),
      name: MacEngineRestart.notification, object: nil)
  }

  @objc private func engineRestarted() {
    close(notify: false)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "show":
      guard let args else {
        result(FlutterError(code: "invalid_args", message: "Expected a map", details: nil))
        return
      }
      result(present(MacSheetConfig(args: args)))

    case "dismiss":
      close(notify: false)
      result(nil)

    case "setDetent":
      // An inspector has one height: the window's.
      result(nil)

    case "setSelectedPage":
      if let index = args?["index"] as? Int, let store, store.pages.indices.contains(index) {
        store.selection = index
      }
      result(nil)

    case "setItems":
      if let page = args?["page"] as? Int, let items = args?["items"] as? [[String: Any]] {
        store?.setItems(page: page, items: MacListItem.parse(items))
      }
      result(nil)

    case "setBadgeCounts":
      if let badges = args?["badgeCounts"] as? [Any?] {
        store?.setBadges(badges.map { $0 as? Int })
      }
      result(nil)

    case "setBrightness":
      if let isDark = args?["isDark"] as? Bool, store != nil {
        MacSplitWindow.shared.setAppearance(MacFlutterWindow.appearance(isDark: isDark), for: .inspector)
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func present(_ config: MacSheetConfig) -> Bool {
    guard !config.pages.isEmpty else { return false }
    let store = MacSheetStore(config: config)
    let onEvent: (String, [String: Any]?) -> Void = { [weak self] name, payload in
      self?.channel?.invokeMethod(name, arguments: payload)
    }
    let view = MacSheetInspector(
      store: store, onEvent: onEvent,
      onClose: config.dismissible ? { [weak self] in self?.close(notify: true) } : nil)
    // show() again (or after a hot restart) replaces the content in place.
    // The hosting controller is kept from one show() to the next.
    let host = self.host ?? NSHostingController(rootView: view)
    host.rootView = view
    // The split view sizes the inspector, not the content's ideal size.
    if #available(macOS 13.0, *) { host.sizingOptions = [] }
    let shown = MacSplitWindow.shared.setInspector(
      host, canCollapse: config.dismissible,
      onCollapse: { [weak self] in self?.close(notify: true) })
    guard shown else { return false }
    MacSplitWindow.shared.setAppearance(MacFlutterWindow.appearance(isDark: config.isDark), for: .inspector)
    self.store = store
    self.host = host
    return true
  }

  private func close(notify: Bool) {
    guard store != nil else { return }
    store = nil
    MacSplitWindow.shared.setInspector(nil)
    if notify { channel?.invokeMethod("onDismissed", arguments: nil) }
  }
}

// MARK: - Configuration

struct MacSheetConfig {
  struct Button {
    let id: String
    let symbol: String?
    let label: String?
  }
  struct Page {
    let title: String
    let symbol: String?
    let activeSymbol: String?
    var badge: Int?
    let buttons: [Button]
    var items: [MacListItem]
  }

  let pages: [Page]
  let dismissible: Bool
  let tint: Color?
  let isDark: Bool?
  let selectedPage: Int

  init(args: [String: Any]) {
    pages = (args["pages"] as? [[String: Any]] ?? []).map { p in
      Page(
        title: p["title"] as? String ?? "",
        symbol: p["sfSymbol"] as? String,
        activeSymbol: p["activeSfSymbol"] as? String,
        badge: p["badgeCount"] as? Int,
        buttons: (p["buttons"] as? [[String: Any]] ?? []).map { b in
          Button(id: b["id"] as? String ?? "", symbol: b["sfSymbol"] as? String, label: b["label"] as? String)
        },
        items: MacListItem.parse(p["items"] as? [[String: Any]] ?? []))
    }
    dismissible = args["dismissible"] as? Bool ?? true
    tint = (args["tint"] as? Int).map { Color(ImageUtils.colorFromARGB($0)) }
    isDark = args["isDark"] as? Bool
    selectedPage = args["selectedPage"] as? Int ?? 0
  }
}

final class MacSheetStore: ObservableObject {
  @Published var pages: [MacSheetConfig.Page]
  @Published var selection: Int
  let tint: Color?

  init(config: MacSheetConfig) {
    pages = config.pages
    selection = config.pages.indices.contains(config.selectedPage) ? config.selectedPage : 0
    tint = config.tint
  }

  func setItems(page: Int, items: [MacListItem]) {
    guard pages.indices.contains(page) else { return }
    pages[page].items = items
  }

  func setBadges(_ badges: [Int?]) {
    var updated = pages
    for (i, badge) in badges.enumerated() where i < updated.count {
      updated[i].badge = badge
    }
    pages = updated
  }
}

// MARK: - The inspector

/// The sheet in the inspector: a segmented switcher of the pages (more than
/// one), the selected page's title with its buttons and the close button,
/// and its rows.
struct MacSheetInspector: View {
  @ObservedObject var store: MacSheetStore
  let onEvent: (String, [String: Any]?) -> Void
  let onClose: (() -> Void)?

  private var pageSelection: Binding<Int> {
    Binding(
      get: { store.selection },
      set: { newValue in
        guard newValue != store.selection else { return }
        store.selection = newValue
        onEvent("onPageSelected", ["index": newValue])
      })
  }

  var body: some View {
    let index = store.pages.indices.contains(store.selection) ? store.selection : 0
    VStack(alignment: .leading, spacing: 0) {
      if store.pages.count > 1 {
        switcher
          .padding(.horizontal, 12)
          .padding(.top, 10)
      }
      if store.pages.indices.contains(index) {
        header(store.pages[index], index: index)
        rows(store.pages[index], index: index)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .tint(store.tint)
    .accentColor(store.tint)
  }

  /// The pages as an `NSSegmentedControl`: each page's symbol (or title
  /// when it has none) and its badge count beside it; the title is the
  /// segment's tooltip and VoiceOver label.
  private var switcher: some View {
    MacPageSegments(
      segments: store.pages.enumerated().map { i, page in
        MacPageSegments.Segment(
          title: page.title,
          symbol: i == store.selection ? (page.activeSymbol ?? page.symbol) : page.symbol,
          badge: (page.badge ?? 0) > 0 ? page.badge : nil)
      },
      selection: pageSelection)
    .frame(maxWidth: .infinity)
  }

  private func header(_ page: MacSheetConfig.Page, index: Int) -> some View {
    HStack(alignment: .center, spacing: 6) {
      Text(page.title)
        .font(.title2.bold())
        .lineLimit(1)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: 8)
      ForEach(page.buttons.indices, id: \.self) { b in
        let button = page.buttons[b]
        SwiftUI.Button {
          onEvent("onButtonTap", ["page": index, "id": button.id])
        } label: {
          if let symbol = button.symbol {
            Image(systemName: symbol)
          } else {
            Text(button.label ?? "")
          }
        }
        .buttonStyle(.borderless)
        .help(button.label ?? "")
        .accessibilityLabel(Text(button.label ?? button.symbol ?? ""))
      }
      if let onClose {
        SwiftUI.Button(action: onClose) {
          Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
        .help("Close")
        .accessibilityLabel(Text("Close"))
      }
    }
    .font(.system(size: 15))
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 6)
  }

  @ViewBuilder
  private func rows(_ page: MacSheetConfig.Page, index: Int) -> some View {
    if page.items.isEmpty {
      Spacer()
    } else {
      List {
        ForEach(page.items.indices, id: \.self) { i in
          SwiftUI.Button {
            onEvent("onItemTap", ["page": index, "index": i])
          } label: {
            MacListRow(item: page.items[i])
          }
          .buttonStyle(.plain)
        }
      }
      .listStyle(.sidebar)
    }
  }
}

/// The inspector's page switcher: AppKit's segmented control, which SwiftUI's
/// segmented picker cannot fill with a symbol and a count side by side.
struct MacPageSegments: NSViewRepresentable {
  struct Segment: Equatable {
    let title: String
    let symbol: String?
    let badge: Int?
  }

  let segments: [Segment]
  @Binding var selection: Int

  func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

  func makeNSView(context: Context) -> NSSegmentedControl {
    let control = NSSegmentedControl()
    control.trackingMode = .selectOne
    control.segmentDistribution = .fillEqually
    control.target = context.coordinator
    control.action = #selector(Coordinator.changed(_:))
    control.setAccessibilityLabel("Pages")
    control.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return control
  }

  func updateNSView(_ control: NSSegmentedControl, context: Context) {
    context.coordinator.selection = $selection
    if context.coordinator.segments != segments {
      context.coordinator.segments = segments
      control.segmentCount = segments.count
      for (i, segment) in segments.enumerated() {
        let image = segment.symbol.flatMap { Self.image(symbol: $0, segment: segment) }
        control.setImage(image, forSegment: i)
        control.setImageScaling(.scaleNone, forSegment: i)
        // A segment without a symbol shows its title and count as text.
        var label = image == nil ? segment.title : ""
        if image == nil, let badge = segment.badge { label += " \(badge)" }
        control.setLabel(label, forSegment: i)
        control.setToolTip(segment.title, forSegment: i)
        control.setWidth(0, forSegment: i)
      }
    }
    if control.selectedSegment != selection, segments.indices.contains(selection) {
      control.selectedSegment = selection
    }
  }

  /// The page's symbol, with its badge count drawn after it, as one
  /// template image: the segment tints both, and VoiceOver reads the page
  /// title and the count (a segment's own label would be read instead of
  /// the title).
  static func image(symbol: String, segment: Segment) -> NSImage? {
    let description = segment.badge.map { "\(segment.title), \($0)" } ?? segment.title
    guard let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: description) else {
      return nil
    }
    guard let badge = segment.badge else { return glyph }
    let text = NSAttributedString(
      string: "\(badge)",
      attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)])
    let textSize = text.size()
    let gap: CGFloat = 3
    let size = NSSize(
      width: ceil(glyph.size.width + gap + textSize.width),
      height: ceil(max(glyph.size.height, textSize.height)))
    let image = NSImage(size: size, flipped: false) { rect in
      glyph.draw(in: NSRect(
        x: 0, y: (rect.height - glyph.size.height) / 2,
        width: glyph.size.width, height: glyph.size.height))
      text.draw(at: NSPoint(
        x: glyph.size.width + gap, y: (rect.height - textSize.height) / 2))
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = description
    return image
  }

  final class Coordinator: NSObject {
    var selection: Binding<Int>
    var segments: [Segment] = []

    init(selection: Binding<Int>) { self.selection = selection }

    @objc func changed(_ sender: NSSegmentedControl) {
      if selection.wrappedValue != sender.selectedSegment {
        selection.wrappedValue = sender.selectedSegment
      }
    }
  }
}
