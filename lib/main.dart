import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/services/auth_service.dart';
import 'app/services/session_manager.dart';
import 'app/theme/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(AuthService(), permanent: true);
  Get.put(SessionManager(), permanent: true);
  runApp(const MediHiveApp());
}

class MediHiveApp extends StatelessWidget {
  const MediHiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = Get.put(AppThemeController());

    return Obx(
      () => GetMaterialApp(
        title: 'MediHive',
        debugShowCheckedModeBanner: false,

        // ── Themes ──────────────────────────────────────────────────────────
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeCtrl.themeMode,

        // ── Bindings ────────────────────────────────────────────────────────
        initialBinding: InitialBinding(),

        // ── Navigation ──────────────────────────────────────────────────────
        initialRoute: AuthService.to.isAuthenticated
            ? Routes.HOME
            : AppPages.INITIAL,
        getPages: AppPages.routes,
      ),
    );
  }
}
