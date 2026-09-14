import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/keys/session_lock_keys.dart';
import '../../../theme/theme.dart';
import '../controllers/session_lock_controller.dart';

/// What an idle ward device shows.
///
/// Deliberately not a sign-in form. It says whose session this is, because the
/// person picking the device up needs to know before they type — and it offers
/// the handover in one tap for when the answer is "not mine". A lock that can
/// only be opened by the person who left it is a lock that gets worked around
/// by not locking.
///
/// Nothing about the session is cleared. The tabs behind this are still loaded,
/// so unlocking returns somebody to the row they were reading rather than to a
/// cold start.
class SessionLockView extends GetView<SessionLockController> {
  const SessionLockView({super.key});

  @override
  Widget build(BuildContext context) {
    // Reads `controller` first: a GetView whose build never touches it never
    // constructs a lazyPut controller.
    final c = controller;

    return Scaffold(
      key: SessionLockKeys.screen,
      body: BentoGround(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BentoSpace.page),
              child: MaxWidthBody(
                maxWidth: 420,
                child: Form(
                  key: c.formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: brandTonalColor(context),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            c.initials,
                            style: AppFonts.text(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: brandInkColor(context),
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        c.name.isEmpty ? 'Locked' : c.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).brightness == Brightness.dark
                            ? AppTextStyles.darkTitle2(weight: FontWeight.w700)
                            : AppTextStyles.lightTitle2(weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This device locked while it was idle.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).brightness == Brightness.dark
                            ? AppTextStyles.darkSubheadline()
                            : AppTextStyles.lightSubheadline(),
                      ),
                      const SizedBox(height: 24),

                      Obx(
                        () => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (c.error.isNotEmpty) ...[
                              NoticeBanner(
                                key: SessionLockKeys.error,
                                icon: Icons.error_outline_rounded,
                                tint: AppColors.error,
                                message: c.error,
                              ),
                              const SizedBox(height: BentoSpace.action),
                            ],
                            BentoInput(
                              key: SessionLockKeys.password,
                              controller: c.password,
                              label: 'Password',
                              hint: 'Your password',
                              obscure: true,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => c.unlock(),
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'Enter your password to unlock.'
                                      : null,
                            ),
                            const SizedBox(height: BentoSpace.section),
                            SizedBox(
                              height: AppTheme.minTapTarget,
                              child: FilledButton(
                                key: SessionLockKeys.unlock,
                                onPressed: c.busy ? null : c.unlock,
                                child: Text(c.busy ? 'Unlocking…' : 'Unlock'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: BentoSpace.action),
                      TextButton(
                        key: SessionLockKeys.notMe,
                        onPressed: c.signOutInstead,
                        // The handover. Named for what it does to the session,
                        // not for how it feels: the next person gets a sign-in
                        // screen and this one's work is gone.
                        child: const Text('Not you? Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
