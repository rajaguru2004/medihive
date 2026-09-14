// Widget-key hygiene, as a ratchet.
//
// Run: dart run tool/check_keys.dart
//      dart run tool/check_keys.dart --update-baseline
//
// `find.text` is ambiguous by construction in this app: "Queue" is a nav
// destination, a screen title and a section header; "Save" is on every form;
// a patient's name appears on the row and again on the detail it opens.
// So every interactive widget a test drives gets a key from
// `lib/app/core/keys/`.
//
// Retrofitting three hundred widgets in one pull request is unreviewable, and
// a misplaced `key:` in a const constructor breaks layout silently. So this
// does not demand a clean tree. It records how many interactive widgets are
// still unkeyed and refuses to let that number grow. Keys arrive with the flow
// test that needs them, and the number only falls.
//
// The rules below the ratchet have no grace period, because each one is cheap
// to satisfy the first time and expensive to unpick later.

import 'dart:io';

const _baselineFile = 'tool/keys_baseline.txt';
const _keysDir = 'lib/app/core/keys';
const _modulesDir = 'lib/app/modules';
const _testDirs = ['integration_test'];

/// Widgets a test drives. A key on anything else is optional.
const _interactive = <String>[
  'ElevatedButton',
  'OutlinedButton',
  'TextButton',
  'IconButton',
  'FilledButton',
  'TextField',
  'TextFormField',
  'Switch',
  'Checkbox',
  'Radio',
  'DropdownButton',
  'DropdownButtonFormField',
  'GestureDetector',
  'InkWell',
];

final _violations = <String>[];
var _unkeyed = 0;
final _unkeyedByFile = <String, int>{};

void main(List<String> args) {
  final updateBaseline = args.contains('--update-baseline');

  _scanModules();
  _checkKeyFiles();
  _checkKeyCollisions();
  _checkNoPumpAndSettle();
  _checkNoFindTextInFlows();

  if (_violations.isNotEmpty) {
    stderr.writeln('\nKey hygiene failures:\n');
    for (final v in _violations) {
      stderr.writeln('  • $v');
    }
  }

  if (updateBaseline) {
    File(_baselineFile).writeAsStringSync('$_unkeyed\n');
    stdout.writeln('Baseline set to $_unkeyed.');
    exit(_violations.isEmpty ? 0 : 1);
  }

  final baseline = _readBaseline();

  if (_unkeyed > baseline) {
    final worst = _unkeyedByFile.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    stderr.writeln(
        '\nUnkeyed interactive widgets: $_unkeyed (baseline $baseline).');
    stderr.writeln('This number may only go down. Worst offenders:');
    for (final e in worst.take(10)) {
      stderr.writeln('  ${e.value.toString().padLeft(4)}  ${e.key}');
    }
    stderr.writeln('\nGive the widget you added a key from lib/app/core/keys/, '
        'or key an existing one in the same file to stay level.');
    exit(1);
  }

  if (_violations.isNotEmpty) exit(1);

  stdout.writeln('Key hygiene OK — $_unkeyed unkeyed (baseline $baseline).');
}

int _readBaseline() {
  final file = File(_baselineFile);
  if (!file.existsSync()) {
    stderr.writeln('No $_baselineFile. Run with --update-baseline first.');
    exit(1);
  }
  return int.parse(file.readAsStringSync().trim());
}

/// Counts interactive widgets in `lib/app/modules/**/views/` with no `key:`.
void _scanModules() {
  for (final file in _dartFilesIn(_modulesDir)) {
    if (!file.path.contains('/views/')) continue;
    final source = file.readAsStringSync();
    var count = 0;

    for (final widget in _interactive) {
      // Matches `Widget(` and `const Widget(` at a constructor position.
      final pattern = RegExp(r'(?<![\w.])' + widget + r'\s*\(');
      for (final match in pattern.allMatches(source)) {
        final body = _constructorBody(source, match.end - 1);
        if (body == null) continue;
        if (_hasKeyArgument(body)) continue;
        count++;
      }
    }

    if (count > 0) {
      _unkeyed += count;
      _unkeyedByFile[_relative(file.path)] = count;
    }
  }
}

/// Returns the text between the parentheses starting at [openParen], or null
/// when they are unbalanced (a generated or malformed file).
String? _constructorBody(String source, int openParen) {
  var depth = 0;
  for (var i = openParen; i < source.length; i++) {
    final ch = source[i];
    if (ch == '(') depth++;
    if (ch == ')') {
      depth--;
      if (depth == 0) return source.substring(openParen + 1, i);
    }
  }
  return null;
}

/// A `key:` at the top nesting level of the constructor body — a `key:` inside
/// a nested child does not key the parent.
bool _hasKeyArgument(String body) {
  var depth = 0;
  for (final match in RegExp(r'[(\[{}\])]|(?<![\w.])key\s*:').allMatches(body)) {
    final text = match.group(0)!;
    if ('([{'.contains(text)) {
      depth++;
    } else if (')]}'.contains(text)) {
      depth--;
    } else if (depth == 0) {
      return true;
    }
  }
  return false;
}

/// One key file per module, and every key file exported from the barrel.
void _checkKeyFiles() {
  final barrel = File('$_keysDir/app_keys.dart');
  if (!barrel.existsSync()) {
    _violations.add('$_keysDir/app_keys.dart is missing');
    return;
  }
  final exports = barrel.readAsStringSync();

  for (final file in _dartFilesIn(_keysDir)) {
    final name = file.uri.pathSegments.last;
    if (name == 'app_keys.dart') continue;
    if (!name.endsWith('_keys.dart')) {
      _violations.add('$_keysDir/$name should be named <module>_keys.dart');
    }
    if (!exports.contains("export '$name';")) {
      _violations.add('$name is not exported from app_keys.dart');
    }
  }

  // Every module with a view needs a key file, because a flow test that
  // reaches it will need an anchor.
  final modules = Directory(_modulesDir)
      .listSync()
      .whereType<Directory>()
      .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last);

  for (final module in modules) {
    final keyFile = File('$_keysDir/${module}_keys.dart');
    if (!keyFile.existsSync()) {
      _violations.add(
          'module "$module" has no $_keysDir/${module}_keys.dart (it needs at '
          'least a `screen` anchor)');
    }
  }
}

/// No key string may be declared twice.
///
/// Two modules that pick the same string are two screens a single `find.byKey`
/// cannot tell apart, and the failure reads as "the widget did not render"
/// rather than as a name clash. It happened the moment two streams built a
/// role editor and a settings screen at the same time.
///
/// A stricter rule was tried and dropped: flagging a literal that a templated
/// key such as `inpatient_ward_$id` could also produce. It fires 164 times on
/// this tree — `inpatient_ward_name` collides with it only if a ward's id is
/// literally the word "name" — and a check that cries wolf 164 times is a
/// check somebody turns off. The two real collisions it would have caught
/// (`billing_invoice_list` under `billing_invoice_$id`, and
/// `invoice_form_discount_amount` under `invoice_form_discount_$mode`) were
/// both found by a flow within a minute of the screen being wired.
void _checkKeyCollisions() {
  final literals = <String, String>{}; // key string -> where it was declared
  final declaration = RegExp(r"Key\('([^'$]*)'\)");

  for (final file in _dartFilesIn(_keysDir)) {
    final name = file.uri.pathSegments.last;
    final source = _withoutComments(file.readAsStringSync());

    for (final match in declaration.allMatches(source)) {
      final raw = match.group(1)!;
      final seen = literals[raw];
      if (seen != null && seen != name) {
        _violations.add("key '$raw' is declared twice — $seen and $name");
      } else {
        literals[raw] = name;
      }
    }
  }
}

/// `pumpAndSettle` is banned in the e2e suite — see integration_test/support/
/// pump.dart for why.
void _checkNoPumpAndSettle() {
  for (final dir in _testDirs) {
    for (final file in _dartFilesIn(dir)) {
      // The file that documents the ban necessarily names it.
      if (file.path.endsWith('support/pump.dart')) continue;
      final source = file.readAsStringSync();
      if (RegExp(r'\.pumpAndSettle\s*\(').hasMatch(source)) {
        _violations.add('${_relative(file.path)} calls pumpAndSettle — use '
            'pumpUntil / pumpUntilRouteSettled (see support/pump.dart)');
      }
    }
  }
}

/// A flow test never calls `find.*` directly; finders live in robots.
///
/// Comments are stripped before the check. English sentences end in "find." far
/// more often than Dart code calls it, and a rule that flags prose is a rule
/// people learn to work around by writing worse comments.
///
/// The demo walkthrough is held to the same rule for the same reason: it drives
/// more of the app in one run than any single flow does, so it is the file a UI
/// change would otherwise break in the most places.
void _checkNoFindTextInFlows() {
  const dirs = ['integration_test/flows', 'integration_test/demo'];
  for (final dir in dirs) {
    for (final file in _dartFilesIn(dir)) {
      final source = _withoutComments(file.readAsStringSync());
      final matches = RegExp(r'(?<![\w.])find\.').allMatches(source);
      if (matches.isNotEmpty) {
        _violations.add('${_relative(file.path)} calls find.* directly — put '
            'the finder in a robot (integration_test/robots/)');
      }
    }
  }
}

/// Drops line and block comments, keeping the code's line structure.
///
/// Not a Dart parser, and it does not need to be: it is only asked whether a
/// line of *code* mentions `find.`, and the one shape that would fool it — a
/// `//` inside a string literal — does not appear in a flow test.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .map((line) {
      final comment = line.indexOf('//');
      return comment == -1 ? line : line.substring(0, comment);
    })
    .join('\n');

Iterable<File> _dartFilesIn(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

String _relative(String path) =>
    path.replaceFirst('${Directory.current.path}/', '');
