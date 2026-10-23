import 'package:material_ui/material_ui.dart';

import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const XueHuaBarcodeScannerExampleApp());
}

/// `xue_hua_barcode_scanner` 示例应用根组件。
class XueHuaBarcodeScannerExampleApp extends StatelessWidget {
  const XueHuaBarcodeScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XueHua Barcode Scanner Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C853),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ExampleHomePage(),
    );
  }
}
