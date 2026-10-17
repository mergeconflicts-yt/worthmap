import 'package:contour/app/app.dart';
import 'package:flutter/widgets.dart';

/// Phase 1 entrypoint (T01). No financial logic here.
/// Composition only. Worker startup lands in T07/T08.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ContourApp());
}
