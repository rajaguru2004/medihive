import 'department.dart';
import 'json.dart';

/// A member of staff.
///
/// Distinct from `AuthUser`, which is the *signed-in* person and carries the
/// session's permissions. This is any user the directory lists — a doctor on
/// an appointment picker, a technician on a verification line.
class StaffUser {
  const StaffUser({
    this.id = '',
    this.organizationId = '',
    this.email = '',
    this.fullName = '',
    this.firstName,
    this.lastName,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.employeeId,
    this.role,
    this.departmentId,
    this.department = Department.empty,
    this.specialization,
    this.licenseNumber,
    this.defaultCalendar,
    this.isActive = true,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String email;

  /// The backend's single name column. [firstName] and [lastName] are the
  /// newer split, present on some rows and not others, so [displayName]
  /// prefers whichever the row actually carries.
  final String fullName;

  final String? firstName;
  final String? lastName;

  final String? phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? address;

  final String? employeeId;

  /// The legacy single-role column — display only. Authorisation is decided by
  /// the permission set on `AuthUser`, never by this string.
  final String? role;

  final String? departmentId;

  /// `Department.empty` when the route did not populate one.
  final Department department;

  final String? specialization;
  final String? licenseNumber;

  /// `ethiopian` or `gregorian` — the calendar this user charts in.
  final String? defaultCalendar;

  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const StaffUser empty = StaffUser();

  bool get isEmpty => id.isEmpty && email.isEmpty;

  /// The name to put on a row. Never blank and never an email address where a
  /// name exists — a picker listing eight `@hospital.com` addresses is a
  /// picker nobody can use.
  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    final split = [firstName ?? '', lastName ?? '']
        .where((p) => p.trim().isNotEmpty)
        .join(' ')
        .trim();
    return split.isNotEmpty ? split : email;
  }

  /// Two letters at most. Three is a monogram, and a monogram in a 34 dp
  /// circle is a smudge.
  String get initials {
    final parts = displayName
        .split(RegExp(r'[\s.]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// The department's name, from the populated block or the bare id — what a
  /// row shows under a name.
  String get departmentName =>
      department.name.isNotEmpty ? department.name : '';

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    final department = Department.of(json['department']);
    return StaffUser(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asString(json['organizationId']),
      email: asString(json['email']),
      fullName: asString(json['fullName'] ?? json['name']),
      firstName: asStringOrNull(json['firstName']),
      lastName: asStringOrNull(json['lastName']),
      phone: asStringOrNull(json['phone']),
      dateOfBirth: asDate(json['dateOfBirth']),
      gender: asStringOrNull(json['gender']),
      address: asStringOrNull(json['address']),
      employeeId: asStringOrNull(json['employeeId']),
      role: asStringOrNull(json['role']),
      departmentId: asStringOrNull(json['departmentId']) ??
          (department.isEmpty ? null : department.id),
      department: department,
      specialization: asStringOrNull(json['specialization']),
      licenseNumber: asStringOrNull(json['licenseNumber']),
      defaultCalendar: asStringOrNull(json['defaultCalendar']),
      isActive: asBool(json['isActive'], fallback: true),
      lastLoginAt: asDate(json['lastLoginAt']),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
    );
  }

  factory StaffUser.of(dynamic value) =>
      value is Map ? StaffUser.fromJson(value.cast<String, dynamic>()) : empty;
}
