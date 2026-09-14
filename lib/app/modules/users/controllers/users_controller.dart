import 'dart:async';

import 'package:get/get.dart';

import '../../../core/app_log.dart';
import '../../../core/paged_list_controller.dart';
import '../../../data/models/access_map.dart';
import '../../../data/models/role.dart';
import '../../../data/models/staff_user.dart';
import '../../../data/network/dio_client.dart';
import '../../../data/network/endpoints.dart';
import '../../../data/services/access_service.dart';
import '../../../data/services/data_bus.dart';
import '../../../data/utils/api_envelope.dart';
import '../../../theme/theme.dart';
import '../staff_directory.dart';

/// The staff directory: who works here, what they do, and who is still live.
///
/// Paging, the five list states and the refresh come from
/// [PagedListController]. What is left is this resource's own, and most of it
/// is about one fact: **neither staff route can be searched or filtered on the
/// server.** `GET /api/users` binds its query to `PaginationDto`, which
/// declares `page`, `limit`, `orderBy` and `orderDir` and nothing else, and the
/// global `ValidationPipe` runs `forbidNonWhitelisted` — so `?search=` is a
/// 400 for the whole request. `GET /api/settings/users` takes a `role` and no
/// search at all, and answers the whole organisation in one bare array.
///
/// So the narrowing happens here, over rows in hand, and a search first pulls
/// the pages behind it: a match on page three reported as "nobody matches
/// that" is worse than a slow search.
class UsersController extends PagedListController<StaffUser> {
  UsersController()
      : super(
          repository: const StaffDirectory(),
          // 50 rather than 20: the narrowing below is in memory, so a page
          // that costs one round trip is worth more here than on a list the
          // server filters.
          pageSize: 50,
          sortOptions: const [
            // Newest first, because the commonest reason to open the directory
            // is an account somebody created this morning.
            SortOption(field: 'createdAt', label: 'Newest first'),
            SortOption(
              field: 'fullName',
              label: 'Name A–Z',
              descending: false,
            ),
            SortOption(
              field: 'createdAt',
              label: 'Oldest first',
              descending: false,
            ),
          ],
        );

  static UsersController get to => Get.find<UsersController>();

  /// How many extra pages a search will pull before it gives up.
  ///
  /// A directory with more than this many people is one that needs a server
  /// that can search, not a phone that pages harder.
  static const int _searchPageBudget = 5;

  /// The role catalogue, for the filter's option list.
  ///
  /// Empty when this account may not read roles — `GET /api/roles` is gated on
  /// `ROLE_READ`, which a user administrator can be without. The filter is
  /// then absent rather than empty.
  final roles = <Role>[].obs;

  /// The row the tablet's second pane is showing. Null on a phone, where the
  /// record is a pushed screen.
  final selectedId = RxnString();

  DioClient get _client => Get.find<DioClient>();

  bool get canCreate => AccessService.to.can(Modules.users, AccessVerb.create);
  bool get canUpdate => AccessService.to.can(Modules.users, AccessVerb.update);

  /// The settings route filters by role itself. Fed through `filters`, which
  /// `StaffDirectory` reads and the paged route discards.
  @override
  Map<String, dynamic> get baseParams => const {};

  @override
  void onInit() {
    // Before `super.onInit()`, which fires the first load. Two clinicians hand
    // a ward tablet over between shifts and the second one's grants are not
    // the first one's, so the route probe starts again from the preferred
    // route rather than inheriting a fallback somebody else needed.
    StaffDirectory.forget();
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    _loadRoles();

    if (Get.isRegistered<DataBus>()) {
      // The form is a pushed route, so this list is still alive underneath it
      // and nothing else will tell it that an account was created. The base
      // class only marks the list stale — that is right for a shell tab the
      // user has navigated away from, and wrong for the screen the form pops
      // straight back onto.
      ever<int>(DataBus.to.tick(StaffDirectory.entityName), (_) {
        if (isForbidden) return;
        unawaited(reload(silent: true));
      });
    }
  }

  @override
  String idOf(StaffUser item) => item.id;

  @override
  String get couldNotLoadMessage => "Couldn't load the staff directory.";

  /// Only what this route's DTO declares.
  ///
  /// `search` and the filters are deliberately dropped: see the class comment.
  /// `role` still travels, in [PagedQuery.params], because the settings route
  /// reads it — `StaffDirectory` is the one thing that knows which route is
  /// answering, so it decides whether to send it.
  @override
  PagedQuery queryFor(int page) => PagedQuery(
        page: page,
        limit: pageSize,
        orderBy: sort.field,
        orderDir: sort.orderDir,
        params: {
          for (final entry in filters.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value.join(','),
        },
      );

  /// The rows on screen: the term and the role applied over what is loaded.
  List<StaffUser> get rows {
    final needle = query.value.trim().toLowerCase();
    final wanted = filters['role'] ?? const <String>[];

    return items.where((user) {
      if (wanted.isNotEmpty && !wanted.contains(user.role ?? '')) return false;
      if (needle.isEmpty) return true;
      return [
        user.displayName,
        user.email,
        user.employeeId ?? '',
        user.specialization ?? '',
        user.departmentName,
        // The stored token, so typing "lab" finds LAB_TECHNICIAN as well as
        // the person whose department is Laboratory.
        user.role ?? '',
      ].any((field) => field.toLowerCase().contains(needle));
    }).toList();
  }

  bool get isNarrowed =>
      query.value.trim().isNotEmpty || (filters['role'] ?? const []).isNotEmpty;

  /// The role names in the directory, for the filter sheet.
  ///
  /// From the catalogue where there is one, and from the rows otherwise: a
  /// filter that offers a role nobody holds is a filter that produces an empty
  /// list, and a filter that omits one somebody does hold is worse.
  List<String> get roleOptions {
    final names = <String>{
      for (final role in roles) role.name,
      for (final user in items)
        if ((user.role ?? '').isNotEmpty) user.role!,
    }..removeWhere((name) => name.isEmpty);
    return names.toList()..sort();
  }

  @override
  Future<void> search(String value) async {
    if (value.trim() == query.value.trim()) return;
    query.value = value;
    await _gatherRows();
  }

  @override
  Future<void> applyFilters(Map<String, List<String>> next) async {
    filters
      ..clear()
      ..addAll(next);
    await _gatherRows();
  }

  /// Makes sure there are rows to narrow.
  ///
  /// The settings route refetches, because it is the one that can filter by
  /// role server-side and it answers the whole organisation anyway. The paged
  /// route cannot narrow at all, so the only useful thing to do is finish
  /// paging — bounded, because a directory that needs more than
  /// [_searchPageBudget] pages needs a server that can search.
  Future<void> _gatherRows() async {
    if (StaffDirectory.usesSettingsRoute) {
      await reload(silent: true);
      return;
    }
    for (var round = 0; round < _searchPageBudget && hasMore; round++) {
      await loadMore();
    }
  }

  Future<void> _loadRoles() async {
    try {
      final response = await _client.get(Endpoints.roles.list);
      roles.assignAll(
        ApiEnvelope.of(response).orThrow().listOf(Role.fromJson),
      );
    } on ApiForbiddenException catch (e) {
      // Not a failure worth a banner: the directory is readable and the filter
      // simply is not offered. A user administrator without `ROLE_READ` is a
      // shape the server actually ships.
      AppLog.info('UsersController', 'roles refused: ${e.message}');
    } catch (e, stack) {
      AppLog.error('UsersController', 'role catalogue failed', e, stack);
    }
  }

  /// Opens somebody in the tablet's second pane.
  void select(String id) => selectedId.value = id;

  /// Where a row goes on a phone. Arguments rather than a path parameter — see
  /// `StaffRoutes` for why the record is not `/staff/:id`.
  Object recordArgumentsFor(StaffUser user) => {
        'id': user.id,
        // The row the list already holds, so the header paints on the first
        // frame instead of after a round trip. The record refetches anyway: a
        // row is a summary and the record is the whole account.
        'user': user,
      };
}
