import Cocoa
import FlutterMacOS
import SwiftUI

/// A row of a native sidebar: a title, an SF Symbol or an image (each with
/// a variant for the selected row), and a badge.
struct MacSidebarRow: Identifiable {
  /// The row's index across all sections, top to bottom; what the
  /// selection and the callbacks use.
  let id: Int
  var title: String
  var symbol: String?
  var activeSymbol: String?
  var image: NSImage?
  var activeImage: NSImage?
  /// The badge text; `MacSidebarRow.dotBadge` for a dot without a count.
  var badge: String?

  /// What `CNTabBarItem.dotBadge` sends: a dot instead of a count.
  static let dotBadge = "\u{200B}"
}

/// A group of sidebar rows under an optional header.
struct MacSidebarSection: Identifiable {
  let id: Int
  var title: String?
  var rows: [MacSidebarRow]
}

/// What a native sidebar shows; SwiftUI redraws on every change.
final class MacSidebarModel: ObservableObject {
  @Published var sections: [MacSidebarSection] = []
  /// The selected row's index, or nil when no row is selected (a sidebar
  /// whose search is active).
  @Published var selection: Int?
  @Published var tint: Color?
  /// Icons only, each row's title as its tooltip and VoiceOver label: the
  /// narrow rail of `CNTabRail`.
  @Published var iconsOnly = false
  /// A search field at the top of the sidebar (`CNTabBarNative`'s search
  /// tab), and its text.
  @Published var hasSearch = false
  @Published var searchPrompt = "Search"
  @Published var query = ""

  /// The user picked a row (not called for programmatic changes).
  var onSelect: ((Int) -> Void)?
  /// The user edited the search text.
  var onQuery: ((String) -> Void)?

  /// Every row's index, top to bottom.
  var rowCount: Int { sections.reduce(0) { $0 + $1.rows.count } }

  /// Sections built from flat rows, numbering them across sections.
  static func sections(from data: [[String: Any]]) -> [MacSidebarSection] {
    var next = 0
    return data.enumerated().map { s, section in
      let rows = (section["items"] as? [[String: Any]] ?? []).map { item -> MacSidebarRow in
        defer { next += 1 }
        return MacSidebarModel.row(next, from: item)
      }
      let title = section["title"] as? String
      return MacSidebarSection(id: s, title: title?.isEmpty == false ? title : nil, rows: rows)
    }
  }

  /// A row from a map with `title`, `sfSymbol`, `activeSfSymbol`, `image` /
  /// `activeImage` (`path`, `data`, `format`), `iconBytes` /
  /// `activeIconBytes` (a custom icon Flutter rendered) and `badge`.
  static func row(_ index: Int, from item: [String: Any]) -> MacSidebarRow {
    let image = loadImage(item["image"] as? [String: Any], iconBytes: item["iconBytes"])
    let activeImage = loadImage(item["activeImage"] as? [String: Any], iconBytes: item["activeIconBytes"])
    let symbol = item["sfSymbol"] as? String
    let active = item["activeSfSymbol"] as? String
    let badge = item["badge"] as? String
    return MacSidebarRow(
      id: index,
      title: item["title"] as? String ?? "",
      symbol: symbol?.isEmpty == false ? symbol : nil,
      activeSymbol: active?.isEmpty == false ? active : nil,
      image: image,
      activeImage: activeImage,
      badge: badge?.isEmpty == false ? badge : nil)
  }

  private static func loadImage(_ data: [String: Any]?, iconBytes: Any?) -> NSImage? {
    let size: CGFloat = 18
    if let data {
      let format = data["format"] as? String
      if let bytes = data["data"] as? FlutterStandardTypedData {
        return ImageUtils.image(
          assetPath: nil, imageData: bytes.data, format: format,
          customIconBytes: nil, size: size, color: nil)
      }
      if let path = data["path"] as? String, !path.isEmpty {
        return ImageUtils.image(
          assetPath: path, imageData: nil, format: format,
          customIconBytes: nil, size: size, color: nil)
      }
    }
    if let bytes = iconBytes as? FlutterStandardTypedData {
      return ImageUtils.customIconImage(bytes.data, pointSize: size)
    }
    return nil
  }
}

/// A native macOS sidebar: SwiftUI's `List` in the sidebar style, with
/// sections, symbols or images, badges and one selected row, and an optional
/// search field at its top. Used by the window's split view sidebar
/// (`CNTabBarNative`) and by the `CNSidebar` platform view.
struct MacSidebarList: View {
  @ObservedObject var model: MacSidebarModel

  /// The selection as the user changes it. A sidebar of tabs always has a
  /// row selected, so a click that would clear it is ignored.
  private var selection: Binding<Int?> {
    Binding(
      get: { model.selection },
      set: { newValue in
        guard let newValue else {
          model.objectWillChange.send()
          return
        }
        if newValue == model.selection { return }
        model.selection = newValue
        model.onSelect?(newValue)
      })
  }

  private var query: Binding<String> {
    Binding(
      get: { model.query },
      set: { newValue in
        if newValue == model.query { return }
        model.query = newValue
        model.onQuery?(newValue)
      })
  }

  var body: some View {
    if model.hasSearch {
      // An AppKit search field above the rows, as System Settings has.
      // SwiftUI's `searchable(placement: .sidebar)` shows nothing in a
      // sidebar outside a `NavigationSplitView`.
      VStack(spacing: 0) {
        MacSearchField(text: query, prompt: model.searchPrompt)
          .padding(.horizontal, 10)
          .padding(.top, 2)
          .padding(.bottom, 6)
        list
      }
    } else {
      list
    }
  }

  private var list: some View {
    List(selection: selection) {
      ForEach(model.sections) { section in
        if let title = section.title {
          Section(header: Text(title)) { rows(section) }
        } else {
          Section { rows(section) }
        }
      }
    }
    .listStyle(.sidebar)
    .tint(model.tint)
    .accentColor(model.tint)
  }

  @ViewBuilder
  private func rows(_ section: MacSidebarSection) -> some View {
    ForEach(section.rows) { row in
      MacSidebarRowView(row: row, selected: model.selection == row.id, iconsOnly: model.iconsOnly)
        .tag(Optional(row.id))
    }
  }
}

/// One sidebar row: the icon and title as a `Label`, the badge as a list
/// badge.
private struct MacSidebarRowView: View {
  let row: MacSidebarRow
  let selected: Bool
  let iconsOnly: Bool

  var body: some View {
    if iconsOnly {
      // A Label, so VoiceOver reads the title. The sidebar style sizes and
      // tints only a full Label's icon, so this one gets the same here.
      Label { Text(row.title) } icon: { icon }
        .labelStyle(.iconOnly)
        .imageScale(.large)
        .foregroundColor(.accentColor)
        .overlay(alignment: .topTrailing) { compactBadge.accessibilityHidden(true) }
        .frame(maxWidth: .infinity, minHeight: 34)
        .help(row.title)
        .modifier(MacBadgeAccessibility(badge: row.badge))
    } else {
      Label { Text(row.title) } icon: { icon }
        .badge(badgeText)
        .modifier(MacBadgeAccessibility(badge: row.badge))
    }
  }

  private var badgeText: Text? {
    guard let badge = row.badge else { return nil }
    if badge == MacSidebarRow.dotBadge {
      // "Something new", in the accent colour, as Mail marks unread mail.
      return Text(Image(systemName: "circle.fill"))
        .font(.system(size: 7))
        .foregroundColor(.accentColor)
    }
    return Text(badge)
  }

  @ViewBuilder
  private var compactBadge: some View {
    if let badge = row.badge {
      // At the icon's top-trailing corner, as on the iOS rail.
      if badge == MacSidebarRow.dotBadge {
        // Red like the count badges here and the iOS rail's dot.
        Circle().fill(Color.red).frame(width: 7, height: 7).offset(x: 4, y: -3)
      } else {
        Text(badge)
          .font(.system(size: 9, weight: .semibold))
          .foregroundColor(.white)
          .padding(.horizontal, 4)
          .frame(minWidth: 14, minHeight: 14)
          .background(Capsule().fill(Color.red))
          .fixedSize()
          .offset(x: 9, y: -7)
      }
    }
  }

  @ViewBuilder
  private var icon: some View {
    if let image = selected ? (row.activeImage ?? row.image) : row.image {
      Image(nsImage: image)
        .renderingMode(image.isTemplate ? .template : .original)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 18, height: 18)
    } else if let symbol = selected ? (row.activeSymbol ?? row.symbol) : row.symbol {
      Image(systemName: symbol)
    } else if iconsOnly {
      Image(systemName: "circle")
    }
  }
}

/// Reads a badge's count as the row's value; a dot reads as "New".
struct MacBadgeAccessibility: ViewModifier {
  let badge: String?

  func body(content: Content) -> some View {
    if let badge {
      content.accessibilityValue(Text(badge == MacSidebarRow.dotBadge ? "New" : badge))
    } else {
      content
    }
  }
}

/// `NSSearchField`, reporting every edit (and the cancel button) at once.
struct MacSearchField: NSViewRepresentable {
  @Binding var text: String
  let prompt: String

  func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

  func makeNSView(context: Context) -> NSSearchField {
    let field = MacSidebarSearchField()
    field.placeholderString = prompt
    field.delegate = context.coordinator
    field.target = context.coordinator
    field.action = #selector(Coordinator.changed(_:))
    field.sendsSearchStringImmediately = true
    field.setAccessibilityLabel(prompt)
    return field
  }

  func updateNSView(_ field: NSSearchField, context: Context) {
    context.coordinator.text = $text
    if field.stringValue != text { field.stringValue = text }
    if field.placeholderString != prompt {
      field.placeholderString = prompt
      field.setAccessibilityLabel(prompt)
    }
  }

  final class Coordinator: NSObject, NSSearchFieldDelegate {
    var text: Binding<String>

    init(text: Binding<String>) { self.text = text }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSSearchField else { return }
      if text.wrappedValue != field.stringValue { text.wrappedValue = field.stringValue }
    }

    @objc func changed(_ sender: NSSearchField) {
      if text.wrappedValue != sender.stringValue { text.wrappedValue = sender.stringValue }
    }
  }
}

/// The sidebar's search field. It takes the keyboard when the user clicks
/// it or tabs to it, or when `focus()` is called (`activateSearch`), never
/// on its own: AppKit would otherwise make it the window's first responder
/// when the split view appears, away from the Flutter text field the user
/// is typing in.
final class MacSidebarSearchField: NSSearchField {
  private var focusing = false

  override var acceptsFirstResponder: Bool {
    if focusing { return true }
    guard let event = NSApp.currentEvent else { return false }
    switch event.type {
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
      return true
    case .keyDown:
      return event.keyCode == 48  // Tab
    default:
      return false
    }
  }

  /// Puts the keyboard here.
  func focus() {
    focusing = true
    window?.makeFirstResponder(self)
    focusing = false
  }
}
