import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_plus/cupertino_native_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelCupertinoNative platform = MethodChannelCupertinoNative();
  const MethodChannel channel = MethodChannel('cupertino_native');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
