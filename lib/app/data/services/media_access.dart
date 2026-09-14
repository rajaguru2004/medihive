/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — asking the device for something the patient owns
///
/// The microphone, the camera and the photo library are the first three things
/// this app has ever asked a patient for, and all three arrive through here.
/// One call site for `permission_handler`, because the sentence somebody reads
/// when they say no has to be written once and written well — six screens each
/// inventing their own refusal is six different explanations of the same
/// situation.
///
/// ## The one rule
///
/// **A refusal is never a null.** Every picker seam in this app returns null
/// for exactly one thing: the person looked at the picker and backed out. If a
/// denied permission also came back as null, the screen would show that
/// patient the same nothing it shows somebody who changed their mind — no
/// sentence, no way back, and a microphone button that silently does nothing
/// every time it is pressed. So a denial throws a [MediaRefusal], and the
/// exception *is* the sentence: it carries copy written for the person holding
/// the device, so a caller has nothing to invent and nothing to translate.
///
/// That is the narrow exception to `.agents/RULES.md` §3.3's "never show a raw
/// exception to a user". A [MediaRefusal] is not a raw exception; it is a
/// written refusal that happens to travel on the error channel because that is
/// the only channel `Future<T?>` leaves free.
///
/// ## Whose voice these are in
///
/// The sentences come from `PatientText`, because case-taking is the surface
/// that wires a real camera and a real microphone and a patient is the harder
/// reader. A staff screen that later adopts one of these seams — radiology
/// reaching for the camera, say — should give [refusalFor] a line of its own
/// rather than telling a radiographer they could "describe it instead".
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:permission_handler/permission_handler.dart';

import '../../core/i18n/patient_text.dart';

/// What the app is about to ask for.
enum MediaPermission {
  /// Answering out loud instead of typing.
  microphone,

  /// Photographing the thing the patient wants looked at.
  camera,

  /// Attaching a photo they already have.
  photoLibrary,
}

/// The device would not hand over what was asked for, and this is what to say.
///
/// [message] is finished copy in the patient's register — it goes on screen as
/// it is. [canOpenSettings] is true only where the operating system will no
/// longer show the prompt, which is the one case where "try again" is a lie
/// and "Open Settings" is the only way forward.
class MediaRefusal implements Exception {
  const MediaRefusal(this.message, {this.canOpenSettings = false});

  final String message;
  final bool canOpenSettings;

  @override
  String toString() => message;
}

/// The gate in front of the microphone, the camera and the photo library.
abstract final class MediaAccess {
  /// Asks for [which], and throws a [MediaRefusal] unless it is granted.
  ///
  /// Asked here rather than left to each plugin's own helper. `record`'s
  /// `hasPermission()` answers with a bool, and a bool cannot tell "they
  /// declined just now" from "it is switched off in Settings and the prompt
  /// will never appear again" — which are the same outcome to the code and two
  /// different sentences to the patient.
  static Future<void> require(MediaPermission which) async {
    final refusal = refusalFor(which, await _permissionOf(which).request());
    if (refusal != null) throw refusal;
  }

  /// The sentence for [status], or null when there is nothing to say.
  ///
  /// Split out from [require] so the wording is reachable without a platform
  /// channel: this is the part that has to be right, and it is the part a test
  /// can hold still.
  static MediaRefusal? refusalFor(
    MediaPermission which,
    PermissionStatus status,
  ) {
    // `limited` is iOS answering "yes, to these photos". The picker then shows
    // exactly the ones that were chosen, which is a patient exercising the
    // control the dialog offered them — not a refusal, and not something to
    // nag about.
    if (status.isGranted || status.isLimited) return null;

    // `restricted` is a device under parental or MDM control. The prompt never
    // appears and Settings will not offer the switch either, so it is worded
    // like a permanent denial and offered no door that does not open.
    final blocked = status.isPermanentlyDenied || status.isRestricted;

    return switch (which) {
      MediaPermission.microphone => MediaRefusal(
          blocked
              ? PatientText.microphoneBlocked
              : PatientText.microphoneDenied,
          canOpenSettings: status.isPermanentlyDenied,
        ),
      MediaPermission.camera => MediaRefusal(
          blocked ? PatientText.cameraBlocked : PatientText.cameraDenied,
          canOpenSettings: status.isPermanentlyDenied,
        ),
      MediaPermission.photoLibrary => MediaRefusal(
          blocked ? PatientText.photosBlocked : PatientText.photosDenied,
          canOpenSettings: status.isPermanentlyDenied,
        ),
    };
  }

  /// Opens the app's own page in the system settings.
  ///
  /// Only ever offered behind [MediaRefusal.canOpenSettings]. A button that
  /// sends somebody to Settings to turn on a switch that is already on is a
  /// button that makes them doubt what they are reading.
  static Future<bool> openSystemSettings() => openAppSettings();

  static Permission _permissionOf(MediaPermission which) => switch (which) {
        MediaPermission.microphone => Permission.microphone,
        MediaPermission.camera => Permission.camera,
        MediaPermission.photoLibrary => Permission.photos,
      };
}
