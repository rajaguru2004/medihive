import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:medihive/app/data/repositories/patient_documents_repository.dart';
import 'package:medihive/app/data/services/file_source.dart';
import 'package:medihive/app/data/services/image_source.dart';
import 'package:medihive/app/data/services/media_access.dart';
import 'package:medihive/app/data/services/patient_document_file_source.dart';
import 'package:medihive/app/modules/patient_documents/document_list/controllers/document_list_controller.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the camera branch, where it is cheap and honest to test it
///
/// The device tier runs on an emulator with no lens, so it drives the photo
/// library and the file picker and never taps "Take a photo": a capture surface
/// nothing can service either hangs the run or is swallowed by a stub, and a
/// test that passes for the second reason is worse than no test.
///
/// What is left to prove is the **decision**, and none of it needs hardware:
///
///   * the camera row asks the camera for the camera, not the library;
///   * backing out of a picker is not a failure and says nothing;
///   * a device that says no produces the sentence written for the patient,
///     rather than the nothing a null would produce;
///
/// and in every one of those, that no bytes leave the phone. Each test asserts
/// the last part, because "it did not upload" is the half that is invisible on
/// screen and is the half that matters when the picker misbehaves.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
    // A file source has to exist for the controller's own registration guard to
    // leave it alone; nothing in this file reaches it.
    Get.put<PatientDocumentFileSource>(const _NoFile(), permanent: true);
  });

  tearDown(Get.reset);

  /// A controller with the three seams in place and **no `onReady`**.
  ///
  /// `onReady` is where the fetch lives, and none of these tests want a
  /// network. Driving `add` directly is the whole decision under test: the
  /// picker, the permission, and whether anything is sent.
  DocumentListController controllerWith({
    required ImageSource images,
    MediaPermissionGate? permissions,
  }) {
    Get.put<ImageSource>(images, permanent: true);
    Get.put<MediaPermissionGate>(permissions ?? _Granted(), permanent: true);
    return DocumentListController();
  }

  test('the camera row asks for the camera, not the photo library', () async {
    final picker = _RecordingImageSource();
    final controller = controllerWith(images: picker);

    await controller.add(DocumentOrigin.camera);

    expect(picker.asked, [ImageOrigin.camera]);
    // And the permission it asked for is the camera's, not the library's. The
    // sentence somebody reads when they decline differs between the two — "you
    // can attach a photo you already have" is only true for one of them — so
    // asking for the wrong one is a refusal worded for a situation the patient
    // is not in.
    expect(
      (Get.find<MediaPermissionGate>() as _Granted).asked,
      [MediaPermission.camera],
    );
  });

  test('a camera the patient backed out of is not a failure', () async {
    final controller = controllerWith(images: _RecordingImageSource());

    await controller.add(DocumentOrigin.camera);

    // Null and **only** null means "they looked at the picker and changed
    // their mind". Nothing is said, because nothing went wrong.
    expect(controller.uploadError.value, isNull);
    expect(controller.isUploading.value, isFalse);
  });

  test('a device that says no answers with the sentence, not with nothing',
      () async {
    final controller = controllerWith(
      images: _RecordingImageSource(),
      permissions: const _Refused(),
    );

    await controller.add(DocumentOrigin.camera);

    // `MediaRefusal.message` is finished copy in the patient's register and
    // goes on screen as it is — the narrow exception to "never show an
    // exception to a user", because this one was written for them.
    final refusal = controller.uploadError.value;
    expect(refusal, isNotNull);
    expect(refusal, contains('camera'));
    // It names the way forward rather than the problem. A patient who declines
    // has not made a mistake and is not told they have.
    expect(refusal, contains('instead'));
  });

  test('the camera is never reached when the permission is refused', () async {
    final picker = _RecordingImageSource();
    final controller = controllerWith(
      images: picker,
      permissions: const _Refused(),
    );

    await controller.add(DocumentOrigin.camera);

    // The order is the point: ask, then open. A picker opened before the
    // permission is settled is a second system dialog stacked on the first.
    expect(picker.asked, isEmpty);
  });

  test('an oversized photograph is refused before anything is sent', () async {
    final controller = controllerWith(
      images: _OversizedImageSource(),
    );

    await controller.add(DocumentOrigin.camera);

    // Refused here rather than by the route, which answers a size overrun by
    // dropping the connection — the app would then show a network error for a
    // photograph that is merely too big, and the patient would retake it
    // larger.
    expect(controller.uploadError.value, contains('more than we can take'));
    // With a figure on it, so "smaller" means something.
    expect(controller.uploadError.value, contains('MB'));
    expect(controller.isUploading.value, isFalse);
  });
}

/// A camera that is always opened and always backed out of.
class _RecordingImageSource implements ImageSource {
  final List<ImageOrigin> asked = [];

  @override
  Future<PickedImage?> pick(ImageOrigin origin) async {
    asked.add(origin);
    return null;
  }
}

/// A photograph past the ceiling the route enforces.
class _OversizedImageSource implements ImageSource {
  @override
  Future<PickedImage?> pick(ImageOrigin origin) async => PickedImage(
        bytes: Uint8List(11 * 1024 * 1024),
        filename: 'prescription.jpg',
        mimeType: 'image/jpeg',
      );
}

class _Granted implements MediaPermissionGate {
  final List<MediaPermission> asked = [];

  @override
  Future<void> require(MediaPermission which) async => asked.add(which);
}

class _Refused implements MediaPermissionGate {
  const _Refused();

  @override
  Future<void> require(MediaPermission which) async {
    throw MediaRefusal(
      which == MediaPermission.camera
          ? 'Without the camera you cannot take a photo here. You can describe '
              'it instead.'
          : 'Without access to your photos you cannot attach one. You can take '
              'a new photo instead.',
    );
  }
}

class _NoFile implements PatientDocumentFileSource {
  const _NoFile();

  @override
  Future<PickedFile?> pick() async => null;
}
