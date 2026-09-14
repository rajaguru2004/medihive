/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — imaging, as three collections and one upload
///
/// An exam is what can be ordered, an order is one patient's request for it,
/// and a report is the radiologist's read of what came back. Three routes with
/// the same five verbs, so three [CrudRepository] subclasses — each adding only
/// the calls that are genuinely its own.
///
/// The one thing shared across them is the entity name each announces on the
/// `DataBus`, because the worklist watches all three: a report written from a
/// detail screen changes a row on the worklist behind it.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:convert';

import 'package:dio/dio.dart';
// `FormData` is declared by both packages; GetX's belongs to its own HTTP
// client, which this app does not use.
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../models/json.dart';
import '../models/radiology_exam.dart';
import '../models/radiology_order.dart';
import '../models/radiology_report.dart';
import '../network/endpoints.dart';
import '../services/image_source.dart';
import '../utils/api_envelope.dart';
import 'crud_repository.dart';

/// The order states the server's `@IsIn` accepts, in the order a study moves
/// through them.
///
/// Spelled exactly as the column stores them — `in_progress`, with the
/// underscore — because any other spelling is a 400 on the PATCH that moves
/// the order along.
abstract final class RadiologyOrderStatus {
  static const String pending = 'pending';
  static const String scheduled = 'scheduled';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String reported = 'reported';
  static const String cancelled = 'cancelled';

  static const List<String> all = [
    pending,
    scheduled,
    inProgress,
    completed,
    reported,
    cancelled,
  ];
}

/// How soon the study is wanted. `routine` → `urgent` → `stat`.
///
/// Imaging spells this `urgency`; the lab spells the same ladder `priority`.
/// Both are kept as their backend names them, because a harmonised name is a
/// 400.
abstract final class RadiologyUrgency {
  static const String routine = 'routine';
  static const String urgent = 'urgent';
  static const String stat = 'stat';

  static const List<String> all = [routine, urgent, stat];
}

/// A report's lifecycle. A `final` report that is changed becomes `amended`
/// and carries the reason it was.
abstract final class RadiologyReportStatus {
  static const String draft = 'draft';
  static const String isFinal = 'final';
  static const String amended = 'amended';

  static const List<String> all = [draft, isFinal, amended];
}

/// What the `DataBus` calls each imaging collection.
abstract final class RadiologyEntities {
  static const String orders = 'radiology-orders';
  static const String reports = 'radiology-reports';
  static const String exams = 'radiology-exams';
}

/// The five figures `GET /api/radiology/stats/summary` answers with.
class RadiologyStats {
  const RadiologyStats({
    this.pending = 0,
    this.inProgress = 0,
    this.completedToday = 0,
    this.criticalFindings = 0,
    this.totalExams = 0,
  });

  final int pending;
  final int inProgress;

  /// Studies completed **today**, not in total. Named as the server names it,
  /// because a figure labelled "Completed" that resets overnight is one
  /// somebody reports as a bug.
  final int completedToday;

  /// Reports carrying a critical finding that nobody has verified yet. The
  /// server counts unverified ones only, which is what makes it a worklist
  /// figure rather than a historical one.
  final int criticalFindings;

  final int totalExams;

  static const RadiologyStats empty = RadiologyStats();

  factory RadiologyStats.fromJson(Map<String, dynamic> json) => RadiologyStats(
        pending: asInt(json['pending']),
        inProgress: asInt(json['inProgress']),
        completedToday: asInt(json['completedToday']),
        criticalFindings: asInt(json['criticalFindings']),
        totalExams: asInt(json['totalExams']),
      );
}

/// The imaging catalogue — what a clinician can ask for.
class RadiologyExamRepository extends CrudRepository<RadiologyExam> {
  const RadiologyExamRepository()
      : super(
          Endpoints.radiologyExams,
          RadiologyExam.fromJson,
          RadiologyEntities.exams,
        );

  /// The whole catalogue, optionally narrowed to one modality group.
  ///
  /// `GET /api/radiology/exams` takes `category` and nothing else — it has no
  /// pagination DTO at all, so it answers a bare array however it is asked and
  /// [CrudRepository.listAll]'s page walk stops after one round.
  Future<List<RadiologyExam>> catalogue({String? category}) => listAll(
        params: {if (category != null && category.isNotEmpty) 'category': category},
      );
}

/// Imaging requests.
class RadiologyOrderRepository extends CrudRepository<RadiologyOrder> {
  const RadiologyOrderRepository()
      : super(
          Endpoints.radiologyOrders,
          RadiologyOrder.fromJson,
          RadiologyEntities.orders,
        );

  /// The counts above the worklist.
  ///
  /// Its own call rather than something derived from the rows on screen: the
  /// worklist holds one page and the figures are about the whole department.
  Future<RadiologyStats> stats() async {
    final response = await client.get(Endpoints.radiologyStats);
    return RadiologyStats.fromJson(ApiEnvelope.of(response).orThrow().object);
  }
}

/// Radiologists' reads.
class RadiologyReportRepository extends CrudRepository<RadiologyReport> {
  const RadiologyReportRepository()
      : super(
          Endpoints.radiologyReports,
          RadiologyReport.fromJson,
          RadiologyEntities.reports,
        );

  /// Every report against one order. A bare array; `ApiEnvelope` flattens it.
  Future<List<RadiologyReport>> forOrder(String orderId) async {
    final response = await client.get(
      Endpoints.radiologyReports.list,
      queryParameters: {'orderId': orderId},
    );
    return ApiEnvelope.of(response).orThrow().listOf(RadiologyReport.fromJson);
  }

  /// Posts one image and answers with the URL the server filed it under.
  ///
  /// Multipart, under the field name **`file`** — the route's
  /// `FileInterceptor('file')` reads that name and nothing else, so a part sent
  /// as `image` or `upload` arrives as no file at all and the handler throws
  /// "No file uploaded" with a 200-shaped request behind it.
  ///
  /// The media type is stated rather than inferred: Dio types a byte part it
  /// was given no type for as `application/octet-stream`, which the route's
  /// `fileFilter` refuses along with everything else outside its four.
  Future<String> uploadImage(
    PickedImage image, {
    ProgressCallback? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        image.bytes,
        filename: image.filename,
        contentType: DioMediaType.parse(image.mimeType),
      ),
    });

    final envelope = await upload(
      Endpoints.radiologyUpload,
      form,
      onProgress: onProgress,
    );
    return asString(envelope.object['url']);
  }

  /// Records the study's images on the report.
  ///
  /// Deliberately not routed through `RadiologyReportDraft`: the draft is the
  /// report **form's** body, and `images` is not a field anybody types — it is
  /// written by the upload path and nothing else. `write_contract_test.dart`
  /// holds the draft to that, so this is the only place the key is sent.
  ///
  /// The column is a text column holding JSON, which is why this encodes
  /// rather than sending a list: the DTO declares `images` as `@IsString()`,
  /// and an array there is a 400.
  Future<RadiologyReport> setImages(
    String reportId,
    List<RadiologyImage> images,
  ) =>
      update(reportId, {
        'images': jsonEncode([
          for (final image in images)
            {
              'url': image.url,
              if (image.caption != null) 'caption': image.caption,
              if (image.view != null) 'view': image.view,
            },
        ]),
      });
}

/// The three repositories, registered once.
///
/// Every imaging screen reaches for them through `Get.find`, so a screen opened
/// from a deep link finds the same instances as one opened from the worklist.
abstract final class RadiologyRepositories {
  static void register() {
    if (!Get.isRegistered<RadiologyOrderRepository>()) {
      Get.put(const RadiologyOrderRepository(), permanent: true);
    }
    if (!Get.isRegistered<RadiologyExamRepository>()) {
      Get.put(const RadiologyExamRepository(), permanent: true);
    }
    if (!Get.isRegistered<RadiologyReportRepository>()) {
      Get.put(const RadiologyReportRepository(), permanent: true);
    }
    // The stub until `image_picker` is a dependency — see `image_source.dart`.
    // Registered here rather than in one screen's binding so a test can swap
    // it before the screen is built.
    if (!Get.isRegistered<ImageSource>()) {
      Get.put<ImageSource>(const StubImageSource(), permanent: true);
    }
  }

  static RadiologyOrderRepository get orders =>
      Get.find<RadiologyOrderRepository>();
  static RadiologyExamRepository get exams =>
      Get.find<RadiologyExamRepository>();
  static RadiologyReportRepository get reports =>
      Get.find<RadiologyReportRepository>();
}
