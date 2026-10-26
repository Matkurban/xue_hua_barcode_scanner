import 'package:flutter_driver/driver_extension.dart';
import 'package:xue_hua_barcode_scanner_example/main.dart' as app;

import 'driver_data_handler.dart';

/// Driver entrypoint. Normal `flutter run` keeps using `lib/main.dart`.
void main() {
  enableFlutterDriverExtension(handler: driverDataHandler);
  app.main();
}
