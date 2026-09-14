/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — where an image being attached to a study comes from
///
/// The imaging screens need one thing from a camera roll or a camera: bytes, a
/// filename and a media type. That is a small enough surface to state here and
/// inject, which is what keeps `RadiologyOrderDetailController` testable
/// without a platform channel — a picker plugin answers over the method
/// channel, and a method channel in a widget test is a stub either way.
///
/// `image_picker` is a dependency now, and `image_picker_image_source.dart`
/// holds the `ImagePickerImageSource implements ImageSource` this interface
/// was written for. A binding registers that instead of [StubImageSource];
/// nothing above this line changed when it arrived, which was the point.
///
/// The note left here for that day turned out to be worth its minute, and
/// understated: `image_picker` exports an `ImageSource` **enum** of its own
/// *and* a `PickedFile` that collides with `file_source.dart`'s. The
/// implementation takes the whole package behind a prefix rather than hiding
/// names one at a time.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:typed_data';

/// Where the picker should look.
enum ImageOrigin {
  /// Take one now. The radiographer standing at the machine.
  camera,

  /// One already on the device — a study exported from the console.
  gallery,
}

/// One image, ready to be posted as a multipart part.
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;

  /// What the server files it under. Carries its extension, because the
  /// bucket key is built from it.
  final String filename;

  /// One of the four the upload route accepts — `image/jpeg`, `image/png`,
  /// `image/webp`, `application/dicom`. Sent explicitly rather than guessed
  /// from the extension: Dio defaults a part with no type to
  /// `application/octet-stream`, which the route's `fileFilter` rejects.
  final String mimeType;

  int get sizeInBytes => bytes.length;
}

/// A source of images to attach to a study.
abstract interface class ImageSource {
  /// The chosen image, or null when the person backed out of the picker.
  Future<PickedImage?> pick(ImageOrigin origin);
}

/// The implementation this build ships with.
///
/// It answers with a real, valid one-pixel PNG rather than with null, so every
/// screen and every flow downstream of the picker — the multipart post, the
/// PATCH that records the URL, the thumbnail strip — is exercised end to end
/// on a build that has no picker plugin in it. A stub that returned null would
/// leave the whole upload path untested and looking finished.
class StubImageSource implements ImageSource {
  const StubImageSource();

  /// A 1×1 transparent PNG, byte for byte.
  ///
  /// Spelled out rather than decoded from base64 at call time: this is the
  /// only image this build can produce, and a constant list is one a test can
  /// compare against.
  static final Uint8List onePixelPng = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  @override
  Future<PickedImage?> pick(ImageOrigin origin) async => PickedImage(
        bytes: onePixelPng,
        // Named for where it came from, so a study with two attachments does
        // not show the same filename twice with nothing to tell them apart.
        filename: 'study-${origin.name}.png',
        mimeType: 'image/png',
      );
}
