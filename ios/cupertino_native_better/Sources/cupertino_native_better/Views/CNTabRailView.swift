import Flutter
import SwiftUI
import UIKit

/// Factory for `CNTabRail`, a vertical tab bar for the side of the screen.
///
/// A standalone `UITabBar` (which `CNTabBar` is) never adopts the iOS 27.1
/// vertical bar — only system containers do — so on iPhone Duo's outer display
/// and in landscape on its inner display this view stands in for it. It has
/// two styles: `rail`, icons stacked in a Liquid Glass capsule like the system
/// vertical tab bar, and `sidebar`, icon-and-label rows in a glass panel for
/// the open inner display.
public class CNTabRailViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    public init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        if #available(iOS 26.0, *) {
            return CNTabRailPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
        }
        // The Dart side draws its own fallback below iOS 26; never reached there.
        return CNTabRailEmptyView(frame: frame)
    }
}

private final class CNTabRailEmptyView: NSObject, FlutterPlatformView {
    private let container: UIView
    init(frame: CGRect) { container = UIView(frame: frame) }
    func view() -> UIView { container }
}

@available(iOS 26.0, *)
final class CNTabRailPlatformView: NSObject, FlutterPlatformView {

    private let container: UIView
    private let channel: FlutterMethodChannel
    private let store: CNTabRailStore
    private let hostingController: UIHostingController<CNTabRailSwiftUI>

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        container = UIView(frame: frame)
        container.backgroundColor = .clear
        channel = FlutterMethodChannel(name: "CNTabRail_\(viewId)", binaryMessenger: messenger)

        let dict = args as? [String: Any] ?? [:]
        store = CNTabRailStore()
        store.apply(items: dict)
        store.apply(style: dict)
        store.selection = (dict["selectedIndex"] as? NSNumber)?.intValue ?? 0

        hostingController = UIHostingController(rootView: CNTabRailSwiftUI(store: store))
        hostingController.view.backgroundColor = .clear
        // The rail is laid out by Flutter; the screen's safe area must not
        // inset the SwiftUI content inside it.
        hostingController.safeAreaRegions = []
        hostingController.overrideUserInterfaceStyle = (dict["isDark"] as? Bool ?? false) ? .dark : .light

        super.init()

        let hosted = hostingController.view!
        hosted.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosted)
        NSLayoutConstraint.activate([
            hosted.topAnchor.constraint(equalTo: container.topAnchor),
            hosted.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosted.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosted.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        store.onSelect = { [weak self] index in
            self?.channel.invokeMethod("valueChanged", arguments: ["index": index])
        }

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(nil); return }
            let args = call.arguments as? [String: Any] ?? [:]
            switch call.method {
            case "setSelectedIndex":
                let index = (args["index"] as? NSNumber)?.intValue ?? 0
                withAnimation(.snappy) { self.store.selection = index }
                result(nil)
            case "setItems":
                self.store.apply(items: args)
                result(nil)
            case "setStyle":
                self.store.apply(style: args)
                if let isDark = args["isDark"] as? Bool {
                    self.hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView { container }
}

@available(iOS 26.0, *)
final class CNTabRailStore: ObservableObject {

    struct Item: Identifiable {
        let id: Int
        var label: String
        var symbol: String
        var activeSymbol: String
        var image: UIImage?
        var activeImage: UIImage?
        var badge: String
    }

    @Published var items: [Item] = []
    @Published var selection = 0
    @Published var tint: Color?
    @Published var style = "rail"
    var onSelect: ((Int) -> Void)?

    func select(_ index: Int) {
        withAnimation(.snappy) { selection = index }
        onSelect?(index)
    }

    func apply(items dict: [String: Any]) {
        let labels = dict["labels"] as? [String] ?? []
        let symbols = dict["sfSymbols"] as? [String] ?? []
        let activeSymbols = dict["activeSfSymbols"] as? [String] ?? []
        let badges = dict["badges"] as? [String] ?? []
        let icons = dict["customIconBytes"] as? [Any] ?? []
        let activeIcons = dict["activeCustomIconBytes"] as? [Any] ?? []
        let assets = Assets(dict, prefix: "imageAsset")
        let activeAssets = Assets(dict, prefix: "activeImageAsset")
        let count = max(labels.count, symbols.count)
        items = (0..<count).map { i in
            Item(
                id: i,
                label: i < labels.count ? labels[i] : "",
                symbol: i < symbols.count ? symbols[i] : "",
                activeSymbol: i < activeSymbols.count ? activeSymbols[i] : "",
                // Priority, as in CNTabBar: image asset > custom icon > symbol.
                image: assets.image(i) ?? Self.image(icons, i),
                activeImage: activeAssets.image(i) ?? Self.image(activeIcons, i),
                badge: i < badges.count ? badges[i] : ""
            )
        }
    }

    func apply(style dict: [String: Any]) {
        if let argb = (dict["tint"] as? NSNumber)?.intValue {
            tint = Color(ImageUtils.colorFromARGB(argb))
        }
        if let s = dict["style"] as? String { style = s }
    }

    /// Custom icons arrive pre-rendered by Dart as PNG bytes at the screen
    /// scale; they are drawn as templates so the tint applies.
    private static func image(_ list: [Any], _ i: Int) -> UIImage? {
        guard i < list.count, let data = list[i] as? FlutterStandardTypedData else { return nil }
        return UIImage(data: data.data, scale: 3)?.withRenderingMode(.alwaysTemplate)
    }

    /// Image assets (`CNImageAsset`), sent as the same parallel lists
    /// `CNTabBar` uses. Bytes take precedence over the asset path. Drawn as
    /// templates, as `UITabBar` draws them, so the tint applies.
    private struct Assets {
        let paths: [String]
        let data: [Any]
        let formats: [String]

        init(_ dict: [String: Any], prefix: String) {
            paths = dict["\(prefix)Paths"] as? [String] ?? []
            data = dict["\(prefix)Data"] as? [Any] ?? []
            formats = dict["\(prefix)Formats"] as? [String] ?? []
        }

        func image(_ i: Int) -> UIImage? {
            let format = i < formats.count && !formats[i].isEmpty ? formats[i] : nil
            // The size SVGs are rasterised at; raster images are scaled to fit.
            let size = CGSize(width: 22, height: 22)
            var image: UIImage?
            if i < data.count, let bytes = data[i] as? FlutterStandardTypedData {
                image = ImageUtils.createImageFromData(bytes.data, format: format, size: size)
            } else if i < paths.count, !paths[i].isEmpty {
                image = ImageUtils.loadFlutterAsset(paths[i], size: size, format: format)
            }
            return image?.withRenderingMode(.alwaysTemplate)
        }
    }
}

@available(iOS 26.0, *)
struct CNTabRailSwiftUI: View {

    @ObservedObject var store: CNTabRailStore
    @Namespace private var selectionNamespace

    /// Concrete colours on purpose: a foreground style of `AnyShapeStyle(.primary)`
    /// resolves `.primary` against itself and recurses until the stack
    /// overflows (seen as a crash the moment the rail first appeared).
    private var accent: Color { store.tint ?? .accentColor }

    var body: some View {
        if store.style == "sidebar" {
            sidebar
        } else {
            rail
        }
    }

    // MARK: Rail — icons in a vertical glass capsule

    private var rail: some View {
        GlassEffectContainer {
            VStack(spacing: 4) {
                ForEach(store.items) { item in
                    let selected = item.id == store.selection
                    Button { store.select(item.id) } label: {
                        icon(item, selected: selected)
                            .font(.system(size: 19, weight: .medium))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(selected ? accent : Color.primary)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.10))
                                        .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                                }
                            }
                            .overlay(alignment: .topTrailing) { badge(item.badge).offset(x: 4, y: -2) }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.label)
                    .accessibilityValue(item.badge)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                    // Icons keep a fixed size, like the system tab bar's; with
                    // a large text size, long-pressing shows the item in the
                    // Large Content Viewer instead.
                    .accessibilityShowsLargeContentViewer {
                        icon(item, selected: selected)
                        Text(item.label)
                    }
                }
            }
            .padding(5)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Sidebar — icon and label rows in a glass panel

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(store.items) { item in
                let selected = item.id == store.selection
                Button { store.select(item.id) } label: {
                    HStack(spacing: 12) {
                        icon(item, selected: selected)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 26)
                        Text(item.label)
                            .font(.body.weight(selected ? .semibold : .regular))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if !item.badge.isEmpty {
                            Text(item.badge)
                                .font(.footnote.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .foregroundStyle(selected ? accent : Color.primary)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(accent.opacity(0.14))
                                .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityValue(item.badge)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(1)
    }

    // MARK: Pieces

    @ViewBuilder
    private func icon(_ item: CNTabRailStore.Item, selected: Bool) -> some View {
        if let image = (selected ? item.activeImage : nil) ?? item.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        } else {
            let name = selected && !item.activeSymbol.isEmpty ? item.activeSymbol : item.symbol
            Image(systemName: name.isEmpty ? "circle" : name)
                .symbolVariant(selected ? .fill : .none)
        }
    }

    @ViewBuilder
    private func badge(_ text: String) -> some View {
        if text == CupertinoTabBarPlatformView.dotBadge {
            // CNTabBarItem.dotBadge: a dot without a count, as in CNTabBar.
            Circle()
                .fill(.red)
                .frame(width: 9, height: 9)
                .offset(x: -3, y: 3)
                .accessibilityHidden(true)
        } else if !text.isEmpty {
            Text(text)
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, text.count > 1 ? 5 : 0)
                .frame(minWidth: 17, minHeight: 17)
                .background(Capsule().fill(.red))
                .accessibilityHidden(true)
        }
    }
}
