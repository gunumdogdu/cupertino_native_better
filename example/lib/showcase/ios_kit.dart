import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';

/// Building blocks that look like Apple's own iOS 27 apps, measured from the
/// Settings app: grouped background, continuous-corner cards, 52 pt rows,
/// coloured icon tiles and the floating glass header.
abstract final class IOS {
  static const double margin = 16;
  static const double cardRadius = 26;
  static const double rowHeight = 52;
  static const double tileSize = 30;

  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );
  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.43,
  );
  static const TextStyle body = TextStyle(fontSize: 17, letterSpacing: -0.43);
  static const TextStyle footnote = TextStyle(
    fontSize: 15,
    letterSpacing: -0.23,
  );
}

/// A page on the grouped background, with a large title or a glass header.
class IOSPage extends StatelessWidget {
  const IOSPage({
    super.key,
    this.largeTitle,
    this.title,
    this.leading,
    this.trailing,
    required this.children,
    this.bottomPadding = 40,
    this.controller,
  });

  /// Shown as a 34 pt title above the content, as on a root page.
  final String? largeTitle;

  /// Shown centred in the glass header, as on a pushed page.
  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> children;
  final double bottomPadding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final top = insets.top;
    final hasHeader = title != null || leading != null || trailing != null;
    return ColoredBox(
      color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: Stack(
        children: [
          ListView(
            controller: controller,
            padding: EdgeInsets.only(
              top: top + (hasHeader ? 64 : 8),
              bottom: bottomPadding + insets.bottom,
              left: insets.left,
              right: insets.right,
            ),
            children: [
              if (largeTitle != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(IOS.margin, 4, 16, 14),
                  child: Text(
                    largeTitle!,
                    style: IOS.largeTitle.copyWith(
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
              ...children,
            ],
          ),
          if (hasHeader)
            Positioned(
              top: top + 6,
              left: IOS.margin + insets.left,
              right: IOS.margin + insets.right,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: IOS.title.copyWith(
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  if (leading != null)
                    Align(alignment: Alignment.centerLeft, child: leading),
                  if (trailing != null)
                    Align(alignment: Alignment.centerRight, child: trailing),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The 44 pt glass circle Apple puts in the corners of a header.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.symbol,
    required this.label,
    this.onPressed,
  });

  final String symbol;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: CNButton.icon(
        icon: CNSymbol(
          symbol,
          size: 17,
          color: CupertinoColors.label.resolveFrom(context),
        ),
        semanticLabel: label,
        onPressed: onPressed ?? () => Navigator.maybePop(context),
      ),
    );
  }
}

/// A section: optional grey header, a rounded card of [rows], optional footer.
class IOSSection extends StatelessWidget {
  const IOSSection({super.key, this.header, required this.rows, this.footer});

  final String? header;
  final List<Widget> rows;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final separator = CupertinoColors.separator.resolveFrom(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) {
        final row = rows[i];
        final inset = row is IOSRow && (row.icon != null || row.leading != null)
            ? 16 + IOS.tileSize + 14.0
            : 16.0;
        children.add(
          Padding(
            padding: EdgeInsets.only(left: inset),
            child: Container(height: hairline, color: separator),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(IOS.margin, 0, IOS.margin, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                header!,
                style: IOS.body.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          DecoratedBox(
            decoration: ShapeDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(IOS.cardRadius),
              ),
            ),
            child: Column(children: children),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                footer!,
                style: IOS.footnote.copyWith(color: secondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// A 52 pt list row: optional icon tile, title, optional value and trailing.
class IOSRow extends StatelessWidget {
  const IOSRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.value,
    this.trailing,
    this.leading,
    this.chevron = false,
    this.destructive = false,
    this.centered = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? icon;
  final Color? iconColor;

  /// Replaces the icon tile, e.g. with a file thumbnail.
  final Widget? leading;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final bool destructive;

  /// Centres the title, as for a lone action such as Sign Out.
  final bool centered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = destructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);
    final titleText = Text(
      title,
      style: IOS.body.copyWith(color: label),
      overflow: TextOverflow.ellipsis,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: subtitle == null ? IOS.rowHeight : 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              if (icon != null && leading == null) ...[
                IconTile(symbol: icon!, color: iconColor!),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: centered
                    ? Center(child: titleText)
                    : subtitle == null
                    ? titleText
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleText,
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: IOS.footnote.copyWith(
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    value!,
                    style: IOS.body.copyWith(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              ?trailing,
              if (chevron)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 17,
                    color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A white SF Symbol on a coloured continuous-corner square, as in Settings.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.symbol,
    required this.color,
    this.size = IOS.tileSize,
  });

  final String symbol;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: color,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
      ),
      alignment: Alignment.center,
      child: CNIcon(
        symbol: CNSymbol(
          symbol,
          size: size * 0.6,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}
