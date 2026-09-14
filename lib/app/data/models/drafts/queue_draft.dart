
import 'draft_json.dart';

/// A ticket joining or moving through the queue.
///
/// DTO: `hms_v2/src/modules/queue/dto/create-queue.dto.ts` and `update-
/// queue.dto.ts`.
///
/// `patientId` is create-only: a ticket belongs to the person who took it.
class QueueEntryDraft {
  const QueueEntryDraft({
    this.patientId,
    this.serviceArea,
    this.serviceType,
    this.priority,
    this.assignedToId,
    this.assignedRoom,
    this.status,
    this.estimatedWaitMinutes,
    this.displayMessage,
  });

  /// Create only.
  final String? patientId;

  /// `opd`, `emergency`, `mch` — where the patient is queueing. A service area
  /// is a category, not an acuity.
  final String? serviceArea;
  final String? serviceType;

  /// Both vocabularies are accepted: `p1`..`p5`, and
  /// `emergency`/`urgent`/`high`/`normal`/`low`/`routine`. The board orders a
  /// mix of them by rank rather than by string.
  final String? priority;
  final String? assignedToId;
  final String? assignedRoom;

  /// Update only. `waiting`, `called`, `in_service`, `completed`, `cancelled`,
  /// `no_show`.
  final String? status;

  /// Update only.
  final int? estimatedWaitMinutes;

  /// Update only. What the waiting-room screen shows this ticket.
  final String? displayMessage;

  QueueEntryDraft copyWith({
    String? patientId,
    String? serviceArea,
    String? serviceType,
    String? priority,
    String? assignedToId,
    String? assignedRoom,
    String? status,
    int? estimatedWaitMinutes,
    String? displayMessage,
  }) =>
      QueueEntryDraft(
        patientId: patientId ?? this.patientId,
        serviceArea: serviceArea ?? this.serviceArea,
        serviceType: serviceType ?? this.serviceType,
        priority: priority ?? this.priority,
        assignedToId: assignedToId ?? this.assignedToId,
        assignedRoom: assignedRoom ?? this.assignedRoom,
        status: status ?? this.status,
        estimatedWaitMinutes: estimatedWaitMinutes ?? this.estimatedWaitMinutes,
        displayMessage: displayMessage ?? this.displayMessage,
      );

  Map<String, dynamic> _shared() => {
        'serviceArea': serviceArea,
        'serviceType': serviceType,
        'priority': priority,
        'assignedToId': assignedToId,
        'assignedRoom': assignedRoom,
      };

  Map<String, dynamic> toCreateJson() => draftBody({
        'patientId': patientId,
        ..._shared(),
      });

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'status': status,
        'estimatedWaitMinutes': estimatedWaitMinutes,
        'displayMessage': displayMessage,
      });
}
