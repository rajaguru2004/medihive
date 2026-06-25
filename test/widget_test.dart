import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/routes/app_pages.dart';

void main() {
  testWidgets('MediHive app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(initialRoute: AppPages.INITIAL, getPages: AppPages.routes),
    );

    // App renders without throwing
    expect(tester.takeException(), isNull);
  });
}
