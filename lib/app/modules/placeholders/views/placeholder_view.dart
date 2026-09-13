import 'package:flutter/material.dart';

import '../../../core/keys/app_keys.dart';
import '../../../theme/theme.dart';

/// A screen that is routed but not yet built.
///
/// Deliberately not a "coming soon" splash. A clinician who taps Pharmacy and
/// gets a shrug learns that this app is unfinished; one who is told *where the
/// work happens today* can go and do it. So each of these names the module,
/// says what it is for, and points at the place the job is currently done.
///
/// It is also a real screen in every other respect — keyed, back-navigable,
/// themed — because it is reachable by deep link and a test walking the shell
/// has to be able to tell it apart from a crash.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.module,
    required this.title,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Stable id for the key. Survives a rename of [title].
  final String module;

  final String title;
  final IconData icon;

  /// What this module is for, and where the work happens meanwhile. Two
  /// sentences at most — a paragraph here is a paragraph nobody reads.
  final String message;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: PlaceholderKeys.screen(module),
      appBar: DetailHeader(title: title),
      body: BentoGround(
        child: SafeArea(
          child: Center(
            child: MaxWidthBody(
              maxWidth: 420,
              child: Padding(
                padding: const EdgeInsets.all(BentoSpace.page),
                child: EmptyState(
                  icon: icon,
                  title: '$title is not switched on here',
                  message: message,
                  actionLabel: actionLabel,
                  onAction: onAction,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
