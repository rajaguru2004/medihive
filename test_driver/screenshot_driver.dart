import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Writes the screenshots the screenshot suite captures.
///
/// Run:
/// ```sh
/// flutter drive \
///   --driver=test_driver/screenshot_driver.dart \
///   --target=integration_test/screenshots/review_screenshots_test.dart \
///   -d <device>
/// ```
///
/// Files land in `.review/` — the contact sheet a design pass is done
/// against. They are deliberately not committed: a screenshot is evidence of
/// one build, not an artefact of the repo. Add `--dart-define=REVIEW_DIR=...`
/// to write them elsewhere.
Future<void> main() async {
  const outputDir = String.fromEnvironment(
    'REVIEW_DIR',
    defaultValue: '.review',
  );

  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('$outputDir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      stdout.writeln('  ✓ $outputDir/$name.png');
      return true;
    },
  );
}
