import Cocoa
import FlutterMacOS
import SwiftUI

/// Shows a native popover (`NSPopover`) anchored to a rect of the Flutter
/// view on request from Dart over the `cn_popover` channel: the macOS side
/// of `CNPopover`.
///
/// The popover has the `.transient` behaviour: a click outside closes it,
/// and so does Escape. Its window takes the keyboard while it is open, so
/// Return presses the default button and Tab moves through its controls
/// when keyboard navigation is on. On macOS 26 the system draws it in
/// Liquid Glass.
///
/// The content is SwiftUI in an `NSHostingController`, built from the data
/// Dart sends (`CNPopoverConfig`): a title and message, rows, switches and
/// buttons. Flutter widgets cannot be placed inside it: the popover is a
/// window of its own, and Flutter draws into a second window only through
/// its multi-window API, which is not stable in Flutter 3.44.
///
/// `show` takes the payload of `debugBuildPopoverPayload` and answers, once
/// the popover has closed, the id of the row or button that closed it, or
/// nil (a click outside, Escape, a cancel button, `dismiss`, a newer
/// `show`, a hot restart). Nothing here blocks the main thread: `show`
/// returns at once and the answer is sent from the popover's callbacks.
final class CNPopoverManager: NSObject, NSPopoverDelegate {
  static let shared = CNPopoverManager()

  private var channel: FlutterMethodChannel?

  /// The open popover's call, answered exactly once by `finish`.
  private var pendingResult: FlutterResult?
  private var session: Int?
  private var popover: NSPopover?
  private var store: CNPopoverStore?
  /// The anchor in Flutter's coordinates (top-left origin), converted into
  /// the view's again whenever the view changes size.
  private var anchor = CGRect.zero
  private var edge = "bottom"
  private weak var view: NSView?
  private var frameObserver: NSObjectProtocol?
  private var keyMonitor: Any?
  private var activationObserver: NSObjectProtocol?

  func setup(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "cn_popover", binaryMessenger: messenger)
    channel = ch
    ch.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    // A hot restart starts a new root isolate (see MacEngineRestart). The
    // popover's caller is gone then, so the popover closes. Only a popover
    // opened before the announcement is closed.
    NotificationCenter.default.addObserver(
      forName: MacEngineRestart.notification, object: nil, queue: nil
    ) { [weak self] _ in
      guard let self, let stale = self.session else { return }
      DispatchQueue.main.async {
        if self.session == stale { self.finish(nil, close: true) }
      }
    }
    MacEngineRestart.observe(messenger)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let callSession = args?["session"] as? Int
    switch call.method {
    case "show":
      guard let args, let config = CNPopoverConfig(args: args) else {
        result(FlutterError(code: "invalid_args", message: "Expected {session, anchor, edge, content}", details: nil))
        return
      }
      show(config, result: result)
    case "update":
      if callSession == session, let content = args?["content"] as? [String: Any] {
        store?.content = CNPopoverConfig.Content(dict: content)
      }
      result(nil)
    case "setAnchor":
      if callSession == session, let rect = CNPopoverConfig.rect(args?["anchor"]) {
        anchor = rect
        reposition()
      }
      result(nil)
    case "dismiss":
      if callSession == nil || callSession == session {
        finish(nil, close: true)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Presentation

  private func show(_ config: CNPopoverConfig, result: @escaping FlutterResult) {
    // A popover already open belongs to an earlier call: it answers nil and
    // goes away at once.
    if let previous = popover {
      finish(nil, close: false)
      previous.animates = false
      previous.close()
    }
    guard let view = MacFlutterWindow.flutterView, view.window?.isVisible == true else {
      result(FlutterError(code: "no_view", message: "No Flutter view to anchor the popover to", details: nil))
      return
    }

    let store = CNPopoverStore(content: config.content, tint: config.tint.map { Color($0) })
    let width = config.width ?? Self.idealWidth(of: config.content, in: 200...360)
    store.width = width
    let screenHeight = (view.window?.screen ?? NSScreen.main)?.visibleFrame.height ?? 800
    store.maxHeight = max(120, screenHeight * 0.8)
    store.height = min(Self.height(of: config.content, width: width), store.maxHeight)

    let host = NSHostingController(rootView: CNPopoverRootView(store: store))
    let popover = NSPopover()
    popover.behavior = .transient
    popover.animates = true
    popover.contentViewController = host
    popover.contentSize = NSSize(width: width, height: store.height)
    popover.delegate = self
    if let appearance = MacFlutterWindow.appearance(isDark: config.isDark) {
      popover.appearance = appearance
    }

    store.onRow = { [weak self, weak popover] id in
      guard let self, let popover, popover === self.popover else { return }
      self.finish(id, close: true)
    }
    store.onAction = { [weak self, weak popover] action in
      guard let self, let popover, popover === self.popover else { return }
      self.finish(action.style == "cancel" ? nil : action.id, close: true)
    }
    store.onToggle = { [weak self, weak popover] id, value in
      guard let self, let popover, popover === self.popover else { return }
      self.sendToggle(id: id, value: value)
    }
    store.onHeight = { [weak popover, weak store] height in
      guard let popover, let store, height > 0 else { return }
      let clamped = min(height, store.maxHeight)
      guard abs(store.height - clamped) > 0.5 else { return }
      store.height = clamped
      popover.contentSize = NSSize(width: store.width, height: clamped)
    }
    store.onEscape = { [weak self, weak popover] in
      guard let self, let popover, popover === self.popover else { return }
      self.finish(nil, close: true)
    }

    pendingResult = result
    session = config.session
    anchor = config.anchor
    edge = config.edge
    self.view = view
    self.popover = popover
    self.store = store

    popover.show(relativeTo: Self.positioningRect(anchor, in: view), of: view,
                 preferredEdge: Self.rectEdge(edge, in: view))
    // AppKit refuses to show a popover in some states (a window being
    // closed) without an error; the call must not wait for it.
    guard popover.isShown else {
      finish(nil, close: false)
      return
    }
    host.view.window?.setAccessibilityModal(true)
    focusPopover()
    observe(view)
  }

  /// Answers the open popover's call with [value] once, and closes the
  /// popover when [close] is set (it is already closed otherwise).
  private func finish(_ value: String?, close: Bool) {
    let result = pendingResult
    let popover = self.popover
    pendingResult = nil
    session = nil
    self.popover = nil
    store = nil
    stopObserving()
    if close, let popover, popover.isShown {
      popover.close()
    }
    result?(value)
  }

  private func sendToggle(id: String, value: Bool) {
    guard let session else { return }
    channel?.invokeMethod("onToggleChanged", arguments: [
      "session": session, "id": id, "value": value,
    ]) { [weak self] reply in
      // No Dart handler: the app restarted and nobody is waiting for this
      // popover any more.
      if (reply as? NSObject) === FlutterMethodNotImplemented, self?.session == session {
        self?.finish(nil, close: true)
      }
    }
  }

  // MARK: - Following the anchor, Escape

  private func observe(_ view: NSView) {
    stopObserving()
    view.postsFrameChangedNotifications = true
    frameObserver = NotificationCenter.default.addObserver(
      forName: NSView.frameDidChangeNotification, object: view, queue: .main
    ) { [weak self] _ in
      self?.reposition()
    }
    // An app that becomes active after the popover opened (a click into a
    // window of an app in the background) makes its main window key again:
    // hand the keyboard back to the popover.
    activationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.focusPopover()
    }
    // Escape closes the popover wherever the keyboard is, as the popover's
    // own window does not take it when focus stayed in the app's window.
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard event.keyCode == 53, let self, let popover = self.popover, popover.isShown,
            event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
      else { return event }
      self.finish(nil, close: true)
      return nil
    }
  }

  private func stopObserving() {
    if let frameObserver { NotificationCenter.default.removeObserver(frameObserver) }
    frameObserver = nil
    if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    keyMonitor = nil
    if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
    activationObserver = nil
  }

  /// Gives the keyboard, and with it VoiceOver's focus, to the popover,
  /// which VoiceOver treats as modal until it closes.
  private func focusPopover() {
    guard let popover, popover.isShown,
          let content = popover.contentViewController?.view,
          let window = content.window else { return }
    window.makeKey()
    window.makeFirstResponder(content)
    NSAccessibility.post(element: content, notification: .focusedUIElementChanged)
  }

  /// Puts the popover back on its anchor: after the anchor moved, or after
  /// the view changed size, which moves a rect measured from its top.
  private func reposition() {
    guard let popover, popover.isShown, let view else { return }
    let rect = Self.positioningRect(anchor, in: view)
    if popover.positioningRect != rect { popover.positioningRect = rect }
  }

  // MARK: - NSPopoverDelegate

  /// A click outside, or the app going to the background, closed it.
  func popoverDidClose(_ notification: Notification) {
    guard let closed = notification.object as? NSPopover, closed === popover else { return }
    finish(nil, close: false)
  }

  // MARK: - Geometry

  /// A rect in Flutter's coordinates in [view]'s, which is not flipped. An
  /// empty anchor is given a point's size: AppKit takes an empty rect as
  /// the whole view.
  static func positioningRect(_ rect: CGRect, in view: NSView) -> NSRect {
    let y = view.isFlipped ? rect.minY : view.bounds.height - rect.maxY
    return NSRect(x: rect.minX, y: y, width: max(rect.width, 1), height: max(rect.height, 1))
  }

  /// [edge] as an edge of a rect in [view]'s coordinates. AppKit moves the
  /// popover to the opposite edge when there is no room on this one.
  static func rectEdge(_ edge: String, in view: NSView) -> NSRectEdge {
    switch edge {
    case "top": return view.isFlipped ? .minY : .maxY
    case "left": return .minX
    case "right": return .maxX
    default: return view.isFlipped ? .maxY : .minY
    }
  }

  /// The width the content takes on one line, within [range].
  static func idealWidth(of content: CNPopoverConfig.Content, in range: ClosedRange<CGFloat>) -> CGFloat {
    let ideal = NSHostingView(rootView: CNPopoverMeasure(content: content)).intrinsicContentSize.width
    guard ideal.isFinite, ideal > 0 else { return range.upperBound }
    return min(range.upperBound, max(range.lowerBound, ceil(ideal)))
  }

  /// The content's height at [width].
  static func height(of content: CNPopoverConfig.Content, width: CGFloat) -> CGFloat {
    let host = NSHostingController(rootView: CNPopoverMeasure(content: content))
    let size = host.sizeThatFits(in: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    return ceil(size.height)
  }
}

// MARK: - Config (plain data parsed from the channel)

/// Mirrors `debugBuildPopoverPayload` in `lib/components/popover.dart`.
struct CNPopoverConfig {
  /// A row's `CNListItem` part, with the keys `CNNativeSheet` uses on iOS.
  struct Item {
    let title: String
    let subtitle: String?
    let trailing: String?
    let symbol: String?
    let image: NSImage?
    let chevron: Bool
  }
  struct Row {
    let id: String
    let item: Item
    let checked: Bool
    let enabled: Bool
    /// Shows information only: not a button, never closes the popover
    /// (#129).
    let readOnly: Bool
  }
  struct Toggle {
    let id: String
    let label: String
    let subtitle: String?
    let symbol: String?
    var value: Bool
    let enabled: Bool
  }
  struct Action {
    let id: String?
    let label: String
    /// `plain`, `default`, `destructive` or `cancel`.
    let style: String
  }
  struct Content {
    let title: String?
    let message: String?
    let rows: [Row]
    var toggles: [Toggle]
    let actions: [Action]

    init(dict: [String: Any]) {
      title = (dict["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
      message = (dict["message"] as? String).flatMap { $0.isEmpty ? nil : $0 }
      rows = (dict["rows"] as? [[String: Any]] ?? []).map { r in
        Row(
          id: r["id"] as? String ?? "",
          item: Item(
            title: r["title"] as? String ?? "",
            subtitle: r["subtitle"] as? String,
            trailing: r["trailingText"] as? String,
            symbol: r["leadingSfSymbol"] as? String,
            image: CNPopoverConfig.loadImage(r["leadingImage"] as? [String: Any]),
            chevron: r["showChevron"] as? Bool ?? false),
          checked: r["checked"] as? Bool ?? false,
          enabled: r["enabled"] as? Bool ?? true,
          readOnly: r["readOnly"] as? Bool ?? false)
      }
      toggles = (dict["toggles"] as? [[String: Any]] ?? []).map { t in
        Toggle(
          id: t["id"] as? String ?? "",
          label: t["label"] as? String ?? "",
          subtitle: t["subtitle"] as? String,
          symbol: t["sfSymbol"] as? String,
          value: t["value"] as? Bool ?? false,
          enabled: t["enabled"] as? Bool ?? true)
      }
      actions = (dict["actions"] as? [[String: Any]] ?? []).map { a in
        Action(id: a["id"] as? String, label: a["label"] as? String ?? "",
               style: a["style"] as? String ?? "plain")
      }
    }
  }

  let session: Int
  let anchor: CGRect
  /// `top`, `bottom`, `left` or `right`.
  let edge: String
  let content: Content
  let width: CGFloat?
  let tint: NSColor?
  let isDark: Bool?

  init?(args: [String: Any]) {
    guard let session = args["session"] as? Int,
          let anchor = Self.rect(args["anchor"]),
          let content = args["content"] as? [String: Any] else { return nil }
    self.session = session
    self.anchor = anchor
    edge = args["edge"] as? String ?? "bottom"
    self.content = Content(dict: content)
    width = (args["width"] as? NSNumber).map { CGFloat($0.doubleValue) }
    tint = (args["tint"] as? Int).map { ImageUtils.colorFromARGB($0) }
    isDark = args["isDark"] as? Bool
  }

  static func rect(_ value: Any?) -> CGRect? {
    guard let r = value as? [String: Any],
          let x = (r["x"] as? NSNumber)?.doubleValue,
          let y = (r["y"] as? NSNumber)?.doubleValue,
          let w = (r["width"] as? NSNumber)?.doubleValue,
          let h = (r["height"] as? NSNumber)?.doubleValue else { return nil }
    return CGRect(x: x, y: y, width: w, height: h)
  }

  static func loadImage(_ data: [String: Any]?) -> NSImage? {
    guard let data else { return nil }
    let format = data["format"] as? String
    if let bytes = data["data"] as? FlutterStandardTypedData {
      return ImageUtils.createImageFromData(bytes.data, format: format)
    }
    if let path = data["path"] as? String, !path.isEmpty {
      return ImageUtils.loadFlutterAsset(path, format: format)
    }
    return nil
  }
}

// MARK: - Store

final class CNPopoverStore: ObservableObject {
  @Published var content: CNPopoverConfig.Content
  @Published var width: CGFloat = 280
  @Published var height: CGFloat = 100
  var maxHeight: CGFloat = 600
  let tint: Color?

  var onRow: (String) -> Void = { _ in }
  var onAction: (CNPopoverConfig.Action) -> Void = { _ in }
  var onToggle: (String, Bool) -> Void = { _, _ in }
  var onHeight: (CGFloat) -> Void = { _ in }
  var onEscape: () -> Void = {}

  init(content: CNPopoverConfig.Content, tint: Color?) {
    self.content = content
    self.tint = tint
  }

  /// The switch at [index], reporting the user's changes. Values set by
  /// `update` change the content without reporting.
  func toggle(_ index: Int) -> Binding<Bool> {
    Binding(
      get: { [weak self] in
        guard let self, self.content.toggles.indices.contains(index) else { return false }
        return self.content.toggles[index].value
      },
      set: { [weak self] value in
        guard let self, self.content.toggles.indices.contains(index) else { return }
        self.content.toggles[index].value = value
        self.onToggle(self.content.toggles[index].id, value)
      })
  }
}

// MARK: - SwiftUI content

private struct CNPopoverHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// The content in a scroll view (it scrolls past 80% of the screen's
/// height), at the popover's size, reporting its height so the popover
/// follows changes of the content.
struct CNPopoverRootView: View {
  @ObservedObject var store: CNPopoverStore

  var body: some View {
    ScrollView(.vertical) {
      CNPopoverBody(
        content: store.content,
        tint: store.tint,
        toggle: { [store] in store.toggle($0) },
        onRow: { [store] in store.onRow($0) },
        onAction: { [store] in store.onAction($0) })
        .frame(width: store.width)
        .background(GeometryReader { proxy in
          Color.clear.preference(key: CNPopoverHeightKey.self, value: proxy.size.height)
        })
    }
    .frame(width: store.width, height: store.height)
    .onPreferenceChange(CNPopoverHeightKey.self) { [store] height in
      store.onHeight(height)
    }
    .accessibilityAction(.escape) { [store] in store.onEscape() }
  }
}

/// The content measured off screen, before the popover is shown.
struct CNPopoverMeasure: View {
  let content: CNPopoverConfig.Content

  var body: some View {
    CNPopoverBody(content: content, tint: nil,
                  toggle: { [content] in .constant(content.toggles[$0].value) },
                  onRow: { _ in }, onAction: { _ in })
  }
}

/// The popover's content, top to bottom: the title and message, the rows,
/// the switches and the buttons, in the metrics of macOS popovers and menus.
struct CNPopoverBody: View {
  let content: CNPopoverConfig.Content
  let tint: Color?
  let toggle: (Int) -> Binding<Bool>
  let onRow: (String) -> Void
  let onAction: (CNPopoverConfig.Action) -> Void

  private var hasHeader: Bool { content.title != nil || content.message != nil }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if hasHeader {
        header
          .padding(.horizontal, 14)
          .padding(.top, 12)
          .padding(.bottom, content.rows.isEmpty && content.toggles.isEmpty
                   && content.actions.isEmpty ? 12 : 8)
      }
      if !content.rows.isEmpty {
        if hasHeader { Divider().padding(.horizontal, 14) }
        rows
          .padding(.horizontal, 6)
          .padding(.vertical, 5)
      }
      if !content.toggles.isEmpty {
        if hasHeader || !content.rows.isEmpty { Divider().padding(.horizontal, 14) }
        toggles
          .padding(.vertical, 5)
      }
      if !content.actions.isEmpty {
        actions
          .padding(.horizontal, 14)
          .padding(.top, hasHeader && content.rows.isEmpty && content.toggles.isEmpty ? 4 : 8)
          .padding(.bottom, 12)
      }
    }
    .tint(tint)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 3) {
      if let title = content.title {
        Text(title)
          .font(.headline)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
      }
      if let message = content.message {
        Text(message)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var anyChecked: Bool { content.rows.contains { $0.checked } }
  private var anyLeading: Bool { content.rows.contains { $0.item.image != nil || $0.item.symbol != nil } }

  private var rows: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(content.rows.indices, id: \.self) { i in
        let row = content.rows[i]
        if row.readOnly {
          // Static text for VoiceOver: label and value, no button.
          rowLabel(row)
            .accessibilityAddTraits(row.checked ? .isSelected : [])
        } else {
          Button {
            onRow(row.id)
          } label: {
            rowLabel(row)
          }
          .buttonStyle(CNPopoverRowStyle())
          .disabled(!row.enabled)
          .accessibilityAddTraits(row.checked ? .isSelected : [])
        }
      }
    }
  }

  private func rowLabel(_ row: CNPopoverConfig.Row) -> some View {
    HStack(spacing: 6) {
      // A choice list marks the current choice at the leading edge, as a
      // menu does.
      if anyChecked {
        Image(systemName: "checkmark")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(tint ?? .primary)
          .opacity(row.checked ? 1 : 0)
          .frame(width: 12)
          .accessibilityHidden(true)
      }
      if anyLeading {
        // The column keeps its width in a row without an icon, so every
        // title starts in one column (#129). A frame on an empty view alone
        // takes no space.
        Color.clear
          .frame(width: 18, height: 18)
          .overlay(leading(row.item).frame(width: 18, height: 18))
      }
      VStack(alignment: .leading, spacing: 1) {
        Text(row.item.title)
          .fixedSize(horizontal: false, vertical: true)
        if let subtitle = row.item.subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 8)
      if let trailing = row.item.trailing {
        Text(trailing).foregroundStyle(.secondary)
      }
      if row.item.chevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .frame(minHeight: 24)
    .contentShape(Rectangle())
    .opacity(row.enabled ? 1 : 0.4)
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func leading(_ item: CNPopoverConfig.Item) -> some View {
    if let image = item.image {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .clipShape(Circle())
        .accessibilityHidden(true)
    } else if let symbol = item.symbol {
      Image(systemName: symbol)
        .foregroundStyle(.primary)
        .accessibilityHidden(true)
    }
  }

  private var toggles: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(content.toggles.indices, id: \.self) { i in
        let item = content.toggles[i]
        HStack(spacing: 8) {
          if let symbol = item.symbol {
            Image(systemName: symbol)
              .frame(width: 18)
              .accessibilityHidden(true)
          }
          // Read once, as the switch's label.
          VStack(alignment: .leading, spacing: 1) {
            Text(item.label)
              .fixedSize(horizontal: false, vertical: true)
            if let subtitle = item.subtitle {
              Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .accessibilityHidden(true)
          Spacer(minLength: 12)
          SwiftUI.Toggle(item.label, isOn: toggle(i))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityHint(item.subtitle ?? "")
        }
        .disabled(!item.enabled)
        .opacity(item.enabled ? 1 : 0.5)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(minHeight: 28)
      }
    }
  }

  /// The buttons in a row at the trailing edge, as a dialog's; more than
  /// three are stacked.
  @ViewBuilder
  private var actions: some View {
    if content.actions.count <= 3 {
      HStack(spacing: 8) {
        Spacer(minLength: 0)
        ForEach(content.actions.indices, id: \.self) { i in
          actionButton(content.actions[i])
        }
      }
    } else {
      VStack(alignment: .trailing, spacing: 8) {
        ForEach(content.actions.indices, id: \.self) { i in
          actionButton(content.actions[i])
        }
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  @ViewBuilder
  private func actionButton(_ action: CNPopoverConfig.Action) -> some View {
    let role: ButtonRole? = action.style == "destructive" ? .destructive
      : action.style == "cancel" ? .cancel : nil
    let button = Button(role: role) {
      onAction(action)
    } label: {
      Text(action.label)
        .foregroundColor(action.style == "destructive" ? .red : nil)
        .frame(minWidth: 52)
    }
    switch action.style {
    case "default":
      button.keyboardShortcut(.defaultAction)
    case "cancel":
      button.keyboardShortcut(.cancelAction)
    default:
      button
    }
  }
}

/// A row as a menu item looks in a popover: a rounded highlight under the
/// pointer, darker while pressed.
private struct CNPopoverRowStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    CNPopoverRowHighlight(configuration: configuration)
  }
}

private struct CNPopoverRowHighlight: View {
  let configuration: ButtonStyleConfiguration
  @State private var hovering = false
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    let opacity: Double = !isEnabled ? 0 : configuration.isPressed ? 0.16 : hovering ? 0.08 : 0
    configuration.label
      .background(
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(Color.primary.opacity(opacity)))
      .onHover { hovering = $0 }
  }
}
