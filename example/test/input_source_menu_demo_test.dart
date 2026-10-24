import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_barcode_scanner_example/pages/input_source_menu_demo_page.dart';

void main() {
  testWidgets(
    'demo keeps the default source and hides the single-source control',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: InputSourceMenuDemoPage()),
      );

      expect(find.text('当前输入源：后置相机'), findsOneWidget);
      expect(find.text('当前输入源：内置相机'), findsOneWidget);
      expect(find.text('外接相机'), findsNothing);
      expect(find.text('前置相机'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('xh_scanner_switch_camera_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('xh_scanner_switch_camera_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('外接相机'), findsOneWidget);
      expect(find.text('前置相机'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('xh_scanner_camera_source_usb')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('当前输入源：外接相机'), findsOneWidget);
      expect(find.text('外接相机'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('xh_single_source_hidden')),
        findsOneWidget,
      );
    },
  );
}
