import 'package:contour/app/app.dart';
import 'package:contour/app/demo/demo_bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Entrypoint. A debug build starts the synthetic demo; a release build
/// starts the normal app with the factual unavailable gateways (PF-01).
/// Composition only. Worker startup lands in T07/T08.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(kDebugMode ? const DemoBootstrap() : const ContourApp());
}
