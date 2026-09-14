import 'json.dart';

/// The connection config and the test map, whichever way the route sent them.
///
/// Prisma stores both as JSON inside a text column; the integrations service
/// parses them before answering, and the settings route does not. A model that
/// reads only the parsed form shows an analyser with no address on it.
Map<String, dynamic> _jsonObject(dynamic value) {
  final maps = asMapList(value);
  return maps.isEmpty ? const {} : maps.first;
}

/// An instrument wired into the lab or the imaging suite.
class MachineIntegration {
  const MachineIntegration({
    this.id = '',
    this.organizationId = '',
    this.machineName = '',
    this.machineType = '',
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.department,
    this.connectionType = '',
    this.connectionDetails = const {},
    this.testMapping = const {},
    this.isActive = true,
    this.connectionStatus = 'disconnected',
    this.lastConnectedAt,
    this.lastResultReceivedAt,
    this.queuedResults,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;

  final String machineName;

  /// `lab_analyzer`, `radiology_equipment`, `vital_signs_monitor`.
  final String machineType;

  final String? manufacturer;
  final String? model;
  final String? serialNumber;

  /// `laboratory`, `radiology`, `icu`, `emergency`.
  final String? department;

  /// `hl7`, `astm`, `rest_api`, `file_upload`, `serial`.
  final String connectionType;

  /// Host, port, protocol version — whatever the transport needs. Free-form on
  /// the backend, so it stays a map rather than a class that would 400 the
  /// first time somebody adds a key.
  final Map<String, dynamic> connectionDetails;

  /// The analyser's own test codes mapped onto this site's `LabTest` ids.
  final Map<String, dynamic> testMapping;

  final bool isActive;

  /// `connected`, `disconnected`, `error`.
  final String connectionStatus;

  final DateTime? lastConnectedAt;
  final DateTime? lastResultReceivedAt;

  /// From the `_count` block; null means the route did not count rather than
  /// that nothing is waiting.
  final int? queuedResults;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const MachineIntegration empty = MachineIntegration();

  bool get isEmpty => id.isEmpty && machineName.isEmpty;

  bool get isConnected => connectionStatus.toLowerCase() == 'connected';

  /// A machine that says it is in error, or one switched on and not talking.
  /// Both are states a lab manager has to act on; neither is a clinical state,
  /// so nothing here reaches for the acuity ramp.
  bool get needsAttention =>
      connectionStatus.toLowerCase() == 'error' || (isActive && !isConnected);

  /// `Sysmex XN-1000` — the manufacturer and model where the name does not
  /// already carry them.
  String get displayName {
    final made = [manufacturer ?? '', model ?? '']
        .where((p) => p.isNotEmpty)
        .join(' ');
    if (made.isEmpty || machineName.toLowerCase().contains(made.toLowerCase())) {
      return machineName;
    }
    return '$machineName ($made)';
  }

  /// `192.168.1.100:5000`, where the transport has an address at all.
  String get address {
    final host = asString(connectionDetails['ipAddress'] ??
        connectionDetails['ip_address'] ??
        connectionDetails['host']);
    if (host.isEmpty) return '';
    final port = asString(connectionDetails['port']);
    return port.isEmpty ? host : '$host:$port';
  }

  factory MachineIntegration.fromJson(Map<String, dynamic> json) {
    final counts = asMap(json['_count']);
    return MachineIntegration(
      id: asString(json['id'] ?? json['_id']),
      organizationId: asString(json['organizationId']),
      machineName: asString(json['machineName']),
      machineType: asString(json['machineType']),
      manufacturer: asStringOrNull(json['manufacturer']),
      // The settings route spells the same column `machineModel`.
      model: asStringOrNull(json['model'] ?? json['machineModel']),
      serialNumber: asStringOrNull(json['serialNumber']),
      department: asStringOrNull(json['department']),
      connectionType: asString(json['connectionType']),
      connectionDetails: _jsonObject(json['connectionDetails']),
      testMapping: _jsonObject(json['testMapping']),
      isActive: asBool(json['isActive'], fallback: true),
      connectionStatus:
          asString(json['connectionStatus'], fallback: 'disconnected'),
      lastConnectedAt: asDate(json['lastConnectedAt']),
      lastResultReceivedAt: asDate(json['lastResultReceivedAt']),
      queuedResults: counts['resultsQueue'] == null
          ? null
          : asInt(counts['resultsQueue']),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
    );
  }

  factory MachineIntegration.of(dynamic value) => value is Map
      ? MachineIntegration.fromJson(value.cast<String, dynamic>())
      : empty;
}
