import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn_native_sheet');
  final calls = <MethodCall>[];
  var nativeShows = true;

  Future<void> fromNative(String method, [Object? args]) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, args)),
          (_) {},
        );
  }

  setUp(() {
    calls.clear();
    nativeShows = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'show' ? nativeShows : null;
        });
  });

  tearDown(() async {
    await CNNativeSheet.dismiss();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  const detents = [
    CNSheetDetent.height(150),
    CNSheetDetent.medium,
    CNSheetDetent.large,
  ];

  final pages = [
    CNSheetPage(
      title: 'People',
      sfSymbol: const CNSymbol('person.2.fill'),
      activeSfSymbol: const CNSymbol('person.2.circle.fill'),
      badgeCount: 2,
      buttons: const [
        CNSheetButton(id: 'add', sfSymbol: CNSymbol('plus'), label: 'Add'),
      ],
      items: [
        CNListItem(
          title: 'Ada',
          subtitle: 'London · Now',
          trailingText: '2 km',
          leadingImage: CNImageAsset(
            '',
            imageData: Uint8List.fromList([1, 2, 3]),
            imageFormat: 'png',
          ),
        ),
      ],
    ),
    const CNSheetPage(title: 'Devices'),
  ];

  test('show sends the pages, detents and options', () async {
    final shown = await CNNativeSheet.show(
      pages: pages,
      detents: detents,
      initialDetent: CNSheetDetent.medium,
      undimmedDetent: CNSheetDetent.medium,
      dismissible: false,
    );
    expect(shown, isTrue);
    expect(CNNativeSheet.isShown, isTrue);

    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args['detents'], [
      {'kind': 'height', 'value': 150.0},
      {'kind': 'medium', 'value': 0.0},
      {'kind': 'large', 'value': 0.0},
    ]);
    expect(args['initialDetent'], 1);
    expect(args['undimmedDetent'], 1);
    expect(args['dismissible'], isFalse);
    expect(args['showGrabber'], isTrue);

    final page = (args['pages'] as List).first as Map<Object?, Object?>;
    expect(page['title'], 'People');
    expect(page['sfSymbol'], 'person.2.fill');
    expect(page['activeSfSymbol'], 'person.2.circle.fill');
    expect(page['badgeCount'], 2);
    expect(page['buttons'], [
      {'id': 'add', 'sfSymbol': 'plus', 'label': 'Add'},
    ]);
    final item = (page['items'] as List).single as Map<Object?, Object?>;
    expect(item['title'], 'Ada');
    expect(item['subtitle'], 'London · Now');
    expect(item['trailingText'], '2 km');
    final image = item['leadingImage'] as Map<Object?, Object?>;
    expect(image['data'], Uint8List.fromList([1, 2, 3]));
    expect(image['format'], 'png');
  });

  test('without an undimmed detent the key is left out', () async {
    await CNNativeSheet.show(pages: pages);
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args.containsKey('undimmedDetent'), isFalse);
    expect(args['initialDetent'], 0);
    expect(args['dismissible'], isTrue);
  });

  test('does nothing outside iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await CNNativeSheet.show(pages: pages), isFalse);
    expect(calls, isEmpty);
    expect(CNNativeSheet.isShown, isFalse);
  });

  test('a sheet iOS cannot show reports false', () async {
    nativeShows = false;
    expect(await CNNativeSheet.show(pages: pages), isFalse);
    expect(CNNativeSheet.isShown, isFalse);
  });

  test('native events reach the callbacks', () async {
    final events = <String>[];
    await CNNativeSheet.show(
      pages: pages,
      detents: detents,
      onDetentChanged: (d) => events.add(
        'detent ${d == CNSheetDetent.large
            ? 'large'
            : d == CNSheetDetent.medium
            ? 'medium'
            : 'small'}',
      ),
      onPageSelected: (p) => events.add('page $p'),
      onItemTap: (p, i) => events.add('item $p $i'),
      onButtonTap: (p, id) => events.add('button $p $id'),
      onDismissed: () => events.add('dismissed'),
    );

    await fromNative('onDetentChanged', {'index': 2});
    await fromNative('onDetentChanged', {'index': 0});
    await fromNative('onPageSelected', {'index': 1});
    await fromNative('onItemTap', {'page': 0, 'index': 0});
    await fromNative('onButtonTap', {'page': 0, 'id': 'add'});
    await fromNative('onDismissed');

    expect(events, [
      'detent large',
      'detent small',
      'page 1',
      'item 0 0',
      'button 0 add',
      'dismissed',
    ]);
    expect(CNNativeSheet.isShown, isFalse);
  });

  test('setDetent sends the detent index, and nothing for others', () async {
    await CNNativeSheet.show(pages: pages, detents: detents);
    calls.clear();

    await CNNativeSheet.setDetent(CNSheetDetent.large);
    await CNNativeSheet.setDetent(const CNSheetDetent.fraction(0.3));
    expect(calls.map((c) => '${c.method} ${c.arguments}'), [
      'setDetent {index: 2}',
    ]);
  });

  test('updates are sent only while the sheet is shown', () async {
    await CNNativeSheet.setItems(page: 0, items: const []);
    expect(calls, isEmpty);

    await CNNativeSheet.show(pages: pages);
    calls.clear();
    await CNNativeSheet.setItems(
      page: 1,
      items: const [CNListItem(title: 'iPhone', showChevron: true)],
    );
    await CNNativeSheet.setBadgeCounts([3, null]);
    await CNNativeSheet.setSelectedPage(1);
    await CNNativeSheet.setBrightness(isDark: true);
    expect(calls.map((c) => c.method), [
      'setItems',
      'setBadgeCounts',
      'setSelectedPage',
      'setBrightness',
    ]);
    expect(calls.first.arguments, {
      'page': 1,
      'items': [
        {'title': 'iPhone', 'showChevron': true},
      ],
    });
  });

  test('the collapsed detent is sent by kind', () async {
    await CNNativeSheet.show(
      pages: pages,
      detents: const [CNSheetDetent.collapsed, CNSheetDetent.large],
    );
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args['detents'], [
      {'kind': 'collapsed', 'value': 0.0},
      {'kind': 'large', 'value': 0.0},
    ]);
  });

  test('detents compare by kind and value', () {
    expect(const CNSheetDetent.height(150), const CNSheetDetent.height(150));
    expect(
      const CNSheetDetent.height(150),
      isNot(const CNSheetDetent.fraction(150)),
    );
    expect(CNSheetDetent.medium, isNot(CNSheetDetent.large));
  });
}
