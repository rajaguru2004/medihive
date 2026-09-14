/// The seven tab bodies of the patient hub.
///
/// A `part` rather than a second library: these are private to the hub — a
/// `_Summary` that another screen could construct would be a second patient
/// screen pretending to be a widget — and `_TabShell` builds all seven, so
/// they have to see each other. One screen, one module, two files, because a
/// twelve-hundred-line view is a view nobody reads to the end of.
part of 'patient_hub_view.dart';

// ── Summary ─────────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.controller});

  final PatientHubController controller;

  // Its own `Obx`: the summary is the only tab whose content comes off the
  // record rather than off a section, and `_TabShell` does not watch that.
  @override
  Widget build(BuildContext context) => Obx(() => _summary(context));

  Widget _summary(BuildContext context) {
    final patient = controller.patient.value;
    final visit = controller.lastVisit;

    return Column(
      key: PatientHubKeys.body('summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // First on the screen, and amber rather than red. An allergy is a
        // hazard to check against, not a patient who is deteriorating — and
        // red that is not a deteriorating patient costs a ward scan its
        // meaning. The word "Allergies" leads, so the tint is never the only
        // thing carrying it.
        if (patient.hasAllergies) ...[
          NoticeBanner(
            key: PatientHubKeys.allergyNotice,
            message: 'Allergies: ${patient.allergies.join(', ')}',
            icon: Icons.warning_amber_rounded,
            tint: AppColors.warning,
          ),
          const SizedBox(height: BentoSpace.action),
        ],
        if (patient.chronicConditions.isNotEmpty) ...[
          NoticeBanner(
            message:
                'Chronic conditions: ${patient.chronicConditions.join(', ')}',
            icon: Icons.monitor_heart_outlined,
          ),
          const SizedBox(height: BentoSpace.action),
        ],
        BentoCard(
          padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FactRow(label: 'MRN', value: patient.mrn.isEmpty ? '—' : patient.mrn),
              FactRow(label: 'Age', value: patient.age),
              FactRow(
                label: 'Sex',
                value: (patient.gender ?? '').isEmpty
                    ? '—'
                    : Formatters.label(patient.gender),
              ),
              FactRow(
                label: 'Blood group',
                value: (patient.bloodGroup ?? '').isEmpty
                    ? 'Not recorded'
                    : patient.bloodGroup!,
              ),
              FactRow(
                label: 'Phone',
                value: (patient.phonePrimary ?? '').isEmpty
                    ? '—'
                    : patient.phonePrimary!,
              ),
              if (patient.addressLine.isNotEmpty)
                FactRow(
                  label: 'Address',
                  value: patient.addressLine,
                  stacked: true,
                ),
              if ((patient.emergencyContactName ?? '').isNotEmpty)
                FactRow(
                  label: 'Emergency contact',
                  value: [
                    patient.emergencyContactName,
                    patient.emergencyContactPhone,
                    patient.emergencyContactRelationship,
                  ].whereType<String>().where((p) => p.isNotEmpty).join(' · '),
                  stacked: true,
                ),
              FactRow(
                label: 'Insurance',
                value: patient.hasInsurance
                    ? [
                        patient.insuranceProvider ?? 'Covered',
                        if (patient.insuranceExpired())
                          'cover expired',
                      ].join(' · ')
                    : 'Self-paying',
                // Amber, never red: an expired policy is an administrative
                // problem, not a clinical one.
                valueColor: patient.insuranceExpired()
                    ? semanticInk(context, AppColors.warning)
                    : null,
              ),
              if (patient.currentMedications.isNotEmpty)
                FactRow(
                  label: 'Current medications',
                  value: patient.currentMedications.join(', '),
                  stacked: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: BentoSpace.action),
        BentoCard(
          padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FactRow(
                label: 'Last visit',
                value: visit == null
                    ? (controller.isTabLoading(PatientHubTab.summary)
                        ? 'Loading…'
                        : 'None recorded')
                    : '${SettingsService.to.date(visit.when)} · ${visit.title}',
              ),
              FactRow(
                label: 'Right now',
                value: controller.stateInWords.isEmpty
                    ? 'Unknown'
                    : controller.stateInWords,
                stacked: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Visits ──────────────────────────────────────────────────────────────────

class _Visits extends StatelessWidget {
  const _Visits({required this.controller});

  final PatientHubController controller;

  @override
  Widget build(BuildContext context) {
    final rows = controller.visits;

    return BentoCard(
      key: PatientHubKeys.body('visits'),
      padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Hairline(indent: BentoSpace.listPad),
            BentoRow(
              key: PatientHubKeys.row('visits', rows[i].id),
              // The kind is a **category**, so it gets a glyph and a neutral
              // tint. Routing it through the acuity ramp would paint an
              // emergency visit type with the meaning "triaged immediate".
              icon: rows[i].kind == VisitKind.appointment
                  ? Icons.event_outlined
                  : Icons.description_outlined,
              title: rows[i].title,
              subtitle: [
                SettingsService.to.date(rows[i].when),
                if ((rows[i].subtitle ?? '').isNotEmpty) rows[i].subtitle!,
              ].join(' · '),
              subtitleMaxLines: 2,
              // Not tappable, deliberately. The appointment and consultation
              // detail screens are another stream's and are not in the route
              // table yet; a row that pushes a name nothing answers to lands
              // on "Screen not found", which reads as a broken app rather than
              // as an unfinished one.
              showChevron: false,
              trailing: (rows[i].status ?? '').isEmpty
                  ? null
                  : StatusPill(status: rows[i].status!, compact: true),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Vitals ──────────────────────────────────────────────────────────────────

class _Vitals extends StatelessWidget {
  const _Vitals({required this.controller});

  final PatientHubController controller;

  @override
  Widget build(BuildContext context) {
    final visit = controller.latestConsultation!;
    final flagged = controller.flaggedVitals;
    final worst = controller.worstVital;

    final tiles = <VitalTile>[
      if ((visit.temperature ?? 0) > 0)
        VitalTile(
          label: 'Temp',
          value: '${visit.temperature}',
          unit: '°C',
          tone: VitalRange.temperature(visit.temperature),
          caption: VitalRange.captions['temperature'],
        ),
      if ((visit.pulseRate ?? 0) > 0)
        VitalTile(
          label: 'Pulse',
          value: '${visit.pulseRate}',
          unit: 'bpm',
          tone: VitalRange.pulse(visit.pulseRate),
          caption: VitalRange.captions['pulse'],
        ),
      if ((visit.bloodPressureSystolic ?? 0) > 0)
        VitalTile(
          label: 'BP',
          value: '${visit.bloodPressureSystolic}/'
              '${visit.bloodPressureDiastolic ?? 0}',
          unit: 'mmHg',
          tone: VitalRange.bloodPressure(
            visit.bloodPressureSystolic,
            visit.bloodPressureDiastolic,
          ),
          caption: VitalRange.captions['bloodPressure'],
        ),
      if ((visit.oxygenSaturation ?? 0) > 0)
        VitalTile(
          label: 'SpO₂',
          value: '${visit.oxygenSaturation}',
          unit: '%',
          tone: VitalRange.oxygenSaturation(visit.oxygenSaturation),
          caption: VitalRange.captions['oxygenSaturation'],
        ),
      if ((visit.respiratoryRate ?? 0) > 0)
        VitalTile(
          label: 'Resp',
          value: '${visit.respiratoryRate}',
          unit: '/min',
          tone: VitalRange.respiratoryRate(visit.respiratoryRate),
          caption: VitalRange.captions['respiratoryRate'],
        ),
      if ((visit.weight ?? 0) > 0)
        VitalTile(label: 'Weight', value: '${visit.weight}', unit: 'kg'),
    ];

    return Column(
      key: PatientHubKeys.body('vitals'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // First, because it changes what everything under it means: the tiles
        // are coloured by adult ranges, and on a child those are wrong in both
        // directions.
        if (controller.isPaediatric) ...[
          const NoticeBanner(
            message: VitalRange.paediatricWarning,
            icon: Icons.child_care_outlined,
          ),
          const SizedBox(height: BentoSpace.action),
        ],
        // In words, and above the grid. The tiles colour their figures, and
        // colour alone fails three readers at once: somebody colour-blind,
        // somebody reading a printout, and somebody across a corridor.
        if (flagged.isNotEmpty) ...[
          NoticeBanner(
            key: PatientHubKeys.vitalsNotice,
            message: flagged.length == 1
                ? '${flagged.single} is outside the normal range.'
                : '${flagged.length} observations are outside the normal '
                    'range: ${flagged.join(', ')}.',
            icon: Icons.priority_high_rounded,
            tint: worst ?? AppColors.warning,
          ),
          const SizedBox(height: BentoSpace.action),
        ],
        BentoCard(
          child: tiles.isEmpty
              ? Text(
                  'Nothing was recorded at that visit.',
                  style: AppFonts.text(
                    fontSize: 13,
                    color: secondaryLabelColor(context),
                  ),
                )
              : VitalsGrid(tiles: tiles),
        ),
        const SizedBox(height: BentoSpace.action),
        Text(
          'Taken at the visit on ${SettingsService.to.date(visit.visitDate)}.',
          style: AppFonts.text(
            fontSize: 12,
            height: 1.4,
            color: tertiaryLabelColor(context),
          ),
        ),
      ],
    );
  }
}

// ── Orders ──────────────────────────────────────────────────────────────────

class _Orders extends StatelessWidget {
  const _Orders({required this.controller});

  final PatientHubController controller;

  @override
  Widget build(BuildContext context) {
    final lab = controller.labOrders.items;
    final imaging = controller.radiologyOrders.items;

    return Column(
      key: PatientHubKeys.body('orders'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lab.isNotEmpty) ...[
          const SectionHeader(title: 'Laboratory', inset: true),
          BentoCard(
            padding:
                const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < lab.length; i++) ...[
                  if (i > 0) const Hairline(indent: BentoSpace.listPad),
                  _OrderRow(
                    key: PatientHubKeys.row('orders', lab[i].id),
                    title: lab[i].testSummary.isEmpty
                        ? lab[i].orderNumber
                        : lab[i].testSummary,
                    reference: lab[i].orderNumber,
                    when: lab[i].orderDate,
                    status: lab[i].status,
                    urgent: lab[i].isStat,
                    icon: Icons.science_outlined,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (lab.isNotEmpty && imaging.isNotEmpty)
          const SizedBox(height: BentoSpace.section),
        if (imaging.isNotEmpty) ...[
          const SectionHeader(title: 'Imaging', inset: true),
          BentoCard(
            padding:
                const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < imaging.length; i++) ...[
                  if (i > 0) const Hairline(indent: BentoSpace.listPad),
                  _OrderRow(
                    key: PatientHubKeys.row('orders', imaging[i].id),
                    title: imaging[i].examName,
                    reference: imaging[i].orderNumber,
                    when: imaging[i].orderDate,
                    status: imaging[i].status,
                    urgent: imaging[i].isStat,
                    icon: Icons.monitor_heart_outlined,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    super.key,
    required this.title,
    required this.reference,
    required this.when,
    required this.status,
    required this.urgent,
    required this.icon,
  });

  final String title;
  final String reference;
  final DateTime? when;
  final String status;
  final bool urgent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return BentoRow(
      icon: icon,
      title: title,
      subtitle: [
        reference,
        if (when != null) SettingsService.to.date(when),
      ].where((part) => part.isNotEmpty).join(' · '),
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Amber, not red. A STAT order is work to be done soon; red belongs
          // to a patient who is deteriorating.
          if (urgent) ...[
            const StatusPill(
              status: 'stat',
              label: 'STAT',
              color: AppColors.acuityUrgent,
              compact: true,
            ),
            const SizedBox(width: 6),
          ],
          StatusPill(
            status: status,
            label: Formatters.label(status),
            compact: true,
          ),
        ],
      ),
    );
  }
}

// ── Results ─────────────────────────────────────────────────────────────────

class _Results extends StatelessWidget {
  const _Results({required this.controller});

  final PatientHubController controller;

  @override
  Widget build(BuildContext context) {
    final rows = controller.results;
    final unverified = controller.unverifiedCriticalResults;

    return Column(
      key: PatientHubKeys.body('results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The one place on this screen that earns red, and it says so in
        // words: a critical result nobody has signed off is somebody who has
        // to be told, not a row to be noticed.
        if (unverified.isNotEmpty) ...[
          NoticeBanner(
            key: PatientHubKeys.criticalNotice,
            message: unverified.length == 1
                ? 'One critical result has not been verified: '
                    '${unverified.single.testName}. Tell the ward.'
                : '${unverified.length} critical results have not been '
                    'verified: '
                    '${unverified.map((r) => r.testName).join(', ')}. '
                    'Tell the ward.',
            icon: Icons.priority_high_rounded,
            tint: AppColors.acuityCritical,
          ),
          const SizedBox(height: BentoSpace.action),
        ],
        BentoCard(
          padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Hairline(indent: BentoSpace.listPad),
                _ResultRow(
                  key: PatientHubKeys.row('results', rows[i].id),
                  result: rows[i],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({super.key, required this.result});

  final LabResult result;

  @override
  Widget build(BuildContext context) {
    final critical = result.isCritical;
    final tone = critical
        ? AppColors.acuityCritical
        : (result.isAbnormal ? AppColors.acuityUrgent : null);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpace.listPad,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.testName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).brightness == Brightness.dark
                      ? AppTextStyles.darkCallout()
                      : AppTextStyles.lightCallout(),
                ),
                const SizedBox(height: 4),
                // Never ellipsised: `16…` could be 160, 168 or 16, and this is
                // the figure somebody acts on. `VitalFigure` shrinks instead.
                VitalFigure(
                  value: result.resultValue,
                  unit: result.unit,
                  size: 17,
                  tone: tone,
                ),
                const SizedBox(height: 3),
                Text(
                  'Reference ${result.referenceDisplay}',
                  style: AppFonts.text(
                    fontSize: 12,
                    color: tertiaryLabelColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Colour *and* word. A red figure with no label beside it is a red
          // figure to everybody who cannot see red.
          if (critical)
            StatusPill(
              status: 'critical',
              label: result.isVerified ? 'Critical' : 'Critical · unverified',
              color: AppColors.acuityCritical,
              compact: true,
            )
          else if (result.isAbnormal)
            const StatusPill(
              status: 'abnormal',
              label: 'Abnormal',
              color: AppColors.acuityUrgent,
              compact: true,
            )
          else if (!result.isVerified)
            const StatusPill(
              status: 'unverified',
              label: 'Unverified',
              color: AppColors.acuityReview,
              compact: true,
            ),
        ],
      ),
    );
  }
}

// ── Prescriptions ───────────────────────────────────────────────────────────

class _Prescriptions extends StatelessWidget {
  const _Prescriptions({required this.controller});

  final PatientHubController controller;

  @override
  Widget build(BuildContext context) {
    final rows = controller.prescriptions.items;
    final outstanding = controller.outstandingPrescriptions.length;

    return Column(
      key: PatientHubKeys.body('prescriptions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (outstanding > 0) ...[
          NoticeBanner(
            message: outstanding == 1
                ? 'One prescription is still waiting to be dispensed.'
                : '$outstanding prescriptions are still waiting to be '
                    'dispensed.',
            icon: Icons.medication_outlined,
          ),
          const SizedBox(height: BentoSpace.action),
        ],
        BentoCard(
          padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Hairline(indent: BentoSpace.listPad),
                _PrescriptionRow(
                  key: PatientHubKeys.row('prescriptions', rows[i].id),
                  script: rows[i],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  const _PrescriptionRow({super.key, required this.script});

  final Prescription script;

  @override
  Widget build(BuildContext context) {
    return BentoRow(
      icon: Icons.medication_outlined,
      title: script.itemSummary.isEmpty
          ? '${script.itemCount} item${script.itemCount == 1 ? '' : 's'}'
          : script.itemSummary,
      subtitle: [
        if (script.prescriptionDate != null)
          SettingsService.to.date(script.prescriptionDate),
        script.doctor.fullName,
      ].where((part) => part.trim().isNotEmpty).join(' · '),
      subtitleMaxLines: 2,
      showChevron: false,
      trailing: StatusPill(
        status: script.status,
        label: Formatters.label(script.status),
        // Amber for outstanding work, green for done. Never red: a script
        // waiting at the counter is a queue, not a deteriorating patient.
        color: script.isDispensed
            ? AppColors.success
            : (script.isCancelled
                ? AppColors.acuityDischarged
                : AppColors.warning),
        compact: true,
      ),
    );
  }
}

// ── Billing ─────────────────────────────────────────────────────────────────

class _Billing extends StatelessWidget {
  const _Billing({required this.controller});

  final PatientHubController controller;

  @override
  Widget build(BuildContext context) {
    final rows = controller.invoices.items;
    final money = SettingsService.to.money;
    final outstanding = controller.balanceDue;

    return Column(
      key: PatientHubKeys.body('billing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BentoCard(
          child: MoneyFigure(
            label: 'Outstanding',
            amount: money(outstanding),
            caption: outstanding <= 0
                ? 'Nothing owed on this record'
                : 'Across ${rows.length} invoice'
                    '${rows.length == 1 ? '' : 's'}',
            // Ledger blue, never the acuity ramp: money is not a clinical
            // state, and an unpaid bill is not a patient in trouble.
            color: outstanding > 0 ? semanticInk(context, AppColors.accent) : null,
          ),
        ),
        const SizedBox(height: BentoSpace.action),
        BentoCard(
          padding: const EdgeInsets.symmetric(vertical: BentoSpace.listCardPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Hairline(indent: BentoSpace.listPad),
                _InvoiceRow(
                  key: PatientHubKeys.row('billing', rows[i].id),
                  invoice: rows[i],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final money = SettingsService.to.money;
    final overdue = invoice.overdue();

    // `DocumentRow` pairs its lines: the number sits opposite the total, what
    // the invoice is for sits opposite its state, and the third line runs the
    // full width. So the total goes in `amount` and the outstanding balance —
    // the longer, more variable figure — goes on the line that has room.
    return DocumentRow(
      number: invoice.invoiceNumber,
      title: invoice.items.isEmpty
          ? '${invoice.itemCount} line${invoice.itemCount == 1 ? '' : 's'}'
          : invoice.items.map((item) => item.description).join(', '),
      amount: money(invoice.totalAmount),
      subtitle: [
        if (invoice.invoiceDate != null)
          SettingsService.to.date(invoice.invoiceDate),
        if (invoice.outstanding > 0)
          '${money(invoice.outstanding)} outstanding'
        else
          'Settled',
      ].join(' · '),
      status: overdue ? 'Overdue' : Formatters.label(invoice.paymentStatus),
      // Amber for overdue, never red — an unpaid bill is an administrative
      // problem and red on a clinical screen means a patient is in trouble.
      statusColor: overdue
          ? AppColors.warning
          : (invoice.isPaid
              ? AppColors.success
              : (invoice.isCancelled
                  ? AppColors.acuityDischarged
                  : AppColors.accent)),
      dimmed: invoice.isCancelled,
    );
  }
}
