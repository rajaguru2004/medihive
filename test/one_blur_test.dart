/// The blur ratchet.
///
/// `DESIGN.md` §4.1 and `.agents/RULES.md` §2.5 both state the same absolute:
/// there is not one `BackdropFilter` in this app. A card is glass here through
/// a translucent top-lit fill, a luminous hairline and one soft shadow —
/// because a blur reads back and re-blurs everything beneath it on every frame
/// the content moves, and forty of them in a list is the most expensive thing a
/// Flutter screen can do. On a ward tablet running a board that refreshes every
/// thirty seconds, that is a cost paid continuously for decoration.
///
/// `app_bento.dart` has claimed for some time that this file holds the count.
/// It did not exist, so the ban was documented in three places and enforced in
/// none — which is the state a rule is in just before somebody breaks it.
///
/// The count is **zero**, not one. The comment that referenced this file said
/// one; the tree has never had any.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dart comments, so a sentence explaining why the ban exists does not read as
/// a violation of it. Block comments first: a `//` inside a `/* … */` would
/// otherwise survive.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((line) {
      final marker = line.indexOf('//');
      return marker == -1 ? line : line.substring(0, marker);
    })
    .join('\n');

void main() {
  test('no BackdropFilter reaches a screen in this app', () {
    final offenders = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final code = _withoutComments(file.readAsStringSync());
      if (!code.contains('BackdropFilter')) continue;

      // Report the line as written, not the stripped one — a line number
      // into a comment-free copy of the file helps nobody find it.
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_withoutComments(lines[i]).contains('BackdropFilter')) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A BackdropFilter was added. The kit already answers this: use '
          'BentoCard, or BentoGlass for a translucent surface. See DESIGN.md '
          '§4.1 for why a blur is not available here.\n'
          'Found at:\n  ${offenders.join('\n  ')}',
    );
  });
}
