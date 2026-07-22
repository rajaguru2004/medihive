class DischargePatientModel {
  final String admissionId;
  final String dischargeReason;
  final String dischargeSummary;
  final String dischargeDoctorId;
  final DateTime? followUpDate;
  final String? followUpNotes;

  DischargePatientModel({
    required this.admissionId,
    required this.dischargeReason,
    required this.dischargeSummary,
    required this.dischargeDoctorId,
    this.followUpDate,
    this.followUpNotes,
  });

  Map<String, dynamic> toJson() {
    return {
      'admissionId': admissionId,
      'dischargeReason': dischargeReason,
      'dischargeSummary': dischargeSummary,
      'dischargeDoctorId': dischargeDoctorId,
      'followUpDate': followUpDate?.toIso8601String(),
      'followUpNotes': followUpNotes,
    };
  }
}
