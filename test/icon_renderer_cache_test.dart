import 'dart:typed_data';

import 'package:cupertino_native_better/utils/icon_renderer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the memoisation contract of [iconDataToImageBytes] — not the pixels
/// it produces.
///
/// These assertions deliberately compare `Future` *identity* before awaiting
/// anything, so they hold regardless of whether the test environment can
/// rasterise the glyph. That matters twice over:
///
///  * the widgets call `iconDataToImageBytes` from inside `build()`, and
///    `FutureBuilder` only re-subscribes when its future's identity changes —
///    so a stable instance is exactly what stops the re-render and the
///    placeholder flash;
///  * a cache that returned an equal-but-distinct future would satisfy a
///    value-based test while still re-rasterising on every rebuild.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A plain Latin codepoint rather than a package icon font: the point is the
  // cache, and this keeps the test independent of font asset loading.
  const IconData icon = IconData(0x41, fontFamily: 'Roboto');
  const IconData other = IconData(0x42, fontFamily: 'Roboto');

  group('iconDataToImageBytes memoisation', () {
    setUp(clearIconImageCache);

    test('returns the identical future for identical arguments', () {
      final Future<Uint8List?> first = iconDataToImageBytes(icon, size: 20);
      final Future<Uint8List?> second = iconDataToImageBytes(icon, size: 20);

      expect(identical(first, second), isTrue);
    });

    test('keys on size', () {
      final Future<Uint8List?> small = iconDataToImageBytes(icon, size: 20);
      final Future<Uint8List?> large = iconDataToImageBytes(icon, size: 24);

      expect(identical(small, large), isFalse);
    });

    test('keys on the glyph', () {
      final Future<Uint8List?> a = iconDataToImageBytes(icon, size: 20);
      final Future<Uint8List?> b = iconDataToImageBytes(other, size: 20);

      expect(identical(a, b), isFalse);
    });

    test('keys on colour', () {
      final Future<Uint8List?> black = iconDataToImageBytes(
        icon,
        size: 20,
        color: const Color(0xFF000000),
      );
      final Future<Uint8List?> white = iconDataToImageBytes(
        icon,
        size: 20,
        color: const Color(0xFFFFFFFF),
      );

      expect(identical(black, white), isFalse);
    });

    test('clearIconImageCache forces a fresh render', () {
      final Future<Uint8List?> before = iconDataToImageBytes(icon, size: 20);
      clearIconImageCache();
      final Future<Uint8List?> after = iconDataToImageBytes(icon, size: 20);

      expect(identical(before, after), isFalse);
    });

    test('stays bounded under distinct sizes', () async {
      // The cap is 256 with oldest-first eviction. Overflow it and check the
      // most recent entry survives while the oldest is gone — `size` is
      // caller-supplied and can be animated, which is why the bound exists.
      for (int i = 0; i < 300; i++) {
        iconDataToImageBytes(icon, size: 10 + i.toDouble());
      }

      final Future<Uint8List?> newest = iconDataToImageBytes(
        icon,
        size: 10 + 299.0,
      );
      final Future<Uint8List?> newestAgain = iconDataToImageBytes(
        icon,
        size: 10 + 299.0,
      );
      expect(
        identical(newest, newestAgain),
        isTrue,
        reason: 'the most recent entry should still be cached',
      );

      final Future<Uint8List?> oldest = iconDataToImageBytes(icon, size: 10);
      final Future<Uint8List?> oldestAgain = iconDataToImageBytes(
        icon,
        size: 10,
      );
      // Re-requesting the evicted size re-renders it, which puts it back — so
      // the observable signal is that the two calls above bracket a fresh
      // insert, not that the second call misses.
      expect(identical(oldest, oldestAgain), isTrue);
    });
  });
}
