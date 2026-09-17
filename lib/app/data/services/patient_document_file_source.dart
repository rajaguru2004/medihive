/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — where a *patient document* being uploaded comes from
///
/// A second file browser seam, and the reason it exists rather than reusing
/// [FileSource] is a bug this file is named after.
///
/// `FileSource` was written for the analyser results import: its picker offers
/// `csv, xls, xlsx, hl7, txt` and its media types are the spreadsheet ones.
/// Both features then asked GetX for the same `FileSource` type, and both
/// registered it with `if (!Get.isRegistered<FileSource>())` — first writer
/// wins, permanently. So "Choose a PDF" on the documents screen ran the
/// analyser picker: a PDF that got through the extension filter was labelled
/// `application/octet-stream`, and `POST /api/patient-documents` refused it
/// with "This kind of file cannot be read. Please upload a photo of the
/// document, or a PDF." — a sentence that is true, unhelpful, and about a file
/// the patient chose correctly.
///
/// Worse was the ordering: visiting the integrations screen first registered
/// `StubFileSource` permanently, and then "Choose a PDF" uploaded a fixture
/// CSV. Nothing in either feature was wrong on its own; sharing one injectable
/// type between two features with contradictory answers was.
///
/// Hence a distinct type. `Get.find<PatientDocumentFileSource>()` cannot
/// resolve to the analyser's picker or to its stub, whatever order the screens
/// are opened in, and the compiler is what enforces it rather than a comment.
///
/// `withData: true` for the same reason `file_source.dart` documents: without
/// it `PlatformFile.bytes` is null on desktop and the picker returns a path,
/// which arrives downstream as an empty part.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:file_picker/file_picker.dart';

import '../../core/i18n/patient_text.dart';
import 'file_source.dart';
import 'media_access.dart';

/// Where the documents screen gets a file from.
///
/// Deliberately a separate type from [FileSource] rather than a tag on it: a
/// tag is a string that has to match in two places, and the failure when it
/// does not is the one described above.
abstract class PatientDocumentFileSource {
  Future<PickedFile?> pick();
}

/// [PatientDocumentFileSource] over `file_picker`.
class FilePickerPatientDocumentFileSource implements PatientDocumentFileSource {
  const FilePickerPatientDocumentFileSource();

  /// What `POST /api/patient-documents` accepts, stated to the picker as well
  /// as to the route, so an unreadable file is refused in the file browser
  /// rather than after an upload.
  ///
  /// These mirror `PATIENT_DOCUMENT_MIME_TYPES` in the API
  /// (`patient-documents.service.ts`). Changing one without the other puts the
  /// rejection back where the patient cannot act on it.
  static const List<String> _extensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

  @override
  Future<PickedFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensions,
      withData: true,
    );

    // Null, or an empty selection, means the dialog was dismissed.
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) throw MediaRefusal(PatientText.couldNotOpenFile);

    final mimeType = _mimeTypeOf(file.extension);
    // `allowedExtensions` is advisory: Android's SAF and several cloud
    // providers hand back whatever was tapped. Refusing here is the difference
    // between a sentence in the picker and a 400 after the bytes are uploaded.
    if (mimeType == null) throw MediaRefusal(PatientText.unsupportedDocument);

    return PickedFile(
      bytes: bytes,
      filename: file.name,
      mimeType: mimeType,
    );
  }

  /// The media type the route judges the part by, or null for anything it
  /// would refuse.
  ///
  /// Null rather than `application/octet-stream`: the documents route decides
  /// on the declared type alone and never falls back to the filename, so
  /// octet-stream is not a lenient default there — it is a guaranteed refusal
  /// one network round-trip later.
  static String? _mimeTypeOf(String? extension) =>
      switch ((extension ?? '').toLowerCase()) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
}
