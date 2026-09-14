import 'doctor_model.dart';
import 'json.dart';
import 'patient_ref.dart';

/// One drug on a prescription.
///
/// The name is denormalised into the item rather than looked up: a drug later
/// renamed or withdrawn from the catalogue must not rewrite what a prescriber
/// actually wrote.
class PrescriptionItem {
  const PrescriptionItem({
    this.drugId = '',
    this.drugName = '',
    this.genericName,
    this.dosage,
    this.frequency,
    this.duration,
    this.quantity = 0,
    this.instructions,
  });

  final String drugId;
  final String drugName;
  final String? genericName;

  /// `500mg` — how much per administration.
  final String? dosage;

  /// `Three times daily`.
  final String? frequency;

  /// `7 days`.
  final String? duration;

  /// Total units to dispense. Never rendered ellipsised: `16…` could be 160,
  /// 168 or 16.
  final int quantity;

  final String? instructions;

  bool get isEmpty => drugId.isEmpty && drugName.isEmpty;

  /// `500mg · Three times daily · 7 days` — the sig, with the parts a
  /// prescriber left blank simply absent rather than rendered as gaps.
  String get sig => [
        dosage ?? '',
        frequency ?? '',
        duration ?? '',
      ].where((p) => p.isNotEmpty).join(' · ');

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) =>
      PrescriptionItem(
        drugId: asString(json['drugId'] ?? json['id']),
        drugName: asString(json['drugName'] ?? json['name']),
        genericName: asStringOrNull(json['genericName']),
        dosage: asStringOrNull(json['dosage']),
        frequency: asStringOrNull(json['frequency']),
        duration: asStringOrNull(json['duration']),
        quantity: asInt(json['quantity']),
        instructions: asStringOrNull(json['instructions']),
      );

  Map<String, dynamic> toJson() => {
        'drugId': drugId,
        'drugName': drugName,
        'dosage': ?dosage,
        'frequency': ?frequency,
        'duration': ?duration,
        'quantity': quantity,
        'instructions': ?instructions,
      };
}

/// A prescription, as the pharmacy reads it.
class Prescription {
  const Prescription({
    this.id = '',
    this.organizationId = '',
    this.patientId = '',
    this.consultationId,
    this.doctorId = '',
    this.prescriptionDate,
    this.items = const [],
    this.status = 'pending',
    this.dispensedById,
    this.dispensedAt,
    this.notes,
    this.isRefill = false,
    this.refillsAllowed = 0,
    this.refillsRemaining,
    this.createdAt,
    this.updatedAt,
    this.patient = PatientRef.empty,
    this.doctor = const DoctorModel(id: '', fullName: ''),
  });

  final String id;
  final String organizationId;
  final String patientId;
  final String? consultationId;
  final String doctorId;

  final DateTime? prescriptionDate;

  /// Stored by the backend as a JSON array inside a text column. Read with
  /// `asJsonList`, or the screen shows a prescription with no drugs on it.
  final List<PrescriptionItem> items;

  /// `pending`, `partially_dispensed`, `fully_dispensed`, `cancelled`.
  final String status;

  final String? dispensedById;
  final DateTime? dispensedAt;

  final String? notes;

  final bool isRefill;
  final int refillsAllowed;
  final int? refillsRemaining;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final PatientRef patient;
  final DoctorModel doctor;

  static const Prescription empty = Prescription();

  bool get isEmpty => id.isEmpty && items.isEmpty;

  bool get isDispensed => status.toLowerCase() == 'fully_dispensed';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  /// Still owed to the patient — what a counter queue is filtered on.
  bool get isOutstanding => !isDispensed && !isCancelled;

  int get itemCount => items.length;

  /// `Amoxicillin, Paracetamol` — what a row says the script is for.
  String get itemSummary =>
      items.map((i) => i.drugName).where((n) => n.isNotEmpty).join(', ');

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final patient = PatientRef.of(json['patient']);
    return Prescription(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asString(json['organizationId']),
      patientId: asString(json['patientId'], fallback: patient.id),
      consultationId: asStringOrNull(json['consultationId']),
      doctorId: asString(json['doctorId']),
      prescriptionDate: asDate(json['prescriptionDate']),
      items: asModelList(json['items'], PrescriptionItem.fromJson),
      status: asString(json['status'], fallback: 'pending'),
      dispensedById: asStringOrNull(json['dispensedById']),
      dispensedAt: asDate(json['dispensedAt']),
      notes: asStringOrNull(json['notes']),
      isRefill: asBool(json['isRefill']),
      refillsAllowed: asInt(json['refillsAllowed']),
      refillsRemaining: json['refillsRemaining'] == null
          ? null
          : asInt(json['refillsRemaining']),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
      patient: patient,
      doctor: DoctorModel.fromJson(asMap(json['doctor'])),
    );
  }

  factory Prescription.of(dynamic value) => value is Map
      ? Prescription.fromJson(value.cast<String, dynamic>())
      : empty;
}
