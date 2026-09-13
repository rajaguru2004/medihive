import 'package:flutter/widgets.dart';

/// Widget keys for the queue board.
abstract final class QueueKeys {
  static const screen = Key('queue_screen');
  static const list = Key('queue_list');
  static const search = Key('queue_search');
  static const filters = Key('queue_filters');
  static const addButton = Key('queue_add_button');
  static const empty = Key('queue_empty');
  static const error = Key('queue_error');
  static const legend = Key('queue_legend');

  static Key row(String id) => Key('queue_row_$id');
  static Key advance(String id) => Key('queue_advance_$id');
  static Key filter(String id) => Key('queue_filter_$id');
}
