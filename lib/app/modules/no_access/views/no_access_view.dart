import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/app_keys.dart';
import '../../../routes/app_pages.dart';
import '../../../theme/theme.dart';

/// Where the route guard sends somebody who asked for a module they do not have.
///
/// Reachable in one way only: a deep link, a stale bookmark, or a shortcut from
/// before an administrator changed what this account may do. Navigation itself
/// never offers a destination this account cannot open — that is the whole
/// point of resolving the shell from the access map — so arriving here is
/// always a surprise, and the screen's job is to make it a short one.
///
/// Not an error. Nothing is broken and there is nothing to retry: a permission
/// is changed by a person, so the copy names the module, says who can change it,
/// and offers the way back rather than a button that would fail again.
class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key});

  /// The module's display name, passed by the guard. Falls back to something
  /// true rather than to the module key — "pre-triage" is a database word.
  String get _moduleName {
    final args = Get.arguments;
    if (args is Map && args['moduleName'] is String) {
      return args['moduleName'] as String;
    }
    return 'That screen';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: NoAccessKeys.screen,
      appBar: const DetailHeader(title: 'No access'),
      body: BentoGround(
        child: SafeArea(
          child: Center(
            child: MaxWidthBody(
              maxWidth: 420,
              child: Padding(
                padding: const EdgeInsets.all(BentoSpace.page),
                child: EmptyState(
                  key: NoAccessKeys.module,
                  icon: Icons.lock_outline_rounded,
                  title: '$_moduleName is not part of your role',
                  message:
                      'An administrator can give your account access to it.',
                  actionLabel: 'Go to today',
                  onAction: () => Get.offAllNamed<void>(Routes.HOME),
                  actionKey: NoAccessKeys.home,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
