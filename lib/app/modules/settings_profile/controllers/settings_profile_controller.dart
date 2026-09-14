import 'dart:async';

import 'package:dio/dio.dart'
    show DioMediaType, FormData, MultipartFile, Options;
import 'package:flutter/material.dart';
// `FormData` and `MultipartFile` are declared by both packages; GetX's belong
// to its own HTTP client, which this app does not use.
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../../../core/app_log.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/drafts/drafts.dart';
import '../../../data/models/organization.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/image_source.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../data/utils/error_handler.dart';
import '../../settings/controllers/settings_form_controller.dart';

/// Who this hospital says it is: its name, how to reach it, its marks and its
/// brand colours.
///
/// Everything here is read from `GET /settings/organization` rather than from
/// `SettingsService`. The flat settings map the rest of the app runs on carries
/// the name and the two colours and **none of the contact block** — no slug, no
/// address, no city — so a form built from it would show six empty fields over
/// a record that is not empty and then save the blanks.
class SettingsProfileController extends SettingsFormController {
  static SettingsProfileController get to =>
      Get.find<SettingsProfileController>();

  /// The brand colours this screen offers, as the hex the record stores.
  ///
  /// Taken from `BrandPalette`'s own presets so the app and the console offer
  /// one vocabulary. No red and no amber in the list on purpose: `error` and
  /// `warning` mean something on every other screen in this app, and a site
  /// whose primary is one of them turns every button into an alarm. A site
  /// that already stores such a colour still sees it — [primarySwatches] adds
  /// whatever is on the record, so nothing a hospital chose is hidden from it.
  static const List<String> presetSwatches = [
    '#0E7C7B', // Clinical Teal — the product default
    '#0A5F5E', // its pressed shade, for a site that wants a deeper brand
    '#0059A8', // Clinical Blue
    '#15603C', // Forest
    '#7A2F62', // Plum
    '#0070C0', // Ledger blue, the accent most secondaries use
  ];

  final formKey = GlobalKey<FormState>();

  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final region = TextEditingController();
  final country = TextEditingController();

  /// Set once from the record and never edited. `slug` is create-time identity
  /// — it is in URLs and in other systems' references — so the screen shows it
  /// and refuses to pretend it is a field.
  final rxSlug = ''.obs;

  final rxPrimary = ''.obs;
  final rxSecondary = ''.obs;
  final rxLogoUrl = ''.obs;
  final rxLogoTextUrl = ''.obs;

  /// True while a mark is being posted. Its own flag rather than [rxLoading]:
  /// the save bar must stay live, and the upload has its own place to fail.
  final rxUploading = false.obs;
  final rxUploadError = RxnString();

  /// Set by a failed submit, so the summary appears when somebody presses Save
  /// rather than while they are still typing their way down the form.
  final rxSubmitted = false.obs;

  String _initialName = '';
  String _initialEmail = '';
  String _initialPhone = '';
  String _initialAddress = '';
  String _initialCity = '';
  String _initialRegion = '';
  String _initialCountry = '';
  String _initialPrimary = '';
  String _initialSecondary = '';
  String _initialLogoUrl = '';
  String _initialLogoTextUrl = '';

  bool get canWrite => AccessService.to.can(Modules.settings, AccessVerb.update);

  /// The colours on offer for the mark, with the site's own at the front when
  /// it is not one of the presets.
  List<String> get primarySwatches => _swatches(rxPrimary.value);
  List<String> get secondarySwatches => _swatches(rxSecondary.value);

  static List<String> _swatches(String current) {
    final value = current.trim().toLowerCase();
    if (value.isEmpty ||
        presetSwatches.any((hex) => hex.toLowerCase() == value)) {
      return presetSwatches;
    }
    return [current.trim(), ...presetSwatches];
  }

  @override
  void onInit() {
    super.onInit();
    for (final field in [
      name,
      email,
      phone,
      address,
      city,
      region,
      country,
    ]) {
      // The save bar is driven by `isDirty`, which reads the text controllers.
      // Without this it only re-evaluates when some other observable moves, so
      // the button stays dead through a form somebody has entirely retyped.
      field.addListener(_touch);
    }
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(load());
  }

  @override
  void onClose() {
    for (final field in [
      name,
      email,
      phone,
      address,
      city,
      region,
      country,
    ]) {
      field
        ..removeListener(_touch)
        ..dispose();
    }
    super.onClose();
  }

  /// Bumped on every keystroke.
  ///
  /// A `TextEditingController` is not an `Rx`, so an `Obx` around the save bar
  /// never hears one. One counter is enough — [isDirty] reads the text itself;
  /// this only tells the `Obx` to look again.
  final _typed = 0.obs;
  void _touch() => _typed.value++;

  /// Always true. Reading it is what subscribes the caller to [_typed].
  bool get _keystrokes => _typed.value >= 0;

  Future<void> load({bool silent = false}) async {
    await runGuarded(
      () async {
        final response = await client.get(Endpoints.organization);
        _adoptRecord(
          Organization.fromJson(ApiEnvelope.of(response).orThrow().object),
        );
      },
      fallback: "Couldn't load this hospital's profile.",
      silent: silent,
    );
  }

  Future<void> reload() => load(silent: true);

  void _adoptRecord(Organization organization) {
    name.text = organization.name;
    email.text = organization.email ?? '';
    phone.text = organization.phone ?? '';
    address.text = organization.address ?? '';
    city.text = organization.city ?? '';
    region.text = organization.region ?? '';
    country.text = organization.country ?? '';

    rxSlug.value = organization.slug;
    rxPrimary.value = organization.primaryColor;
    rxSecondary.value = organization.secondaryColor;
    rxLogoUrl.value = organization.logoUrl ?? '';
    rxLogoTextUrl.value = organization.logoTextUrl ?? '';

    _rememberInitials();
  }

  void _rememberInitials() {
    _initialName = name.text.trim();
    _initialEmail = email.text.trim();
    _initialPhone = phone.text.trim();
    _initialAddress = address.text.trim();
    _initialCity = city.text.trim();
    _initialRegion = region.text.trim();
    _initialCountry = country.text.trim();
    _initialPrimary = rxPrimary.value;
    _initialSecondary = rxSecondary.value;
    _initialLogoUrl = rxLogoUrl.value;
    _initialLogoTextUrl = rxLogoTextUrl.value;
  }

  // ── Brand ─────────────────────────────────────────────────────────────────

  void selectPrimary(String hex) => rxPrimary.value = hex;
  void selectSecondary(String hex) => rxSecondary.value = hex;

  // ── Marks ─────────────────────────────────────────────────────────────────

  /// Picks a mark, posts it, and holds the URL the server filed it under until
  /// the form is saved.
  ///
  /// Two steps, like every other upload in this app: the multipart route files
  /// the object and answers with an address, and the address only becomes this
  /// hospital's logo when the organisation write lands. Recording it here
  /// rather than saving immediately is what lets somebody change their mind —
  /// and what keeps one Save for the whole screen.
  Future<bool> pickLogo({required bool wordmark}) async {
    if (rxUploading.value || !canWrite) return false;

    rxUploadError.value = null;
    rxUploading.value = true;
    try {
      final picked = await Get.find<ImageSource>().pick(ImageOrigin.gallery);
      if (picked == null) return false;

      final form = FormData.fromMap({
        // The field name this backend's upload routes read. A part sent as
        // `image` or `logo` arrives as no file at all and the handler answers
        // "No file uploaded" over a request that otherwise looks fine.
        'file': MultipartFile.fromBytes(
          picked.bytes,
          filename: picked.filename,
          // Stated, never inferred: Dio types a byte part it was given no type
          // for as `application/octet-stream`, which every `fileFilter` on this
          // server refuses.
          contentType: DioMediaType.parse(picked.mimeType),
        ),
        // Which of the two marks this is. A site draws its wordmark separately
        // from its symbol and both live on the same record.
        'type': wordmark ? 'logoText' : 'logo',
      });

      final response = await client.post(
        Endpoints.settingsLogo,
        data: form,
        // Dio sets the multipart boundary itself. Leaving the client's default
        // `application/json` on the request sends a body no parser can read.
        options: Options(contentType: 'multipart/form-data'),
      );
      final object = ApiEnvelope.of(response).orThrow().object;
      final url = _uploadedUrl(object, wordmark: wordmark);
      if (url.isEmpty) {
        rxUploadError.value = 'The server took the image but sent no address '
            'for it. Try again.';
        return false;
      }

      if (wordmark) {
        rxLogoTextUrl.value = url;
      } else {
        rxLogoUrl.value = url;
      }
      return true;
    } on ApiForbiddenException catch (e) {
      rxUploadError.value = "You don't have permission to change this "
          "hospital's marks.";
      AppLog.info('$runtimeType', 'logo upload refused: ${e.message}');
      return false;
    } catch (e, stack) {
      AppLog.error('$runtimeType', 'logo upload failed', e, stack);
      rxUploadError.value = parseErrorMessage(e, "Couldn't upload that image.");
      return false;
    } finally {
      rxUploading.value = false;
    }
  }

  /// Reads the address out of whichever key the route answered with.
  ///
  /// `url` is what the other upload route on this server sends. The two named
  /// keys are what a handler that knows it is storing a logo would send, and
  /// accepting both costs one line rather than a release.
  static String _uploadedUrl(
    Map<String, dynamic> object, {
    required bool wordmark,
  }) {
    final named = wordmark ? object['logoTextUrl'] : object['logoUrl'];
    final value = object['url'] ?? named;
    return value == null ? '' : value.toString().trim();
  }

  /// True when a mark has been uploaded and not yet saved — the state the
  /// screen has to admit to, because the image on screen is not on the record.
  bool get hasUnsavedMark =>
      rxLogoUrl.value != _initialLogoUrl ||
      rxLogoTextUrl.value != _initialLogoTextUrl;

  // ── Validation ────────────────────────────────────────────────────────────

  String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'What is this hospital called?' : null;

  /// Optional, and checked only when something was typed.
  ///
  /// Deliberately a shape check rather than a pattern that claims to know what
  /// an address is: this field is on letterheads and invoices, and a form that
  /// rejects a valid address is worse than one that accepts an odd one.
  String? validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final looksRight =
        text.contains('@') && text.indexOf('@') < text.lastIndexOf('.');
    return looksRight ? null : 'That does not look like an email address';
  }

  int get invalidFieldCount => [
        validateName(name.text),
        validateEmail(email.text),
      ].where((message) => message != null).length;

  // ── The save ──────────────────────────────────────────────────────────────

  @override
  bool get isDirty =>
      _keystrokes &&
      (name.text.trim() != _initialName ||
          email.text.trim() != _initialEmail ||
          phone.text.trim() != _initialPhone ||
          address.text.trim() != _initialAddress ||
          city.text.trim() != _initialCity ||
          region.text.trim() != _initialRegion ||
          country.text.trim() != _initialCountry ||
          rxPrimary.value != _initialPrimary ||
          rxSecondary.value != _initialSecondary ||
          rxLogoUrl.value != _initialLogoUrl ||
          rxLogoTextUrl.value != _initialLogoTextUrl);

  /// Only what this screen owns.
  ///
  /// The two colours go out **twice**, and that is the point rather than an
  /// oversight. `primaryColor` and `secondaryColor` are the record's branding —
  /// what the console, the letterhead and the printed chart header read.
  /// `settings.appearance.customColors` is the copy `SiteSettings` folds into
  /// `theme_custom_colors`, which is one of the three keys `ThemeService`
  /// watches; without it the site's own colour would never reach the running
  /// app at all.
  ///
  /// `themePreset` is **not** here. That belongs to the Appearance screen, and
  /// a partial save that carried it would stamp this screen's idea of the theme
  /// over whatever somebody chose there an hour ago.
  @override
  OrganizationSettingsDraft buildDraft() => OrganizationSettingsDraft(
        name: name.text,
        email: email.text,
        phone: phone.text,
        address: address.text,
        city: city.text,
        region: region.text,
        country: country.text,
        logoUrl: rxLogoUrl.value,
        logoTextUrl: rxLogoTextUrl.value,
        primaryColor: rxPrimary.value,
        secondaryColor: rxSecondary.value,
        customPrimary: rxPrimary.value,
        customSecondary: rxSecondary.value,
      );

  @override
  Future<void> save() async {
    rxSubmitted.value = true;
    if (!(formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await super.save();
  }

  @override
  void onSaved() {
    // The adopt in `SettingsFormController.save` has already re-themed the app
    // and refreshed `SettingsService`; this only stops the save bar offering to
    // send the same thing again.
    rxSubmitted.value = false;
    _rememberInitials();
  }
}
