import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medihive/app/data/utils/api_envelope.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MediHive — `ApiEnvelope`
///
/// The unwrapping every service call goes through, and the one place two
/// backend quirks are resolved rather than rediscovered per screen: the payload
/// lives under `data` but a handful of older handlers still answer with
/// `result`, and a 200 carrying `success: false` is a real failure this API
/// returns. A client that trusts the status code alone renders an empty list
/// against a perfectly good error.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  /// A response as Dio hands it over, with only the parts the envelope reads.
  Response<dynamic> responseOf(dynamic body, {int status = 200}) => Response(
        requestOptions: RequestOptions(path: '/api/queue'),
        statusCode: status,
        data: body,
      );

  group('finding the payload', () {
    test('reads data, the key this backend answers with', () {
      final envelope = ApiEnvelope.of(
        responseOf({
          'success': true,
          'data': {'id': 7, 'name': 'Ward A'},
          'message': '',
        }),
      );

      expect(envelope.success, isTrue);
      expect(envelope.object, {'id': 7, 'name': 'Ward A'});
    });

    test('falls back to result, which older handlers still answer with', () {
      // Reading only one of the two keys is how a screen renders an empty list
      // against a perfectly good 200.
      final envelope = ApiEnvelope.of(
        responseOf({
          'success': true,
          'result': [
            {'id': 1},
            {'id': 2},
          ],
        }),
      );

      expect(envelope.success, isTrue);
      expect(envelope.objects, hasLength(2));
      expect(envelope.listOf((json) => json['id'] as int), [1, 2]);
    });

    test('data wins when a response carries both', () {
      final envelope = ApiEnvelope.of(
        responseOf({
          'success': true,
          'data': {'from': 'data'},
          'result': {'from': 'result'},
        }),
      );

      expect(envelope.object, {'from': 'data'});
    });

    test('an explicit null payload is an empty object, not a crash', () {
      // What a successful delete answers with.
      final envelope = ApiEnvelope.of(
        responseOf({'success': true, 'data': null}),
      );

      expect(envelope.success, isTrue);
      expect(envelope.result, isNull);
      expect(envelope.object, isEmpty);
      expect(envelope.objects, isEmpty);
    });

    test('a single object from a list endpoint reads as a list of one', () {
      // Some list routes drop the array when exactly one row matched.
      final envelope = ApiEnvelope.of(
        responseOf({
          'success': true,
          'data': {'id': 9},
        }),
      );

      expect(envelope.objects, [
        {'id': 9},
      ]);
    });
  });

  group('deciding whether the call succeeded', () {
    test('a 200 carrying success:false is a failure', () {
      // A validation failure comes back as 409 from most handlers and as 200
      // from some, so the flag decides and the status code does not.
      final envelope = ApiEnvelope.of(
        responseOf({
          'success': false,
          'data': null,
          'message': 'Bed 4B is already occupied.',
        }),
      );

      expect(envelope.success, isFalse);
      expect(envelope.message, 'Bed 4B is already occupied.');
    });

    test('a body that is not a map at all is a failure with a usable message',
        () {
      // A proxy's HTML error page. Nothing inside it is worth showing a user,
      // so the envelope supplies its own line.
      final envelope = ApiEnvelope.of(
        responseOf('<html><body>502 Bad Gateway</body></html>', status: 502),
      );

      expect(envelope.success, isFalse);
      expect(envelope.message, contains('502'));
    });

    test('an empty collection answered with 202 or 203 is not a failure', () {
      // This backend answers an empty list with 203 and an empty search with
      // 202, both carrying success:false — and a client that trusts the flag
      // alone shows an error banner to a user whose only crime is having no
      // invoices yet.
      for (final status in [202, 203]) {
        final envelope = ApiEnvelope.of(
          responseOf({'success': false, 'data': <dynamic>[]}, status: status),
        );

        expect(envelope.success, isTrue, reason: 'HTTP $status');
        expect(envelope.isEmptyCollection, isTrue, reason: 'HTTP $status');
        expect(envelope.objects, isEmpty, reason: 'HTTP $status');
      }
    });

    test('a 202 carrying a real message is still a failure', () {
      // Keyed on the payload being a list as well as on the status, so a real
      // error at one of those codes keeps its message.
      final envelope = ApiEnvelope.of(
        responseOf(
          {'success': false, 'data': null, 'message': 'Search is disabled.'},
          status: 202,
        ),
      );

      expect(envelope.success, isFalse);
      expect(envelope.isEmptyCollection, isFalse);
    });

    test('msg is read as well as message', () {
      // Two core routes answer with `{msg: "…"}` and no envelope at all, and
      // reading only `message` turns "Enter the same password twice" into a
      // blank "Request failed."
      final envelope = ApiEnvelope.of(
        responseOf({'success': false, 'msg': 'Enter the same password twice.'}),
      );

      expect(envelope.message, 'Enter the same password twice.');
    });
  });

  group('orThrow', () {
    test('hands the envelope straight back when the call succeeded', () {
      final envelope = ApiEnvelope.of(
        responseOf({
          'success': true,
          'data': {'id': 1},
        }),
      );

      expect(envelope.orThrow(), same(envelope));
    });

    test('throws ApiException carrying the words the server sent', () {
      // The controller catches one exception type and shows one message, so
      // the server's own wording has to survive the unwrapping.
      final envelope = ApiEnvelope.of(
        responseOf({
          'success': false,
          'message': 'Bed 4B is already occupied.',
        }),
      );

      expect(
        envelope.orThrow,
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Bed 4B is already occupied.',
          ),
        ),
      );
    });

    test('falls back to a line a user can read when the server sent none', () {
      // A raw exception must never reach a user, and neither must a blank one.
      final envelope = ApiEnvelope.of(responseOf({'success': false}));

      expect(
        envelope.orThrow,
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Request failed.',
          ),
        ),
      );
    });
  });
}
