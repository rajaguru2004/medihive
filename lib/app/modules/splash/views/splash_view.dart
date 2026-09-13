import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/splash_controller.dart';

/// The first frame.
///
/// A wordmark on the ground, and nothing else — no spinner. A spinner on a
/// launch screen says "this is slow"; the mark says "this is starting", and
/// the checks behind it usually finish before a second frame lands anyway.
/// When they do not, the shell's own skeletons take over, which is the honest
/// place for a loading state.
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: SplashKeys.screen,
      body: BentoGround(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The mark: a rounded square carrying the brand, the way the
              // launcher icon does. Drawn rather than shipped as an asset so
              // it follows the site's brand when that is not the default.
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: brandFillColor(context),
                  borderRadius: BorderRadius.circular(BentoRadius.hero),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer
                        .withValues(alpha: 0.24),
                  ),
                  boxShadow: bentoShadow(context, hero: true),
                ),
                child: Icon(
                  Icons.monitor_heart_rounded,
                  size: 38,
                  color: onBrandFillColor(context),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'MediHive',
                key: SplashKeys.wordmark,
                style: isDark
                    ? AppTextStyles.darkTitle2()
                    : AppTextStyles.lightTitle2(),
              ),
              const SizedBox(height: 6),
              Text(
                'Hospital operations',
                style: AppTextStyles.overline(Theme.of(context).brightness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
