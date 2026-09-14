/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the camera and the camera roll, behind `ImageSource`
///
/// The implementation `image_source.dart` describes. Nothing above that file
/// changes: a binding swaps [StubImageSource] for this one and the screens
/// carry on seeing bytes, a filename and a media type.
///
/// **The whole package comes in behind a prefix**, which is the note
/// `image_source.dart` left for this day. `image_picker` exports an
/// `ImageSource` **enum** of its own — and, less obviously, a `PickedFile`
/// class that collides with the one in `file_source.dart`. Two types with one
/// name in a file is a compile error rather than a subtle bug, so it costs a
/// minute once; `as picker` settles both at the import line.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:image_picker/image_picker.dart' as picker;

import 'image_source.dart';
import 'media_access.dart';

/// [ImageSource] over `image_picker`.
class ImagePickerImageSource implements ImageSource {
  const ImagePickerImageSource();

  /// A twelve-megapixel photograph of a rash is four megabytes of detail
  /// nobody looks at, sent over hospital wifi, which `PRODUCT.md` is explicit
  /// about not being office wifi. Two thousand pixels on the long edge is more
  /// than any of these screens display.
  static const double _maxDimension = 2000;
  static const int _quality = 85;

  @override
  Future<PickedImage?> pick(ImageOrigin origin) async {
    await MediaAccess.require(
      origin == ImageOrigin.camera
          ? MediaPermission.camera
          : MediaPermission.photoLibrary,
    );

    final file = await picker.ImagePicker().pickImage(
      source: switch (origin) {
        ImageOrigin.camera => picker.ImageSource.camera,
        ImageOrigin.gallery => picker.ImageSource.gallery,
      },
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
    );

    // Null here, and only here, means the person looked at the picker and
    // backed out. A refused permission threw above rather than arriving as
    // this same nothing.
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final mimeType = _mimeTypeOf(file);

    return PickedImage(
      bytes: bytes,
      filename: _withExtension(file.name, mimeType),
      mimeType: mimeType,
    );
  }

  /// The media type of what came **back**, which is not always what was
  /// picked.
  ///
  /// Asking for `imageQuality` or a `maxWidth` re-encodes, so a PNG chosen
  /// from the roll can arrive as JPEG. Reading the type off the original would
  /// label those bytes `image/png`, and an upload route that trusts the label
  /// over the magic number files an unopenable study.
  String _mimeTypeOf(picker.XFile file) {
    final declared = file.mimeType;
    if (declared != null && declared.startsWith('image/')) return declared;

    return switch (file.name.split('.').last.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'dcm' => 'application/dicom',
      // The platforms' own default, and what `imageQuality` re-encodes to.
      _ => 'image/jpeg',
    };
  }

  /// `image_source.dart` promises the filename carries its extension, because
  /// the bucket key is built from it. Android's picker usually obliges;
  /// a file shared in from another app does not always.
  String _withExtension(String name, String mimeType) {
    if (name.contains('.')) return name;
    final extension = mimeType.split('/').last;
    return '$name.${extension == 'dicom' ? 'dcm' : extension}';
  }
}
