import 'package:get/get.dart';

import '../../../data/services/audio_source.dart';
import '../../../data/services/record_audio_source.dart';
import '../controllers/case_taking_controller.dart';

/// The interview.
class CaseTakingBinding extends Bindings {
  @override
  void dependencies() {
    // Guarded, so a test can put a stub in front of it before the screen is
    // built — the same arrangement `SettingsProfileBinding` uses for
    // `ImageSource`, and the reason is the same: a recorder answers over a
    // method channel, and a method channel in a widget test is a stub either
    // way.
    //
    // **Lazy, and not `put`.** `AudioRecorder`'s constructor opens a
    // platform-side session, and opening one every time somebody looks at this
    // screen is a session held for every patient who chose to type. `fenix`
    // keeps it rebuildable after a sign-out has torn the container down.
    if (!Get.isRegistered<AudioSource>()) {
      Get.lazyPut<AudioSource>(RecordAudioSource.new, fenix: true);
    }
    Get.lazyPut<CaseTakingController>(CaseTakingController.new);
  }
}
