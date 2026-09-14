/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the file browser, behind `FileSource`
///
/// The implementation `file_source.dart` describes. Nothing above that file
/// changes: `IntegrationsRepositories.register` swaps [StubFileSource] for
/// this one and the screen carries on seeing bytes, a filename and a media
/// type.
///
/// **`withData: true` is the whole reason this file has a comment.** It is the
/// trap `file_source.dart` left a note about: without it, `PlatformFile.bytes`
/// is null on desktop and the picker hands back a path instead. A null there
/// arrives downstream as an empty multipart part, which the analyser route
/// accepts as a file and the parser then reports as zero rows — so the failure
/// surfaces to a technician as "that file was empty" rather than as a bug, and
/// they spend the afternoon re-exporting a file that was never wrong.
///
/// Belt and braces, because the flag is one word and the failure is invisible:
/// a null that still arrives is refused here with a sentence instead of being
/// posted as nothing.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:file_picker/file_picker.dart';

import 'file_source.dart';
import 'media_access.dart';

/// [FileSource] over `file_picker`.
class FilePickerFileSource implements FileSource {
  const FilePickerFileSource();

  /// What the analyser import route accepts. Stated to the picker as well as
  /// to the route, so somebody choosing a PDF is told before the upload rather
  /// than after it.
  static const List<String> _extensions = ['csv', 'xls', 'xlsx', 'hl7', 'txt'];

  /// Read by a lab technician at a bench, not by a patient — so this one line
  /// is in the staff register rather than coming from `PatientText`.
  static const String _unreadable =
      'That file could not be read. Choose it again, or pick a different one.';

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
    if (bytes == null) throw const MediaRefusal(_unreadable);

    return PickedFile(
      bytes: bytes,
      filename: file.name,
      mimeType: _mimeTypeOf(file.extension),
    );
  }

  /// The four types the route accepts by media type; everything else is sent
  /// as `application/octet-stream`, which is what `file_source.dart` documents
  /// the route falling back to the extension for.
  String _mimeTypeOf(String? extension) =>
      switch ((extension ?? '').toLowerCase()) {
        'csv' => 'text/csv',
        'txt' => 'text/plain',
        'xls' => 'application/vnd.ms-excel',
        'xlsx' =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        _ => 'application/octet-stream',
      };
}
