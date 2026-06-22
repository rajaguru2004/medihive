import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'app/theme/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    GetMaterialApp(
      title: 'MediHive',
      debugShowCheckedModeBanner: false,
      // ── Centralized Theme ───────────────────────────────────────────────
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // ── Global GetX DI ──────────────────────────────────────────────────
      initialBinding: BindingsBuilder(() {
        Get.put(AppThemeController(), permanent: true);
      }),
      // ── Routing ─────────────────────────────────────────────────────────
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    ),
  );
}
