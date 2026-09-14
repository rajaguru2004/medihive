/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — the instrument link, as one collection and two routes beside it
///
/// `/api/integrations` is not a collection. The module mounts the machines CRUD
/// and two routes about what those machines send: the queue their results land
/// in, and the upload that stands in for a machine with no live link. So one
/// repository rather than three, and the queue and the upload sit beside the
/// collection they belong to instead of in a class with no verbs of its own.
///
/// **Neither list route takes `page` or `limit`.** `MachineQueryDto` declares
/// `organizationId`, `machineType`, `department` and `status`;
/// `ResultsQueueQueryDto` declares `organizationId`, `status` and `machineId`.
/// The API runs `forbidNonWhitelisted`, so a paged request is a 400 for the
/// whole call — which is why [machines] and [queue] below are hand-rolled
/// rather than routed through `CrudRepository.list` and its `PagedQuery`.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:dio/dio.dart';
// `FormData` is declared by both packages; GetX's belongs to its own HTTP
// client, which this app does not use.
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../models/json.dart';
import '../models/machine_integration.dart';
import '../models/results_queue_item.dart';
import '../network/endpoints.dart';
import '../services/data_bus.dart';
import '../services/file_source.dart';
import '../utils/api_envelope.dart';
import 'crud_repository.dart';

/// What kind of instrument this is. A Prisma enum, so anything else is a 400.
///
/// Create-only: `UpdateMachineDto` declares neither this nor
/// [MachineConnection], because a device that turns out to be a different
/// machine is a different machine.
abstract final class MachineType {
  static const String labAnalyzer = 'lab_analyzer';
  static const String radiologyEquipment = 'radiology_equipment';
  static const String vitalSignsMonitor = 'vital_signs_monitor';

  static const List<String> all = [
    labAnalyzer,
    radiologyEquipment,
    vitalSignsMonitor,
  ];
}

/// How the site talks to it. Also a Prisma enum, also create-only.
abstract final class MachineConnection {
  static const String hl7 = 'hl7';
  static const String astm = 'astm';
  static const String restApi = 'rest_api';
  static const String fileUpload = 'file_upload';
  static const String serial = 'serial';

  static const List<String> all = [hl7, astm, restApi, fileUpload, serial];

  /// Whether this transport has a host and a port to configure at all.
  ///
  /// A serial cable and a dropped file have neither, and an address field on
  /// those reads as a setting somebody forgot to fill in.
  static bool hasAddress(String? type) => switch (
      (type ?? '').trim().toLowerCase()) {
        hl7 || astm || restApi => true,
        _ => false,
      };
}

/// What the machine last said about itself.
abstract final class MachineLink {
  static const String connected = 'connected';
  static const String disconnected = 'disconnected';
  static const String error = 'error';

  static const List<String> all = [connected, disconnected, error];
}

/// Where an inbound result has got to.
abstract final class ResultsQueueStatus {
  /// Received, nothing tried yet.
  static const String pending = 'pending';

  /// The identifier on the sample found exactly one patient.
  static const String matched = 'matched';

  /// Written through to the patient's record.
  static const String imported = 'imported';

  /// Nobody of that identifier on this site.
  static const String failed = 'failed';

  /// More than one candidate. A person has to choose.
  static const String manualReview = 'manual_review';

  /// In the order the queue is worked, which is also the order a filter row
  /// should offer them in.
  static const List<String> all = [
    pending,
    manualReview,
    failed,
    matched,
    imported,
  ];
}

/// What the `DataBus` calls each half of this module.
abstract final class IntegrationEntities {
  static const String machines = 'machines';
  static const String resultsQueue = 'results-queue';
}

/// What `POST /api/integrations/results/upload` answers with.
///
/// Worth modelling rather than discarding: the route accepts a file, parses it
/// and then *tries to match every row*, so "the upload worked" and "the results
/// reached a patient" are two different answers and the second is the one a
/// technician needs.
class ResultsUploadSummary {
  const ResultsUploadSummary({
    this.fileName = '',
    this.totalRows = 0,
    this.parsedRows = 0,
    this.parseErrors = const [],
    this.matched = 0,
    this.failed = 0,
    this.needsReview = 0,
    this.queued = 0,
  });

  final String fileName;
  final int totalRows;

  /// Rows the parser understood. Fewer than [totalRows] means the file had
  /// lines in a shape this backend does not read.
  final int parsedRows;

  final List<String> parseErrors;

  /// `matchedCount.success` — rows that found exactly one patient.
  final int matched;

  /// `matchedCount.failed` — rows whose identifier matched nobody.
  final int failed;

  /// `matchedCount.pending` — rows with more than one candidate, waiting for a
  /// person to choose.
  final int needsReview;

  final int queued;

  static const ResultsUploadSummary empty = ResultsUploadSummary();

  bool get isEmpty => fileName.isEmpty && queued == 0;

  /// Whether any row needs somebody to act. What decides between a quiet
  /// confirmation and a line asking them to open the queue.
  bool get needsAttention => failed > 0 || needsReview > 0;

  factory ResultsUploadSummary.fromJson(Map<String, dynamic> json) {
    final counts = asMap(json['matchedCount']);
    return ResultsUploadSummary(
      fileName: asString(json['fileName']),
      totalRows: asInt(json['totalRows']),
      parsedRows: asInt(json['parsedRows']),
      parseErrors: asStringList(json['parseErrors']),
      matched: asInt(counts['success']),
      failed: asInt(counts['failed']),
      needsReview: asInt(counts['pending']),
      queued: asInt(json['queuedResults']),
    );
  }
}

/// The devices a site talks to, and what they have sent.
///
/// The inherited [create], [update] and [delete] act on
/// `/api/integrations/machines`. [queue] and [uploadResults] are the two routes
/// beside it.
class IntegrationsRepository extends CrudRepository<MachineIntegration> {
  const IntegrationsRepository()
      : super(
          Endpoints.machines,
          MachineIntegration.fromJson,
          IntegrationEntities.machines,
        );

  /// Every device this site has registered, newest first — which is the order
  /// the route sorts them in and the only order it offers.
  ///
  /// Not `list()`: see the note at the top of this file. `organizationId` is
  /// deliberately not sent either — the controller resolves it from the bearer
  /// token, and a client that names a site it is not signed in to is a client
  /// asking to be refused.
  Future<List<MachineIntegration>> machines({
    String? machineType,
    String? department,
    String? status,
  }) async {
    final response = await client.get(
      Endpoints.machines.list,
      queryParameters: {
        'machineType': ?_trimmed(machineType),
        'department': ?_trimmed(department),
        'status': ?_trimmed(status),
      },
    );
    return ApiEnvelope.of(response)
        .orThrow()
        .listOf(MachineIntegration.fromJson);
  }

  /// Results a machine has sent, most recent first.
  Future<List<ResultsQueueItem>> queue({
    String? status,
    String? machineId,
  }) async {
    final response = await client.get(
      Endpoints.resultsQueue,
      queryParameters: {
        'status': ?_trimmed(status),
        // The route spells this `machineId` and the row spells the same column
        // `machineIntegrationId`. Sending the row's spelling is a 400, not an
        // ignored filter.
        'machineId': ?_trimmed(machineId),
      },
    );
    return ApiEnvelope.of(response).orThrow().listOf(ResultsQueueItem.fromJson);
  }

  /// Posts one result file and answers with what the server made of it.
  ///
  /// Multipart, under the field name **`file`** — the route's
  /// `FileInterceptor('file')` reads that name and nothing else, so a part sent
  /// as `results` or `upload` arrives as no file at all and the handler files
  /// an empty import under the name `upload.csv`.
  ///
  /// The media type is stated rather than inferred: Dio types a byte part it
  /// was given no type for as `application/octet-stream`, which this route
  /// accepts only when the *filename* ends in one of five extensions.
  ///
  /// [machineIntegrationId] is optional, and omitting it is not a shrug: the
  /// service files an unattributed import against a per-site
  /// `machine-manual-upload-<org>` device it creates on demand, so the queue
  /// still says where every row came from.
  Future<ResultsUploadSummary> uploadResults(
    PickedFile file, {
    String? machineIntegrationId,
    ProgressCallback? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.filename,
        contentType: DioMediaType.parse(file.mimeType),
      ),
      'machineIntegrationId': ?_trimmed(machineIntegrationId),
    });

    final envelope = await upload(
      Endpoints.resultsUpload,
      form,
      onProgress: onProgress,
    );

    // `upload` announces the machines collection — the service stamps
    // `lastResultReceivedAt` on the device it filed the import under. The rows
    // themselves are the other half, and a queue on screen elsewhere is stale
    // the moment this returns.
    if (Get.isRegistered<DataBus>()) {
      DataBus.to.changedRecord(IntegrationEntities.resultsQueue);
    }

    return ResultsUploadSummary.fromJson(envelope.object);
  }

  /// Null for a blank, so the key is dropped rather than sent empty — an empty
  /// `status` is a value the DTO's `@IsEnum` refuses.
  static String? _trimmed(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}

/// The repository and the file picker, registered once.
///
/// Every integrations screen reaches for them through `Get.find`, so a device
/// form opened from a deep link finds the same instances as one opened from the
/// hub.
abstract final class IntegrationsRepositories {
  static void register() {
    if (!Get.isRegistered<IntegrationsRepository>()) {
      Get.put(const IntegrationsRepository(), permanent: true);
    }
    // The stub until `file_picker` is a dependency — see `file_source.dart`.
    // Registered here rather than in one screen's binding so a test can swap it
    // before the screen is built.
    if (!Get.isRegistered<FileSource>()) {
      Get.put<FileSource>(const StubFileSource(), permanent: true);
    }
  }

  static IntegrationsRepository get instance =>
      Get.find<IntegrationsRepository>();
}
