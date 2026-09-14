import 'consultation_model.dart';
import 'json.dart';
import 'lab_order.dart';
import 'prescription.dart';
import 'radiology_order.dart';

/// One consultation and everything the encounter produced.
///
/// `GET /api/consultations/:id` populates `prescriptions`, `labOrders` and
/// `radiologyOrders` beside the record itself; the list route populates none of
/// them. That is the whole reason this is a separate class from
/// [ConsultationModel] rather than three more nullable fields on it: a row on
/// the list and a record on the detail are genuinely different objects, and a
/// model carrying empty lists on every list row cannot say whether the
/// prescription is absent or merely not asked for.
///
/// Neither order list route accepts a `consultationId` filter — `forbidNonWhite
/// listed` makes the attempt a 400 — so these joins are the only way an app can
/// show what an encounter ordered.
class ConsultationRecord {
  const ConsultationRecord({
    required this.consultation,
    this.prescriptions = const [],
    this.labOrders = const [],
    this.radiologyOrders = const [],
  });

  final ConsultationModel consultation;

  /// Scripts written during the encounter, newest first — the order the server
  /// sends them in.
  final List<Prescription> prescriptions;

  final List<LabOrder> labOrders;
  final List<RadiologyOrder> radiologyOrders;

  /// Every drug across every script, which is what a reader of the record is
  /// actually looking for: they want the medication, not the paperwork it came
  /// on.
  List<PrescriptionItem> get prescribedItems =>
      [for (final script in prescriptions) ...script.items];

  bool get hasOrders => labOrders.isNotEmpty || radiologyOrders.isNotEmpty;

  factory ConsultationRecord.fromJson(Map<String, dynamic> json) =>
      ConsultationRecord(
        consultation: ConsultationModel.fromJson(json),
        prescriptions: asModelList(json['prescriptions'], Prescription.fromJson),
        labOrders: asModelList(json['labOrders'], LabOrder.fromJson),
        radiologyOrders:
            asModelList(json['radiologyOrders'], RadiologyOrder.fromJson),
      );
}
