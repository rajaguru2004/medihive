import 'package:flutter/material.dart';

import '../../../../core/keys/app_keys.dart';
import '../../../../theme/theme.dart';
import '../../patient_portal_navigation.dart';

/// Where the entry sequence hands over to the interview.
///
/// **This screen is a seam, and it is meant to be deleted.** The case-taking
/// phase owns `/patient/case`; when it lands it replaces the one `page:`
/// builder in `PatientPortalPages` with its own view and this file goes with
/// it. The route name, the middleware and the arguments it is handed —
/// `PatientEntry`, carrying the language and the consent — are already what
/// that phase needs.
///
/// It exists rather than nothing because the alternative is worse. A consent
/// screen whose "Yes, start" leads to an unregistered route drops a patient on
/// `/not-found`, which says "this link points at a screen that doesn't exist
/// in this version of MediHive" to somebody who has just agreed to tell a
/// hospital about their health. Saying plainly that the questions are not in
/// this release, and giving them their own screen back, is the honest version
/// of the same fact — and it is the pattern `PRODUCT.md` already sets for a
/// module that is routed and not built.
class PatientCasePendingView extends StatelessWidget {
  const PatientCasePendingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: PatientPortalKeys.casePending,
      appBar: DetailHeader(title: 'Your questions'),
      body: BentoGround(
        child: SafeArea(
          child: Center(
            child: MaxWidthBody(
              maxWidth: 420,
              child: Padding(
                padding: EdgeInsets.all(BentoSpace.page),
                child: EmptyState(
                  icon: Icons.record_voice_over_outlined,
                  title: 'The questions are not ready yet',
                  message: 'This part of MediHive is still being built. Tell '
                      'the desk what has brought you in when you arrive, and '
                      'they will take your history the usual way.',
                  actionLabel: 'Back to my record',
                  onAction: PatientPortalNavigation.backToDashboard,
                  actionKey: PatientPortalKeys.casePendingBack,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
