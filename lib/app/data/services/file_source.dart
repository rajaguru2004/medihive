/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — where a results file being sent to an analyser route comes from
///
/// The integrations screen needs one thing from a file browser: bytes, a
/// filename and a media type. That is a small enough surface to state here and
/// inject, which is what keeps `IntegrationsController` testable without a
/// platform channel — a picker plugin answers over the method channel, and a
/// method channel in a widget test is a stub either way.
///
/// `file_picker` is a dependency now, and `file_picker_file_source.dart` holds
/// the `FilePickerFileSource implements FileSource` this interface was written
/// for. `IntegrationsRepositories.register` registers that instead of
/// [StubFileSource]; nothing above this line changed when it arrived, which
/// was the point.
///
/// The same seam `image_source.dart` established for radiology, deliberately
/// spelled the same way. Two seams that differ only in their vocabulary are two
/// seams somebody has to read twice.
///
/// The note left here for that day: `file_picker` hands back a `PlatformFile`
/// whose `bytes` are **null** on desktop unless the picker is asked to read
/// them (`withData: true`) — it gives a path instead. A null there arrives here
/// as an empty part, which the route accepts as a file and the parser then
/// reports as zero rows, so the failure surfaces as "that file was empty"
/// rather than as a bug. The implementation passes the flag and refuses a null
/// that still arrives.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:convert';
import 'dart:typed_data';

/// One file, ready to be posted as a multipart part.
class PickedFile {
  const PickedFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;

  /// What the server files it under. Carries its extension, because the route
  /// falls back to the extension whenever the media type arrives as
  /// `application/octet-stream` — which is what several instrument bridges
  /// send for every file they export.
  final String filename;

  /// One of the four the upload route accepts by type — `text/csv`,
  /// `text/plain`, `application/vnd.ms-excel` or the `.xlsx` type — or
  /// `application/octet-stream` for a `.csv`, `.xls`, `.xlsx`, `.hl7` or
  /// `.txt`. Sent explicitly rather than guessed from the extension: Dio types
  /// a part it was given no type for as `application/octet-stream`, and the
  /// route's `fileFilter` then judges it on the filename alone.
  final String mimeType;

  int get sizeInBytes => bytes.length;

  /// What the route's `limits.fileSize` allows. Stated here so the screen can
  /// refuse an oversized file with a sentence instead of sending ten megabytes
  /// over ward wifi to be told no.
  static const int maxBytes = 10 * 1024 * 1024;

  bool get isTooLarge => sizeInBytes > maxBytes;

  /// `48 KB`. Beside the filename, because "results.csv" alone does not tell
  /// somebody whether they picked the export or the empty template.
  String get sizeLabel {
    const unit = 1024;
    if (sizeInBytes < unit) return '$sizeInBytes B';
    final kb = sizeInBytes / unit;
    if (kb < unit) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    return '${(kb / unit).toStringAsFixed(1)} MB';
  }
}

/// A source of result files to post to the analyser import route.
abstract interface class FileSource {
  /// The chosen file, or null when the person backed out of the picker.
  Future<PickedFile?> pick();
}

/// The implementation this build ships with.
///
/// It answers with a real, parseable CSV rather than with null, so every step
/// downstream of the picker — the multipart post, the progress bar, the queue
/// the import lands on — is exercised end to end on a build that has no picker
/// plugin in it. A stub that returned null would leave the whole upload path
/// untested and looking finished.
class StubFileSource implements FileSource {
  const StubFileSource();

  /// Two analytes for one sample, in the column names `parseResultsFile` reads.
  ///
  /// Deliberately **not** a real patient's MRN: this text ships inside the
  /// application binary, and a sample file with a live identifier in it is a
  /// patient identifier in a place no retention policy covers.
  static const String sampleCsv = 'Patient ID,Test Code,Test Name,Result,Unit\n'
      'SAMPLE-001,WBC,White cell count,7.4,10^9/L\n'
      'SAMPLE-001,HGB,Haemoglobin,13.9,g/dL\n';

  @override
  Future<PickedFile?> pick() async => PickedFile(
        bytes: Uint8List.fromList(utf8.encode(sampleCsv)),
        // Fixed rather than stamped with the clock: this is the only file this
        // build can produce, and a name a test can spell is a name a test can
        // assert the server was sent.
        filename: 'analyser-results.csv',
        mimeType: 'text/csv',
      );
}
