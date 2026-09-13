import 'package:flutter/material.dart';

/// Translates the icon names the backend stores into Material icons.
///
/// `PlatformPage.pageIcon` holds an Ant Design name — the web portal's icon
/// set — because that is what the seed was written against and what an
/// administrator picks from when adding a page. The mobile app draws Material
/// icons, so the mapping lives here rather than in a widget: an unknown name
/// must resolve to *something* recognisable, never to a crash or a blank space
/// in the navigation.
///
/// `libraries.json` uses a **second, unrelated vocabulary** for the same field
/// — bare `Circle`, `CreditCard`, `Globe` rather than `…Outlined`. Both are
/// mapped here, because the alternative is a hub of six identical fallback
/// circles, which is worse than no icons at all.
///
/// Each destination gets an outlined icon for its resting state and a filled
/// one for its active state, which is how the shell shows selection without
/// relying on colour alone.
abstract final class NavIcons {
  /// The icon pair for a page, by its stored icon name.
  static NavIconPair of(String? antName, {String? pageKey}) {
    final byName = _byAntName[_normalise(antName)];
    if (byName != null) return byName;

    // A page whose icon was never set, or set to something nobody mapped: fall
    // back on what the page *is*, which is stable, before falling back on a
    // generic glyph.
    final byKey = _byPageKey[pageKey?.toUpperCase()];
    if (byKey != null) return byKey;

    return _fallback;
  }

  static String _normalise(String? name) =>
      (name ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  static const _fallback = NavIconPair(
    Icons.circle_outlined,
    Icons.circle_rounded,
  );

  /// Mirrors the web portal's `ICON_MAP`.
  static const Map<String, NavIconPair> _byAntName = {
    'dashboardoutlined': NavIconPair(Icons.dashboard_outlined, Icons.dashboard_rounded),
    'customerserviceoutlined':
        NavIconPair(Icons.people_alt_outlined, Icons.people_alt_rounded),
    'containeroutlined': NavIconPair(Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    'filesyncoutlined': NavIconPair(Icons.request_quote_outlined, Icons.request_quote_rounded),
    'creditcardoutlined': NavIconPair(Icons.payments_outlined, Icons.payments_rounded),
    'walletoutlined': NavIconPair(
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
    ),
    'shopoutlined': NavIconPair(Icons.percent_outlined, Icons.percent_rounded),
    'settingoutlined': NavIconPair(Icons.tune_outlined, Icons.tune_rounded),
    'useroutlined': NavIconPair(Icons.person_outline_rounded, Icons.person_rounded),
    'safetyoutlined': NavIconPair(Icons.verified_user_outlined, Icons.verified_user_rounded),
    'appstoreoutlined': NavIconPair(Icons.apps_outlined, Icons.apps_rounded),
    'databaseoutlined': NavIconPair(Icons.dataset_outlined, Icons.dataset_rounded),
    'reconciliationoutlined': NavIconPair(Icons.info_outline_rounded, Icons.info_rounded),
    'filetextoutlined': NavIconPair(Icons.description_outlined, Icons.description),
    'teamoutlined': NavIconPair(Icons.groups_outlined, Icons.groups_rounded),
    'barchartoutlined': NavIconPair(Icons.bar_chart_outlined, Icons.bar_chart_rounded),

    // The library schema vocabulary, from `backend/src/config/libraries.json`.
    'circle': NavIconPair(Icons.label_outline_rounded, Icons.label_rounded),
    'creditcard': NavIconPair(Icons.schedule_outlined, Icons.schedule_rounded),
    'truck': NavIconPair(
      Icons.local_shipping_outlined,
      Icons.local_shipping_rounded,
    ),
    'building': NavIconPair(Icons.inventory_2_outlined, Icons.inventory_2),
    'dashboard': NavIconPair(Icons.straighten_outlined, Icons.straighten_rounded),
    'globe': NavIconPair(Icons.public_outlined, Icons.public_rounded),
  };

  /// By what the page is, for a page whose icon name is missing or unmapped.
  static const Map<String, NavIconPair> _byPageKey = {
    'DASHBOARD': NavIconPair(Icons.dashboard_outlined, Icons.dashboard_rounded),
    'CUSTOMER': NavIconPair(Icons.people_alt_outlined, Icons.people_alt_rounded),
    'INVOICE': NavIconPair(Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    'QUOTE': NavIconPair(Icons.request_quote_outlined, Icons.request_quote_rounded),
    'PAYMENT': NavIconPair(Icons.payments_outlined, Icons.payments_rounded),
    'PAYMENT_MODE': NavIconPair(
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
    ),
    'TAXES': NavIconPair(Icons.percent_outlined, Icons.percent_rounded),
    'SETTINGS': NavIconPair(Icons.tune_outlined, Icons.tune_rounded),
    'ADMIN_MANAGEMENT': NavIconPair(Icons.manage_accounts_outlined, Icons.manage_accounts_rounded),
    'ROLE_MANAGEMENT': NavIconPair(Icons.verified_user_outlined, Icons.verified_user_rounded),
    'PLATFORM_PAGES': NavIconPair(Icons.apps_outlined, Icons.apps_rounded),
    'LIBRARY': NavIconPair(Icons.dataset_outlined, Icons.dataset_rounded),
    'PROFILE': NavIconPair(Icons.person_outline_rounded, Icons.person_rounded),
    'ABOUT': NavIconPair(Icons.info_outline_rounded, Icons.info_rounded),
  };
}

/// A destination's resting and active glyphs.
class NavIconPair {
  const NavIconPair(this.idle, this.active);

  final IconData idle;
  final IconData active;

  IconData resolve({required bool selected}) => selected ? active : idle;
}
