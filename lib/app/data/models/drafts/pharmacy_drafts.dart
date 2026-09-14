
import 'draft_json.dart';

/// A catalogue drug being added or edited.
///
/// DTO: `hms_v2/src/modules/pharmacy/dto/pharmacy-drug.dto.ts`
/// (`CreatePharmacyDrugDto` / `UpdatePharmacyDrugDto`, which adds `isActive`).
///
/// The column set is wider than the DTO: `maximumStockLevel`,
/// `markupPercentage`, `supplierName`, `supplierContact`, `sideEffects` and
/// `contraindications` are stored and returned but on neither write DTO, so
/// they are read-only from this app and absent here.
class DrugDraft {
  const DrugDraft({
    this.drugName,
    this.genericName,
    this.brandName,
    this.drugCode,
    this.drugCategory,
    this.dosageForm,
    this.strength,
    this.quantityInStock,
    this.unitOfMeasure,
    this.reorderLevel,
    this.sellingPrice,
    this.costPrice,
    this.requiresPrescription,
    this.storageLocation,
    this.description,
    this.isActive,
  });

  final String? drugName;
  final String? genericName;
  final String? brandName;
  final String? drugCode;
  final String? drugCategory;

  /// `tablet`, `capsule`, `syrup`, `injection`.
  final String? dosageForm;

  /// `500mg`, `10mg/ml`.
  final String? strength;

  /// Zero is a value, not an absence: a drug that has run out has to be able to
  /// say so.
  final int? quantityInStock;
  final String? unitOfMeasure;
  final int? reorderLevel;
  final double? sellingPrice;
  final double? costPrice;
  final bool? requiresPrescription;
  final String? storageLocation;
  final String? description;

  /// Update only.
  final bool? isActive;

  DrugDraft copyWith({
    String? drugName,
    String? genericName,
    String? brandName,
    String? drugCode,
    String? drugCategory,
    String? dosageForm,
    String? strength,
    int? quantityInStock,
    String? unitOfMeasure,
    int? reorderLevel,
    double? sellingPrice,
    double? costPrice,
    bool? requiresPrescription,
    String? storageLocation,
    String? description,
    bool? isActive,
  }) =>
      DrugDraft(
        drugName: drugName ?? this.drugName,
        genericName: genericName ?? this.genericName,
        brandName: brandName ?? this.brandName,
        drugCode: drugCode ?? this.drugCode,
        drugCategory: drugCategory ?? this.drugCategory,
        dosageForm: dosageForm ?? this.dosageForm,
        strength: strength ?? this.strength,
        quantityInStock: quantityInStock ?? this.quantityInStock,
        unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
        reorderLevel: reorderLevel ?? this.reorderLevel,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        costPrice: costPrice ?? this.costPrice,
        requiresPrescription: requiresPrescription ?? this.requiresPrescription,
        storageLocation: storageLocation ?? this.storageLocation,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> _shared() => {
        'drugName': drugName,
        'genericName': genericName,
        'brandName': brandName,
        'drugCode': drugCode,
        'drugCategory': drugCategory,
        'dosageForm': dosageForm,
        'strength': strength,
        'quantityInStock': quantityInStock,
        'unitOfMeasure': unitOfMeasure,
        'reorderLevel': reorderLevel,
        'sellingPrice': sellingPrice,
        'costPrice': costPrice,
        'requiresPrescription': requiresPrescription,
        'storageLocation': storageLocation,
        'description': description,
      };

  Map<String, dynamic> toCreateJson() => draftBody(_shared());

  Map<String, dynamic> toUpdateJson() => draftBody({
        ..._shared(),
        'isActive': isActive,
      });
}

/// One drug on a pharmacy prescription.
///
/// DTO: `PrescriptionItemDto` in
/// `hms_v2/src/modules/pharmacy/dto/prescription.dto.ts`. Narrower than the
/// consultation route's item — no `genericName` — and looser: only `drugId`,
/// `drugName` and `quantity` are required.
class PrescriptionItemDraft {
  const PrescriptionItemDraft({
    this.drugId,
    this.drugName,
    this.dosage,
    this.frequency,
    this.duration,
    this.quantity,
    this.instructions,
  });

  final String? drugId;
  final String? drugName;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final int? quantity;
  final String? instructions;

  PrescriptionItemDraft copyWith({
    String? drugId,
    String? drugName,
    String? dosage,
    String? frequency,
    String? duration,
    int? quantity,
    String? instructions,
  }) =>
      PrescriptionItemDraft(
        drugId: drugId ?? this.drugId,
        drugName: drugName ?? this.drugName,
        dosage: dosage ?? this.dosage,
        frequency: frequency ?? this.frequency,
        duration: duration ?? this.duration,
        quantity: quantity ?? this.quantity,
        instructions: instructions ?? this.instructions,
      );

  Map<String, dynamic> toJson() => draftBody({
        'drugId': drugId,
        'drugName': drugName,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
        'quantity': quantity,
        'instructions': instructions,
      });
}

/// A prescription being written, dispensed or cancelled.
///
/// DTO: `hms_v2/src/modules/pharmacy/dto/prescription.dto.ts`
/// (`CreatePrescriptionDto` / `UpdatePrescriptionDto`).
///
/// `isRefill`, `refillsAllowed` and `refillsRemaining` are stored columns with
/// no DTO keys, so a refill count cannot be set from this app.
class PrescriptionDraft {
  const PrescriptionDraft({
    this.patientId,
    this.doctorId,
    this.consultationId,
    this.items,
    this.notes,
    this.status,
  });

  /// Create only.
  final String? patientId;

  /// Create only.
  final String? doctorId;

  /// Create only.
  final String? consultationId;

  /// On both routes. An empty list is dropped rather than sent — the DTO would
  /// take it and store a script with no drugs on it.
  final List<PrescriptionItemDraft>? items;
  final String? notes;

  /// Update only. `pending`, `partially_dispensed`, `fully_dispensed`,
  /// `cancelled`.
  final String? status;

  PrescriptionDraft copyWith({
    String? patientId,
    String? doctorId,
    String? consultationId,
    List<PrescriptionItemDraft>? items,
    String? notes,
    String? status,
  }) =>
      PrescriptionDraft(
        patientId: patientId ?? this.patientId,
        doctorId: doctorId ?? this.doctorId,
        consultationId: consultationId ?? this.consultationId,
        items: items ?? this.items,
        notes: notes ?? this.notes,
        status: status ?? this.status,
      );

  List<Map<String, dynamic>>? _items() =>
      items?.map((item) => item.toJson()).toList();

  Map<String, dynamic> toCreateJson() => draftBody({
        'patientId': patientId,
        'doctorId': doctorId,
        'consultationId': consultationId,
        'items': _items(),
        'notes': notes,
      });

  Map<String, dynamic> toUpdateJson() => draftBody({
        'status': status,
        'notes': notes,
        'items': _items(),
      });
}

/// One line on a counter sale.
///
/// DTO: `PharmacySaleItemDto` in `hms_v2/src/modules/pharmacy/dto/pharmacy-
/// sale.dto.ts`. Every field but `batchId` is required.
class SaleItemDraft {
  const SaleItemDraft({
    this.drugId,
    this.batchId,
    this.drugName,
    this.quantity,
    this.unitPrice,
    this.total,
  });

  final String? drugId;
  final String? batchId;
  final String? drugName;
  final int? quantity;
  final double? unitPrice;

  /// Sent rather than derived, because the server stores the line as it was
  /// rung up and a client that recomputes can disagree with the printed
  /// receipt.
  final double? total;

  SaleItemDraft copyWith({
    String? drugId,
    String? batchId,
    String? drugName,
    int? quantity,
    double? unitPrice,
    double? total,
  }) =>
      SaleItemDraft(
        drugId: drugId ?? this.drugId,
        batchId: batchId ?? this.batchId,
        drugName: drugName ?? this.drugName,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        total: total ?? this.total,
      );

  Map<String, dynamic> toJson() => draftBody({
        'drugId': drugId,
        'batchId': batchId,
        'drugName': drugName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
      });
}

/// A pharmacy counter sale.
///
/// DTO: `CreatePharmacySaleDto` in `hms_v2/src/modules/pharmacy/dto/pharmacy-
/// sale.dto.ts`.
///
/// **There is no update route.** `/pharmacy/sales` answers GET and POST only,
/// so [toUpdateJson] is empty by construction rather than by omission — a sale
/// is corrected by a refund, not by an edit.
///
/// The stored row carries `discountAmount`, `taxAmount` and `amountPaid`; the
/// create DTO carries none of them, so a discount cannot be rung up from this
/// app. Followed the DTO.
class SaleDraft {
  const SaleDraft({
    this.patientId,
    this.prescriptionId,
    this.items,
    this.paymentMethod,
    this.paymentStatus,
  });

  /// Null for a walk-in. An over-the-counter sale has no patient record, and
  /// the DTO makes this optional for exactly that reason.
  final String? patientId;
  final String? prescriptionId;
  final List<SaleItemDraft>? items;

  /// `cash`, `credit_card`, `debit_card`, `mobile_money`, `insurance`,
  /// `bank_transfer`, `cheque`.
  final String? paymentMethod;

  /// `pending`, `paid`, `partially_paid`. Narrower than an invoice: a counter
  /// sale is never refunded in place.
  final String? paymentStatus;

  SaleDraft copyWith({
    String? patientId,
    String? prescriptionId,
    List<SaleItemDraft>? items,
    String? paymentMethod,
    String? paymentStatus,
  }) =>
      SaleDraft(
        patientId: patientId ?? this.patientId,
        prescriptionId: prescriptionId ?? this.prescriptionId,
        items: items ?? this.items,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
      );

  Map<String, dynamic> toCreateJson() => draftBody({
        'patientId': patientId,
        'prescriptionId': prescriptionId,
        'items': items?.map((item) => item.toJson()).toList(),
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
      });

  /// Always empty: the pharmacy sales route has no PATCH.
  Map<String, dynamic> toUpdateJson() => const {};
}
