/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — API surface
///
/// Every path the app calls, in one file. A path spelled inline at a call site
/// is a path nobody can grep for when the backend renames a route.
///
/// The backend mounts everything under `/api` and reads the bearer token from
/// the `Authorization` header. Two tiers:
///
///   * unauthenticated — `/auth/login`, `/auth/refresh`
///   * authenticated — everything else
///
/// Collection routes follow one shape (`/<entity>`, `/<entity>/<id>`), so
/// [Crud] builds them rather than listing four near-identical constants per
/// entity.
///
/// **Only routes that exist live here.** A constant for a route the server does
/// not mount is worse than no constant: it reads as verified, and the 404 it
/// produces arrives on a screen rather than in a review.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class Endpoints {
  /// The server this build talks to.
  ///
  /// Overridden per environment without touching code:
  ///
  /// ```sh
  /// flutter run --dart-define=MEDIHIVE_API=https://api.example.com/
  /// ```
  ///
  /// The default is the **LAN address of the development machine**, so a build
  /// with no `--dart-define` reaches the API started by `npm run dev` from a
  /// phone on the same Wi-Fi. It replaced the reserved ngrok tunnel when the
  /// demo moved onto the local network.
  ///
  /// Two things this default depends on, both of which fail silently:
  ///
  /// - **The address is DHCP.** When the laptop's lease changes, this constant
  ///   is stale and every request times out. `npm run dev` prints the current
  ///   LAN address on startup; if it is not the one below, pass
  ///   `--dart-define=MEDIHIVE_API=...` or change it here.
  /// - **It is plain http.** Android forbids cleartext by default, so
  ///   `android/app/src/{main,debug}/res/xml/network_security_config.xml`
  ///   names this exact address. Changing the address here without changing it
  ///   there produces a network failure with no explanation attached.
  ///
  /// It was `http://10.0.2.2:3000/` — the Android *emulator's* loopback to the
  /// host. That is right for `flutter run` on an emulator and wrong everywhere
  /// else, and the failure it produces is the worst kind: a physical handset
  /// cannot resolve `10.0.2.2` at all, so every request hangs to its timeout
  /// and the app shows "we could not reach the hospital" with nothing to say
  /// the address was never reachable in the first place. That cost a debugging
  /// round on a real device.
  ///
  /// If the phone has to reach the API from off this network, the reserved
  /// ngrok domain is still the way:
  /// `--dart-define=MEDIHIVE_API=https://convincedly-photometric-ariella.ngrok-free.dev/`
  /// (start the tunnel with `ngrok start hms-api`). A `--dart-define` always
  /// wins over the default below.
  ///
  /// ```sh
  /// flutter run --dart-define=MEDIHIVE_API=http://10.0.2.2:3000/   # emulator, local API
  /// ```
  static const String baseUrl = String.fromEnvironment(
    'MEDIHIVE_API',
    defaultValue: 'http://192.168.163.97:3000/',
  );

  /// Where uploaded files live. The API returns storage-relative paths, which
  /// [fileUrl] joins onto this. When object storage is configured the API
  /// returns absolute URLs instead, and [fileUrl] passes those through
  /// untouched.
  /// The same origin as [baseUrl], and deliberately so.
  ///
  /// Patient documents are served by the API itself
  /// (`GET /api/patient-documents/:documentId/file`) rather than by a signed
  /// link into object storage, because a presigned URL names the bucket's own
  /// host and a phone has no route to it. One origin means one tunnel, which is
  /// all the free plan gives.
  static const String fileBaseUrl = String.fromEnvironment(
    'MEDIHIVE_FILES',
    defaultValue: 'http://192.168.163.97:3000/',
  );

  /// Whether this build is pointed somewhere only a developer can reach.
  ///
  /// The default above is the Android emulator's loopback to the host machine,
  /// which is right for `flutter run` and wrong for anything shipped: a
  /// release build with no `--dart-define` reaches a host that does not exist,
  /// over cleartext that both platforms refuse, and shows a network error on
  /// its first screen with nothing explaining why. `main()` checks this and
  /// says so out loud in debug.
  static bool get isLoopback =>
      baseUrl.contains('10.0.2.2') ||
      baseUrl.contains('localhost') ||
      baseUrl.contains('127.0.0.1');

  /// An absolute URL for a stored file — an avatar, a site logo, a scan.
  ///
  /// Absolute URLs pass through: once object storage is configured the API
  /// answers with the bucket's own URL, and joining that onto [fileBaseUrl]
  /// produces a path that resolves to nothing.
  static String fileUrl(String? path) {
    final value = (path ?? '').trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final base = fileBaseUrl.endsWith('/')
        ? fileBaseUrl.substring(0, fileBaseUrl.length - 1)
        : fileBaseUrl;
    return value.startsWith('/') ? '$base$value' : '$base/$value';
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '/api/auth/login';

  /// Requires `{refreshToken}` in the body and answers 204.
  static const String logout = '/api/auth/logout';
  static const String refreshToken = '/api/auth/refresh';

  /// The user, their access map and their organisation, in one round trip.
  static const String me = '/api/auth/me';

  /// The access map alone, for a refresh that does not need the rest.
  static const String meAccess = '/api/auth/me/access';
  static const String changePassword = '/api/auth/change-password';

  // ── The patient portal ────────────────────────────────────────────────────
  //
  // The first two are **public**, which no other write in this file is. They
  // are how somebody who has a hospital card but no login gets one, so they
  // are sent with `AuthInterceptor.unauthenticated`: a 401 from either reads
  // as "that did not work" rather than tearing down a session the caller does
  // not have yet.

  /// `{mrn, dateOfBirth}` → a short-lived, single-use claim token.
  ///
  /// Answers **identically whether or not the MRN exists**, so nothing the app
  /// reads back distinguishes the two. Copy written against this route has to
  /// be true in both cases.
  static const String patientClaim = '/api/patient-auth/claim';

  /// `{claimToken, password, email?}` → the ordinary token pair.
  ///
  /// Afterwards the patient signs in through [login] like every other account.
  static const String patientActivate = '/api/patient-auth/activate';

  /// The caller's own patient record and portal state.
  ///
  /// Reads the `patientId` on the bearer token and discards any id in the
  /// query, so there is no version of this request that asks about somebody
  /// else. It is the portal's only route to its own identity: a portal account
  /// holds no `patients` module, so `/api/patients/:id` is a 403.
  static const String patientPortalMe = '/api/patient-auth/me';

  // ── Case taking ───────────────────────────────────────────────────────────
  //
  // The interview. Not a [Crud]: there is no collection a patient can list —
  // every one of these routes reads the `patientId` off the bearer token and
  // refuses a caller who has none, so there is no shape of the request that
  // asks about somebody else's intake.
  //
  // The server names the parameter `:sessionId` rather than `:id`, because
  // `PatientSelfGuard` rewrites `params.id` to the caller's own patient id and
  // a session id arriving under that name would be overwritten before the
  // handler saw it. That is a server-side concern; the paths built here are
  // the same either way.

  /// POST: start an interview, or hand back the one already open.
  ///
  /// 200 for both, with `resumed` saying which happened — from the patient's
  /// side both are "carry on", so neither is an error.
  static const String caseSessions = '/api/case-taking/sessions';

  /// GET: the interview this patient has open, or **200 with a null payload**
  /// when there is none. Not a 404: "you have not started one" is an answer.
  static const String caseSessionCurrent = '/api/case-taking/sessions/current';

  static String caseSession(String sessionId) => '$caseSessions/$sessionId';

  /// POST: consent, or a refusal. The wording's version travels with it.
  static String caseSessionConsent(String sessionId) =>
      '$caseSessions/$sessionId/consent';

  /// POST: an answer in, the next question out.
  ///
  /// The hot path, and the one this whole module's design is arranged around:
  /// the next question comes from a deterministic selector and is in the
  /// response, while any model work the answer triggers runs behind it and
  /// lands as facts later. The patient never waits on the model.
  static String caseSessionTurns(String sessionId) =>
      '$caseSessions/$sessionId/turns';

  /// PATCH: correct an answer. Writes a new fact and retires the old one —
  /// never an update, because the disagreement is the part a clinician reads.
  static String caseSessionFact(String sessionId, String factId) =>
      '$caseSessions/$sessionId/facts/$factId';

  /// GET: "here is what we understood about you".
  static String caseSessionReview(String sessionId) =>
      '$caseSessions/$sessionId/review';

  /// POST: send the finished case to the hospital.
  static String caseSessionSubmit(String sessionId) =>
      '$caseSessions/$sessionId/submit';

  /// Multipart, field `file`: a recorded answer in, a transcript out.
  ///
  /// A refusal here is a 400 with a written sentence rather than a 500,
  /// because voice is never the only way to answer a question — the client is
  /// expected to read that as "carry on with the keyboard".
  static const String caseStt = '/api/case-taking/stt';

  /// A question read aloud. Answers `audio/wav`, outside the envelope.
  static const String caseTts = '/api/case-taking/tts';

  /// POST: a short-lived pass into a live voice room, and the URL to dial.
  ///
  /// Answers `{token, url, roomName, expiresAt}` and **never a key or a
  /// secret**: the room credential is minted server-side against the patient's
  /// bearer token, because a credential inside an APK belongs to everybody who
  /// has the APK and a hospital cannot rotate what is already on a thousand
  /// phones. `data/services/voice_session.dart` is the parser and says the
  /// same thing from the other end.
  ///
  /// **The second route here that is allowed to 404**, on the same terms as
  /// [caseLanguages] and for a stronger reason: a live conversation is an
  /// enhancement over an interview that already works by tap, by keyboard and
  /// by [caseStt], so a site with no media server configured answers this with
  /// nothing and the microphone goes on recording and uploading exactly as it
  /// did before. A 404, a 500, a timeout and a grant with no token in it are
  /// one behaviour in `CaseTakingController`.
  static const String caseVoiceToken = '/api/case-taking/voice/token';

  /// GET: which languages an interview can be taken in here, and which of them
  /// [caseStt] and [caseTts] can currently handle.
  ///
  /// `data` is the array itself — `[{code, canSpeak, canHear}, …]` — like every
  /// other collection in this file, and not an object wrapping one. It carries
  /// no names; `CaseLanguage` says why the app holds those.
  ///
  /// **The one route here that is allowed to 404.** The rule at the top of this
  /// file is that a constant for a route the server does not mount reads as
  /// verified and lands its 404 on a screen, and this one is landing ahead of
  /// its handler. What makes it safe is that nothing waits on it: the language
  /// screen renders its own catalogue first and this only refines the two
  /// capability flags, so a 404, a timeout and a waiting-room tablet with no
  /// signal are one behaviour — the picker the app shipped with. Which models
  /// the sidecar has loaded is genuinely server state and changes without a
  /// release, which is why the call exists at all.
  static const String caseLanguages = '/api/case-taking/languages';

  // ── The patient's own documents ───────────────────────────────────────────
  //
  // A [Crud] this time, because there genuinely is a collection: a patient can
  // list the prescriptions and reports they have handed over, and a staff
  // caller can list one patient's by naming them. What it does **not** have is
  // an update or a delete — a document is evidence (§22), and the only write
  // past the upload is the patient confirming what was read out of it.
  //
  // The server names the parameter `:documentId` rather than `:id`, and that is
  // not tidiness to be undone. `PatientSelfGuard` overwrites a param called
  // `id` with the caller's own patient id, so every one of these routes
  // answered its own owner with "That document could not be found." The URL
  // shape is identical either way, so nothing here has to know — but anyone
  // adding a route below does.
  static const patientDocuments = Crud('/api/patient-documents');

  /// GET: a **short-lived signed URL** to the file the extraction came from.
  ///
  /// The bucket is private, so this is the only way a patient can look at their
  /// own evidence. It expires in minutes: fetch it when the patient asks to
  /// see the original, never at list time.
  ///
  /// **Not what the app uses to show a document** — see
  /// [patientDocumentFile]. The signed URL names the bucket's own host, which
  /// a phone cannot resolve.
  static String patientDocumentOriginal(String documentId) =>
      '${patientDocuments.base}/$documentId/original';

  /// GET: the original file itself, streamed through the API.
  ///
  /// This is the one the app fetches, and the reason is the whole point of
  /// [fileBaseUrl] above: [patientDocumentOriginal] answers with a URL signed
  /// against the bucket — `localhost:9010` on a developer machine,
  /// `minio:9000` in compose — and a handset can resolve neither. The app used
  /// to hand that URL to `Image.network`, which also sends no bearer token, so
  /// "See the original" failed with "We couldn't open the original just now"
  /// no matter what was wrong.
  ///
  /// Through here the bytes come back over the same authenticated origin as
  /// every other call, so one reachable host serves the whole app.
  static String patientDocumentFile(String documentId) =>
      '${patientDocuments.base}/$documentId/file';

  /// POST: the patient confirming that what was read out of this document is
  /// correct.
  ///
  /// The **only** transition out of `needs_review`. Nothing else verifies a
  /// document — not a high confidence, not a successful extraction — because
  /// the server refuses to treat anything it read as clinical truth until the
  /// person it is about says so.
  static String patientDocumentVerify(String documentId) =>
      '${patientDocuments.base}/$documentId/verify';

  // ── Collections ───────────────────────────────────────────────────────────
  //
  // One [Crud] per resource. Anything that is not list/read/create/update/
  // delete gets a named constant below its group.
  //
  // `updateVerb` is not decoration: this API is PATCH for most resources and
  // PUT for patients, users and the three settings collections. Sending the
  // wrong one is a 404 on a route that exists.

  static const users = Crud('/api/users', updateVerb: HttpVerb.put);
  static const roles = Crud('/api/roles');
  static const patients = Crud('/api/patients', updateVerb: HttpVerb.put);
  static const appointments = Crud('/api/appointments');
  static const consultations = Crud('/api/consultations');
  static const preTriage = Crud('/api/pre-triage');
  static const queue = Crud('/api/queue');

  // ── Inpatient ─────────────────────────────────────────────────────────────
  //
  // No `Crud('/api/inpatient')`, and none for the other four module roots
  // below. Those roots exist, but as multiplexed GET/POST/PATCH handlers kept
  // for a Next.js console — there is no `/:id` under any of them, so a `Crud`
  // there would offer a `byId` and a `delete` that 404 on a path that looks
  // right. The sub-collections are the real routes.
  static const wards = Crud('/api/inpatient/wards');
  static const beds = Crud('/api/inpatient/beds');
  static const admissions = Crud('/api/inpatient/admissions');
  static const String inpatientStats = '/api/inpatient/stats';

  // ── Laboratory ────────────────────────────────────────────────────────────
  static const labTests = Crud('/api/laboratory/tests');
  static const labOrders = Crud('/api/laboratory/orders');
  static const labResults = Crud('/api/laboratory/results');
  static const String labStats = '/api/laboratory/stats';

  // ── Radiology ─────────────────────────────────────────────────────────────
  static const radiologyExams = Crud('/api/radiology/exams');
  static const radiologyOrders = Crud('/api/radiology/orders');
  static const radiologyReports = Crud('/api/radiology/reports');

  /// Multipart. A study's images, attached to an order.
  static const String radiologyUpload = '/api/radiology/upload';

  /// The one stats route that is not `/stats` — it is `/stats/summary`, and
  /// the other spelling 404s.
  static const String radiologyStats = '/api/radiology/stats/summary';

  // ── Pharmacy ──────────────────────────────────────────────────────────────
  static const drugs = Crud('/api/pharmacy/drugs');
  static const prescriptions = Crud('/api/pharmacy/prescriptions');
  static const pharmacySales = Crud('/api/pharmacy/sales');
  static const String pharmacyStats = '/api/pharmacy/stats';

  // ── Billing ───────────────────────────────────────────────────────────────
  static const billingServices = Crud('/api/billing/services');
  static const invoices = Crud('/api/billing/invoices');
  static const payments = Crud('/api/billing/payments');
  static const String billingStats = '/api/billing/stats';

  // ── Integrations ──────────────────────────────────────────────────────────
  //
  // `/api/integrations` itself is not a collection — the module mounts only the
  // three routes below. The integrations a site *configures* are a settings
  // collection, [settingsIntegrations].

  /// Analysers and imaging devices that post results back.
  static const machines = Crud('/api/integrations/machines');

  /// Results a machine sent that nobody has verified yet.
  static const String resultsQueue = '/api/integrations/results-queue';

  /// Multipart. A result file from a device with no live link.
  static const String resultsUpload = '/api/integrations/results/upload';

  // ── Settings ──────────────────────────────────────────────────────────────
  //
  // These three are PUT, unlike every other collection in this file.
  static const departments = Crud(
    '/api/settings/departments',
    updateVerb: HttpVerb.put,
  );
  static const settingsUsers = Crud(
    '/api/settings/users',
    updateVerb: HttpVerb.put,
  );
  static const settingsIntegrations = Crud(
    '/api/settings/integrations',
    updateVerb: HttpVerb.put,
  );

  // ── Named actions ─────────────────────────────────────────────────────────

  /// Turns a screening into a live queue entry or appointment.
  static String convertPreTriage(String id) => '/api/pre-triage/$id/convert';

  /// The permissions granted to one role. PUT replaces the whole set.
  static String assignPermission(String roleId) =>
      '/api/roles/$roleId/permissions';

  /// The users holding one role. POST adds one.
  static String roleUsers(String roleId) => '/api/roles/$roleId/users';

  /// One user's hold on one role. DELETE removes it.
  static String roleUser(String roleId, String userId) =>
      '/api/roles/$roleId/users/$userId';

  // ── Singletons ────────────────────────────────────────────────────────────
  static const String dashboard = '/api/dashboard';

  /// The permission catalogue. Read-only: the rows an administrator grants a
  /// role through [assignPermission]. There is no create, update or delete —
  /// the set ships with the server.
  static const String permissions = '/api/permissions';

  /// The site's settings as a flat `{key: value}` map of strings.
  static const String settings = '/api/settings';

  /// The organisation as a shape — branding plus grouped settings. GET reads,
  /// PUT replaces.
  static const String organization = '/api/settings/organization';

  /// Which modules this site has switched on. PUT only.
  static const String settingsModules = '/api/settings/modules';

  /// Multipart logo upload.
  ///
  /// **Not mounted yet** — the server currently takes `logoUrl` through
  /// [organization]. Named here because the upload screen is the one caller and
  /// this is where it will look.
  static const String settingsLogo = '/api/settings/organization/logo';

  /// Clinicians and other staff, for the pickers that assign work.
  static const String staff = '/api/users/staff';
}

/// The verbs this app sends.
///
/// Named rather than stringly-typed because the two that matter — PATCH and
/// PUT — are interchangeable to read and are not interchangeable to this API.
enum HttpVerb { get, post, put, patch, delete }

/// The five routes a collection can have, built from one base path.
///
/// Exists so that adding a resource is one line rather than five near-identical
/// constants, and so that a rename is one edit rather than five.
///
/// It builds paths; it does not promise routes. Several collections here are
/// list/create/update only — a ward has no delete, a lab order has no `GET
/// /:id` — so a module reaching past [list], [create] and [update] should check
/// the route exists before assuming a 404 is a bug in the app.
class Crud {
  const Crud(this.base, {this.updateVerb = HttpVerb.patch})
    : assert(
        updateVerb == HttpVerb.patch || updateVerb == HttpVerb.put,
        'an update is PATCH or PUT; nothing else reaches this route',
      );

  /// The collection path, with no trailing slash.
  final String base;

  /// Which verb this resource's update route answers to.
  ///
  /// PATCH almost everywhere; PUT on patients, users and the settings
  /// collections. `CrudRepository.update` reads this rather than assuming, so
  /// an edit screen written against the wrong one fails in review rather than
  /// on a ward.
  final HttpVerb updateVerb;

  String get list => base;
  String get create => base;
  String byId(String id) => '$base/$id';
  String update(String id) => '$base/$id';
  String delete(String id) => '$base/$id';

  /// A sub-collection under one record — `/api/patients/<id>/visits`.
  String sub(String id, String name) => '$base/$id/$name';
}
