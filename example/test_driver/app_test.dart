import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

/// Linux desktop smoke for the example app.
///
/// Camera preview and the OS gallery picker are not required. A machine with
/// no `/dev/video*` must still pass: the scanner shows an error or empty
/// preview and stays tappable. Gallery buttons are asserted, then left alone,
/// because the Linux embedder opens a blocking GTK file chooser.
void main() {
  late FlutterDriver driver;

  setUpAll(() async {
    driver = await FlutterDriver.connect();
  });

  tearDownAll(() async {
    await driver.close();
  });

  group('XueHua example', () {
    test('decodes a generated QR code on the home page', () async {
      await driver.waitFor(find.byValueKey('xh_home_page'));
      final String engine = await textOf(driver, 'xh_engine_version');
      expect(engine, contains('zxing'));

      final String status = await waitForStatus(
        driver,
        (String value) => value.contains('解码验证成功') || value.contains('操作异常'),
      );
      expect(status, contains('解码验证成功'), reason: status);
      expect(
        status,
        contains('https://github.com/Matkurban/xue_hua_barcode_scanner'),
      );
      expect(await exists(driver, 'xh_qr_preview'), isTrue);
      expect(await exists(driver, 'xh_empty_results'), isFalse);
      expect(await exists(driver, 'xh_home_busy'), isFalse);
    });

    test('rejects an empty payload and decodes a new one', () async {
      await scrollTo(driver, 'xh_barcode_input_clear');
      await driver.tap(find.byValueKey('xh_barcode_input_clear'));
      await scrollTo(driver, 'xh_generate_and_decode');
      await driver.tap(find.byValueKey('xh_generate_and_decode'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final String unchanged = await textOf(driver, 'xh_status_log');
      expect(unchanged, contains('解码验证成功'));
      expect(await exists(driver, 'xh_home_busy'), isFalse);

      await scrollTo(driver, 'xh_barcode_input');
      await driver.tap(find.byValueKey('xh_barcode_input'));
      await driver.enterText('driver-smoke-ok');
      expect(await textOf(driver, 'xh_barcode_input'), 'driver-smoke-ok');
      await driver.tap(find.byValueKey('xh_generate_and_decode'));
      final String generated = await waitForStatus(
        driver,
        (String value) =>
            value.contains('driver-smoke-ok') || value.contains('操作异常'),
      );
      expect(generated, contains('解码验证成功'), reason: generated);
      expect(generated, contains('driver-smoke-ok'));
    });

    test('changes ECC and module shape, then decodes again', () async {
      await scrollTo(driver, 'xh_ecc_dropdown');
      await driver.tap(find.byValueKey('xh_ecc_dropdown'));
      await waitForPopupText(driver, 'HIGH');
      expect(await driver.requestData('tapPopupText:HIGH'), 'tapped');
      await waitForPopupTextAbsent(driver, 'HIGH');
      final String ecc = await driver.requestData(
        'visibleText:xh_ecc_dropdown',
      );
      expect(ecc, contains('HIGH'), reason: ecc);
      expect(ecc, isNot(contains('LOW')), reason: ecc);

      await scrollTo(driver, 'xh_shape_dropdown');
      await driver.tap(find.byValueKey('xh_shape_dropdown'));
      await waitForPopupText(driver, 'circle');
      expect(await driver.requestData('tapPopupText:circle'), 'tapped');
      await waitForPopupTextAbsent(driver, 'circle');
      final String shape = await driver.requestData(
        'visibleText:xh_shape_dropdown',
      );
      expect(shape, contains('circle'), reason: shape);
      expect(shape, isNot(contains('roundedSquare')), reason: shape);

      await scrollTo(driver, 'xh_generate_and_decode');
      await driver.tap(find.byValueKey('xh_generate_and_decode'));
      final String status = await waitForStatus(
        driver,
        (String value) =>
            value.contains('driver-smoke-ok') || value.contains('操作异常'),
      );
      expect(status, contains('解码验证成功'), reason: status);
    });

    test('decodes a padded Y plane through rowStride', () async {
      await scrollTo(driver, 'xh_row_stride_decode');
      await driver.tap(find.byValueKey('xh_row_stride_decode'));
      final String status = await waitForStatus(
        driver,
        (String value) =>
            value.contains('rowStride=') || value.contains('操作异常'),
      );
      expect(status, contains('内存对齐解码成功'), reason: status);
      expect(status, contains('driver-smoke-ok'));
      final RegExpMatch? match = RegExp(r'rowStride=(\d+), width=(\d+)')
          .firstMatch(status);
      expect(match, isNotNull, reason: status);
      expect(
        int.parse(match!.group(1)!),
        greaterThan(int.parse(match.group(2)!)),
      );
      await scrollTo(driver, 'xh_pick_gallery');
      await driver.waitFor(find.byValueKey('xh_pick_gallery'));
    });

    test(
      'switches the multi-source demo and hides the single-source control',
      () async {
        await scrollTo(driver, 'xh_open_input_source_demo');
        await driver.tap(find.byValueKey('xh_open_input_source_demo'));
        await driver.waitFor(find.byValueKey('xh_input_source_demo_page'));
        expect(await textOf(driver, 'xh_demo_active_source'), '当前输入源：后置相机');
        expect(await textOf(driver, 'xh_single_source_hidden'), '当前输入源：内置相机');
        expect(await countOf(driver, 'xh_scanner_switch_camera_button'), 1);

        await driver.tap(find.byValueKey('xh_scanner_switch_camera_button'));
        await driver.waitFor(find.byValueKey('xh_scanner_camera_menu'));
        await driver.waitFor(find.byValueKey('xh_scanner_camera_source_usb'));
        await driver.tap(find.byValueKey('xh_scanner_camera_source_usb'));
        await driver.waitForAbsent(find.byValueKey('xh_scanner_camera_menu'));
        expect(await textOf(driver, 'xh_demo_active_source'), '当前输入源：外接相机');
        expect(await countOf(driver, 'xh_scanner_switch_camera_button'), 1);
        expect(await exists(driver, 'xh_single_source_hidden'), isTrue);

        await driver.tap(find.byValueKey('xh_input_source_demo_back'));
        await driver.waitForAbsent(
          find.byValueKey('xh_input_source_demo_page'),
        );
        await driver.waitFor(find.byValueKey('xh_home_page'));
      },
    );

    test(
      'default scanner survives a missing camera and returns home',
      () async {
        await openScanner(
          driver,
          'xh_open_default_scanner',
          'xh_default_scanner_page',
        );
        await exerciseScanner(
          driver,
          pageKey: 'xh_default_scanner_page',
          hintFragment: '将二维码放入框内',
          torchFragment: '手电筒',
          galleryFragment: '相册',
        );
      },
    );

    test('custom scanner survives a missing camera and returns home', () async {
      await openScanner(
        driver,
        'xh_open_custom_scanner',
        'xh_custom_scanner_page',
      );
      await exerciseScanner(
        driver,
        pageKey: 'xh_custom_scanner_page',
        hintFragment: '自定义赛博主题',
        torchFragment: '闪光灯',
        galleryFragment: '相册导入',
      );
      final Health health = await driver.checkHealth();
      expect(health.status, HealthStatus.ok);
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> scrollTo(FlutterDriver driver, String key) {
  return driver.scrollUntilVisible(
    find.byValueKey('xh_home_list'),
    find.byValueKey(key),
    dyScroll: -160,
    alignment: 0.2,
    timeout: const Duration(seconds: 20),
  );
}

Future<bool> exists(FlutterDriver driver, String key) async {
  return await driver.requestData('exists:$key') == 'yes';
}

Future<int> countOf(FlutterDriver driver, String key) async {
  return int.parse(await driver.requestData('count:$key'));
}

Future<String> textOf(FlutterDriver driver, String key) {
  return driver.requestData('text:$key');
}

Future<String> waitForStatus(
  FlutterDriver driver,
  bool Function(String status) predicate,
) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 30));
  String latest = '';
  while (DateTime.now().isBefore(deadline)) {
    latest = await textOf(driver, 'xh_status_log');
    final bool busy = await exists(driver, 'xh_home_busy');
    if (predicate(latest) && !busy) {
      return latest;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail('Timed out waiting for status. Last log: $latest');
}

Future<void> waitForPopupText(FlutterDriver driver, String text) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (await driver.requestData('popupText:$text') == 'yes') {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Popup text "$text" did not appear');
}

Future<void> waitForPopupTextAbsent(FlutterDriver driver, String text) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (await driver.requestData('popupText:$text') == 'no') {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Popup text "$text" stayed open');
}

Future<void> openScanner(
  FlutterDriver driver,
  String buttonKey,
  String pageKey,
) async {
  await scrollTo(driver, buttonKey);
  await driver.tap(find.byValueKey(buttonKey));
  await driver.runUnsynchronized(() async {
    await driver.waitFor(find.byValueKey(pageKey));
  });
}

Future<void> exerciseScanner(
  FlutterDriver driver, {
  required String pageKey,
  required String hintFragment,
  required String torchFragment,
  required String galleryFragment,
}) async {
  await driver.runUnsynchronized(() async {
    await driver.waitFor(find.byValueKey('xh_scanner_back_button'));
    await driver.waitFor(find.byValueKey('xh_scanner_hint'));
    await driver.waitFor(find.byValueKey('xh_scanner_torch_button'));
    await driver.waitFor(find.byValueKey('xh_scanner_gallery_button'));

    final String hint = await textOf(driver, 'xh_scanner_hint');
    expect(hint, contains(hintFragment), reason: hint);
    final String torch = await textOf(driver, 'xh_scanner_torch_button');
    expect(torch, contains(torchFragment), reason: torch);
    final String gallery = await textOf(driver, 'xh_scanner_gallery_button');
    expect(gallery, contains(galleryFragment), reason: gallery);

    if (await exists(driver, 'xh_scanner_camera_status')) {
      final String camera = await textOf(driver, 'xh_scanner_camera_status');
      expect(camera.trim(), isNotEmpty);
      expect(
        camera.contains('相机不可用') ||
            camera.contains('取景') ||
            camera.contains('NO_CAMERA') ||
            camera.contains('No V4L2'),
        isTrue,
        reason: 'Unexpected camera placeholder: $camera',
      );
    }

    final String torchBefore = await textOf(driver, 'xh_scanner_torch_button');
    await driver.tap(find.byValueKey('xh_scanner_torch_button'));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final bool unsupported =
        await driver.requestData('existsText:不支持手电筒') == 'yes';
    final String torchAfter = await textOf(driver, 'xh_scanner_torch_button');
    expect(
      unsupported || torchAfter != torchBefore,
      isTrue,
      reason: 'Torch tap had no effect. before=$torchBefore after=$torchAfter',
    );
    await driver.waitFor(find.byValueKey('xh_scanner_back_button'));

    if (await exists(driver, 'xh_scanner_switch_camera_button')) {
      await driver.tap(find.byValueKey('xh_scanner_switch_camera_button'));
      await driver.waitFor(find.byValueKey('xh_scanner_camera_menu'));
      final String itemKey =
          await exists(driver, 'xh_scanner_camera_menu_item_1')
          ? 'xh_scanner_camera_menu_item_1'
          : 'xh_scanner_camera_menu_item_0';
      await driver.tap(find.byValueKey(itemKey));
      await driver.waitForAbsent(find.byValueKey('xh_scanner_camera_menu'));
      await driver.waitFor(find.byValueKey('xh_scanner_back_button'));
    }

    await driver.tap(find.byValueKey('xh_scanner_back_button'));
    await driver.waitForAbsent(find.byValueKey(pageKey));
  });
  await driver.waitFor(find.byValueKey('xh_home_page'));
  expect(await exists(driver, pageKey), isFalse);
}
