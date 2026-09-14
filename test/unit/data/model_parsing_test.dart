import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/models/billing_service.dart';
import 'package:medihive/app/data/models/drug.dart';
import 'package:medihive/app/data/models/invoice.dart';
import 'package:medihive/app/data/models/lab_order.dart';
import 'package:medihive/app/data/models/lab_result.dart';
import 'package:medihive/app/data/models/lab_test.dart';
import 'package:medihive/app/data/models/machine_integration.dart';
import 'package:medihive/app/data/models/organization.dart';
import 'package:medihive/app/data/models/patient.dart';
import 'package:medihive/app/data/models/payment.dart';
import 'package:medihive/app/data/models/pharmacy_sale.dart';
import 'package:medihive/app/data/models/prescription.dart';
import 'package:medihive/app/data/models/radiology_order.dart';
import 'package:medihive/app/data/models/radiology_report.dart';
import 'package:medihive/app/data/models/results_queue_item.dart';
import 'package:medihive/app/data/models/site_settings.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — Reading what this backend actually sends
///
/// Three facts about it, each of which has already cost a screen:
///
///  * **a list column arrives as a string.** An invoice's `items`, an order's
///    `tests`, a study's `images`, a patient's `allergies` are all stored as
///    JSON inside text columns and handed back unparsed. A model that reads
///    them with `value is List` sees a String, returns empty, and shows a
///    prescription with no drugs on it — silently, against a good 200.
///
///  * **a date can be absent or unparseable.** It must read as null, never as
///    now. A missing date of birth that defaults to today makes every unknown
///    patient a neonate, and a neonate is the one age at which a weight-based
///    dose is checked against the number on the screen.
///
///  * **a number can be a numeric string.** Money especially: a total that
///    parses to zero is a bill nobody chases.
///
/// A fourth: a route that did not populate an embedded patient must produce a
/// row, not an exception. A screen showing a blank field is recoverable; a
/// screen that failed to parse is not.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('a list column that arrived as a JSON string', () {
    test('a lab order reads its tests', () {
      final order = LabOrder.fromJson(const {
        'id': 'ord-1',
        'orderNumber': 'LAB-001',
        'tests': '[{"testId":"t1","testName":"CBC","urgency":"stat"},'
            '{"testId":"t2","testName":"U&E"}]',
      });

      expect(order.tests, hasLength(2));
      expect(order.tests.first.testName, 'CBC');
      expect(order.tests.first.urgency, 'stat');
      expect(order.testSummary, 'CBC, U&E');
    });

    test('a prescription reads its items', () {
      final prescription = Prescription.fromJson(const {
        'id': 'rx-1',
        'items': '[{"drugId":"d1","drugName":"Amoxicillin","quantity":21,'
            '"dosage":"500mg","frequency":"TDS","duration":"7 days"}]',
      });

      expect(prescription.items, hasLength(1));
      expect(prescription.items.single.quantity, 21);
      expect(prescription.items.single.sig, '500mg · TDS · 7 days');
    });

    test('an invoice reads its lines, and they sum', () {
      final invoice = Invoice.fromJson(const {
        'id': 'inv-1',
        'items': '[{"type":"service","description":"Consultation",'
            '"quantity":1,"unitPrice":300,"tax":45,"total":345},'
            '{"type":"lab","description":"CBC","quantity":1,'
            '"unitPrice":120,"total":120}]',
        'totalAmount': 465,
      });

      expect(invoice.items, hasLength(2));
      expect(invoice.lineTotal, 465);
    });

    test('a sale reads its lines', () {
      final sale = PharmacySale.fromJson(const {
        'id': 'sale-1',
        'items': '[{"drugId":"d1","drugName":"Amoxicillin","quantity":21,'
            '"unitPrice":12.5,"total":262.5}]',
      });

      expect(sale.items, hasLength(1));
      expect(sale.items.single.total, 262.5);
    });

    test('a radiology report reads its images', () {
      final report = RadiologyReport.fromJson(const {
        'id': 'rep-1',
        'images': '[{"url":"https://pacs/1.jpg","view":"AP"},'
            '{"url":"https://pacs/2.jpg","view":"lateral"}]',
      });

      expect(report.images, hasLength(2));
      expect(report.images.last.view, 'lateral');
    });

    test('a patient reads allergies, and keeps one that is not JSON', () {
      // `allergies: "penicillin"` is one allergy, and an allergy this app
      // drops on the floor is the worst possible way to be tidy.
      final structured = Patient.fromJson(const {
        'id': 'pat-1',
        'allergies': '["Penicillin","Sulfa"]',
      });
      expect(structured.allergies, const ['Penicillin', 'Sulfa']);
      expect(structured.hasAllergies, isTrue);

      final bare = Patient.fromJson(const {
        'id': 'pat-2',
        'allergies': 'penicillin',
      });
      expect(bare.allergies, const ['penicillin']);
    });

    test('a lab test reads reference ranges in either stored shape', () {
      // Keyed by sex, which is how the seed data writes them.
      final keyed = LabTest.fromJson(const {
        'id': 'test-1',
        'testName': 'Potassium',
        'referenceRanges': '{"male":{"min":3.5,"max":5.1},'
            '"female":{"min":3.4,"max":5.0}}',
      });
      expect(keyed.referenceRanges, hasLength(2));
      expect(keyed.referenceRanges.first.label, 'male');
      expect(keyed.referenceRanges.first.display, '3.5 – 5.1');

      // A flat array, which is how the console writes them.
      final flat = LabTest.fromJson(const {
        'id': 'test-2',
        'testName': 'Sodium',
        'referenceRanges': [
          {'label': 'adult', 'min': 135, 'max': 145},
        ],
      });
      expect(flat.referenceRanges.single.label, 'adult');
    });

    test('an unparsed JSON object still reads as a map', () {
      // The integrations route parses `connectionDetails` before answering
      // and the settings route does not. A model that reads only the parsed
      // form shows an analyser with no address on it.
      final machine = MachineIntegration.fromJson(const {
        'id': 'm-1',
        'machineName': 'Sysmex XN-1000',
        'connectionDetails': '{"ipAddress":"192.168.1.100","port":5000}',
      });
      expect(machine.address, '192.168.1.100:5000');

      final parsed = MachineIntegration.fromJson(const {
        'id': 'm-2',
        'machineName': 'Mindray',
        'connectionDetails': {'ipAddress': '10.0.0.4'},
      });
      expect(parsed.address, '10.0.0.4');
    });

    test('a results-queue row reads its analytes', () {
      final row = ResultsQueueItem.fromJson(const {
        'id': 'q-1',
        'testResults': '[{"code":"WBC","value":"9.1"},'
            '{"code":"HGB","value":"13.4"}]',
      });
      expect(row.resultCount, 2);
    });

    test('an organisation reads settings stored as a string', () {
      final org = Organization.fromJson(const {
        'id': 'org-1',
        'name': 'General Hospital',
        'settings': '{"locale":{"currency":"ETB","currencySymbol":"Br"},'
            '"clinical":{"waitBreachMinutes":45}}',
        'modulesEnabled': '{"pharmacy":true,"inpatient":false}',
      });

      expect(org.settings.locale.currency, 'ETB');
      expect(org.settings.clinical.waitBreachMinutes, 45);
      expect(org.moduleEnabled('pharmacy'), isTrue);
      expect(org.moduleEnabled('inpatient'), isFalse);
    });

    test('a column with nothing in it is an empty list, not a crash', () {
      for (final empty in [null, '', '[]', 'null']) {
        expect(
          LabOrder.fromJson({'id': 'ord-1', 'tests': empty}).tests,
          isEmpty,
          reason: 'tests: $empty',
        );
      }
    });
  });

  group('a date that is missing or unreadable', () {
    test('a patient without a date of birth is not a neonate', () {
      // `0000-00-00` is deliberately absent: `DateTime.tryParse` accepts it
      // and answers year -1. It cannot come out of this Postgres backend, and
      // the shape it produces is an absurd age rather than a plausible one.
      for (final value in [null, '', 'not-a-date', 'null', 'undefined']) {
        final patient = Patient.fromJson({'id': 'pat-1', 'dateOfBirth': value});
        expect(patient.dateOfBirth, isNull, reason: 'dateOfBirth: $value');
        expect(patient.age, '—');
      }
    });

    test('an invoice without a due date is never overdue', () {
      final invoice = Invoice.fromJson(const {
        'id': 'inv-1',
        'dueDate': 'sometime',
        'totalAmount': 500,
      });
      expect(invoice.dueDate, isNull);
      expect(invoice.overdue(asOf: DateTime(2030)), isFalse);
    });

    test('a result with no verification time is not verified', () {
      final result = LabResult.fromJson(const {
        'id': 'res-1',
        'resultValue': '7.2',
        'verifiedAt': null,
      });
      expect(result.verifiedAt, isNull);
      expect(result.isVerified, isFalse);
    });

    test('stock with no recorded expiry is not expired stock', () {
      final drug = Drug.fromJson(const {
        'id': 'd-1',
        'drugName': 'Amoxicillin',
        'quantityInStock': 100,
        'batches': [
          {'id': 'b-1', 'batchNumber': 'B1', 'expiryDate': ''},
        ],
      });
      expect(drug.nextBatch?.expiryDate, isNull);
      expect(drug.expiringStock(asOf: DateTime(2030)), isFalse);
    });

    test('a good date is still read', () {
      final patient = Patient.fromJson(const {
        'id': 'pat-1',
        'dateOfBirth': '1990-05-15T00:00:00.000Z',
      });
      expect(patient.dateOfBirth, DateTime.utc(1990, 5, 15));
      expect(patient.age, isNot('—'));
    });
  });

  group('an embedded patient that never came', () {
    test('a lab order without one still renders', () {
      final order = LabOrder.fromJson(const {
        'id': 'ord-1',
        'patientId': 'pat-1',
        'orderNumber': 'LAB-001',
      });
      expect(order.patient.isEmpty, isTrue);
      expect(order.patient.displayName, isNotEmpty);
      expect(order.patientId, 'pat-1');
    });

    test('a populated block supplies the id the row omitted', () {
      // `asRefId` reads Mongo's `_id`; this backend is Prisma and spells it
      // `id`, so the populated document is what the fallback comes from.
      final order = LabOrder.fromJson(const {
        'id': 'ord-1',
        'patient': {'id': 'pat-9', 'mrn': 'MRN-9', 'firstName': 'Abebe'},
      });
      expect(order.patientId, 'pat-9');
      expect(order.patient.displayName, 'Abebe');
    });

    test('a patient sent as a bare id string does not throw', () {
      final invoice = Invoice.fromJson(const {
        'id': 'inv-1',
        'patientId': 'pat-1',
        'patient': 'pat-1',
      });
      expect(invoice.patient.isEmpty, isTrue);
      expect(invoice.patientId, 'pat-1');
    });

    test('an unmatched machine result names the sample anyway', () {
      final row = ResultsQueueItem.fromJson(const {
        'id': 'q-1',
        'patientIdentifier': 'TUBE-55',
      });
      expect(row.isMatched, isFalse);
      expect(row.subjectLabel, 'TUBE-55');

      final anonymous = ResultsQueueItem.fromJson(const {'id': 'q-2'});
      expect(anonymous.subjectLabel, 'Unidentified sample');
    });

    test('an unreported study is null, not an empty report', () {
      // "Not yet reported" is a state a worklist filters on, and an empty
      // report object reads as a blank one somebody has already written.
      final order = RadiologyOrder.fromJson(const {
        'id': 'ord-1',
        'examId': 'exam-1',
      });
      expect(order.report, isNull);
      expect(order.isReported, isFalse);
      expect(order.hasCriticalFindings, isFalse);
    });

    test('a report lifts the patient off the order it came inside', () {
      final report = RadiologyReport.fromJson(const {
        'id': 'rep-1',
        'order': {
          'id': 'ord-1',
          'patient': {'id': 'pat-1', 'mrn': 'MRN-1', 'firstName': 'Abebe'},
          'exam': {'id': 'exam-1', 'examName': 'CT Head'},
        },
      });
      expect(report.orderId, 'ord-1');
      expect(report.patient.displayName, 'Abebe');
      expect(report.exam.examName, 'CT Head');
    });

    test('an empty map is an empty patient, not an exception', () {
      final sale = PharmacySale.fromJson(const {'id': 's-1', 'patient': {}});
      expect(sale.patient.isEmpty, isTrue);
      expect(sale.patientId, isNull);
    });
  });

  group('money from a number and from a numeric string', () {
    /// The default site convention: `$1,234.56`, cents hidden when whole.
    const money = MoneyFormat.fallback;

    test('an invoice total reads either way, and formats the same', () {
      final numeric = Invoice.fromJson(const {
        'id': 'inv-1',
        'totalAmount': 1234.5,
        'amountPaid': 200,
      });
      final text = Invoice.fromJson(const {
        'id': 'inv-2',
        'totalAmount': '1234.50',
        'amountPaid': '200',
      });

      expect(numeric.totalAmount, 1234.5);
      expect(text.totalAmount, 1234.5);
      expect(text.totalLabel(money), r'$1,234.50');
      expect(text.outstanding, 1034.5);
      expect(numeric.outstandingLabel(money), text.outstandingLabel(money));
    });

    test('a payment amount reads either way', () {
      expect(
        Payment.fromJson(const {'id': 'p-1', 'amount': '345.00'}).amount,
        345.0,
      );
      expect(
        Payment.fromJson(const {'id': 'p-2', 'amount': 345}).amount,
        345.0,
      );
    });

    test('a catalogue price reads either way', () {
      final service = BillingService.fromJson(const {
        'id': 'svc-1',
        'unitPrice': '300',
        'taxPercentage': '15',
        'isTaxable': 'true',
      });
      expect(service.unitPrice, 300.0);
      expect(service.taxAmount, 45.0);
      expect(service.grossPrice, 345.0);
      expect(service.priceLabel(money), r'$300');
    });

    test('a nullable price stays null rather than becoming free', () {
      // Zero is a price somebody set; absent is a price nobody has. A drug
      // shown at zero is a drug given away.
      final drug = Drug.fromJson(const {'id': 'd-1', 'drugName': 'Aspirin'});
      expect(drug.sellingPrice, isNull);
      expect(drug.priceLabel(money), '—');

      final priced = Drug.fromJson(const {
        'id': 'd-2',
        'drugName': 'Aspirin',
        'sellingPrice': '12.50',
      });
      expect(priced.sellingPrice, 12.5);
      expect(priced.priceLabel(money), r'$12.50');
    });

    test('a sale balance falls back to the arithmetic', () {
      // A balance shown as zero on a sale that is not paid is how money walks
      // out of a pharmacy.
      final sale = PharmacySale.fromJson(const {
        'id': 's-1',
        'totalAmount': '262.50',
        'amountPaid': '100',
      });
      expect(sale.outstanding, 162.5);
      expect(sale.isPaid, isFalse);
    });

    test('a refund counts against the ledger without hiding the receipt', () {
      final refund = Payment.fromJson(const {
        'id': 'p-1',
        'amount': '150.00',
        'isRefund': true,
        'paymentMethod': 'mobile_money',
      });
      expect(refund.amount, 150.0);
      expect(refund.signedAmount, -150.0);
      expect(refund.amountLabel(money), r'-$150');
      expect(refund.methodLabel, 'Mobile money');
    });

    test('the site convention travels with the figure', () {
      // A symbol concatenated onto a number is how an app ships `₹1,200.00`
      // to a site that writes `1.200,00 ₹`.
      const site = MoneyFormat(
        code: 'EUR',
        symbol: '€',
        symbolBefore: true,
        decimalSeparator: ',',
        thousandSeparator: '.',
        precision: 2,
        showZeroCents: true,
      );
      final invoice = Invoice.fromJson(const {
        'id': 'inv-1',
        'totalAmount': '1234.5',
      });
      expect(invoice.totalLabel(site), '€1.234,50');
    });
  });

  group('the rest of a row a route did not populate', () {
    test('an empty json produces a model, not an exception', () {
      expect(Patient.fromJson(const {}).isEmpty, isTrue);
      expect(LabOrder.fromJson(const {}).isEmpty, isTrue);
      expect(LabResult.fromJson(const {}).isEmpty, isTrue);
      expect(LabTest.fromJson(const {}).isEmpty, isTrue);
      expect(Invoice.fromJson(const {}).isEmpty, isTrue);
      expect(Payment.fromJson(const {}).isEmpty, isTrue);
      expect(Drug.fromJson(const {}).isEmpty, isTrue);
      expect(Prescription.fromJson(const {}).isEmpty, isTrue);
      expect(PharmacySale.fromJson(const {}).isEmpty, isTrue);
      expect(RadiologyOrder.fromJson(const {}).isEmpty, isTrue);
      expect(RadiologyReport.fromJson(const {}).isEmpty, isTrue);
      expect(MachineIntegration.fromJson(const {}).isEmpty, isTrue);
      expect(ResultsQueueItem.fromJson(const {}).isEmpty, isTrue);
      expect(Organization.fromJson(const {}).isEmpty, isTrue);
    });

    test('a defaulted flag keeps the meaning its column has', () {
      // `isActive` and `isCoveredByInsurance` both default true on the
      // backend. A model that defaults them false hides a live catalogue and
      // quotes a covered patient the full price.
      expect(Patient.fromJson(const {}).isActive, isTrue);
      expect(LabTest.fromJson(const {}).isActive, isTrue);
      expect(BillingService.fromJson(const {}).isCoveredByInsurance, isTrue);
      expect(Drug.fromJson(const {}).isActive, isTrue);
    });

    test('a module a site has no key for still shows', () {
      // Hiding a module because a key is missing is how a pharmacy disappears
      // from a working deployment.
      final org = Organization.fromJson(const {'id': 'org-1'});
      expect(org.moduleEnabled('pharmacy'), isTrue);
    });

    test('an absent settings blob falls back to the documented defaults', () {
      final org = Organization.fromJson(const {'id': 'org-1'});
      expect(org.settings.clinical.waitBreachMinutes, 30);
      expect(org.settings.clinical.showPatientNames, isTrue);
      expect(org.settings.scheduling.workingHours.start, '08:00');
      expect(org.money.code, 'INR');
    });

    test('the deprecated flat settings keys are still read', () {
      // A site provisioned before the groups existed stores only these. The
      // backend lifts them on write; this reads them so the app does not show
      // that site the product defaults in the meantime.
      final org = Organization.fromJson(const {
        'id': 'org-1',
        'settings': {
          'defaultCurrency': 'ETB',
          'defaultTimezone': 'Africa/Addis_Ababa',
          'workingHours': {'start': '07:30', 'end': '16:30'},
          'appointmentDuration': 20,
        },
      });
      expect(org.settings.locale.currency, 'ETB');
      expect(org.settings.locale.timezone, 'Africa/Addis_Ababa');
      expect(org.settings.scheduling.workingHours.start, '07:30');
      expect(org.settings.scheduling.appointmentDuration, 20);
    });

    test('an organisation round-trips into the flat settings reader', () {
      final org = Organization.fromJson(const {
        'id': 'org-1',
        'name': 'General Hospital',
        'settings': {
          'locale': {'currency': 'ETB', 'currencySymbol': 'Br'},
          'clinical': {'waitBreachMinutes': 45, 'showPatientNames': false},
        },
      });
      final site = org.siteSettings;
      expect(site.siteName, 'General Hospital');
      expect(site.waitBreachMinutes, 45);
      expect(site.showPatientNames, isFalse);
      expect(site.money.code, 'ETB');
      expect(site.money.symbol, 'Br');
    });
  });
}
