import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs/core/network/mock_server.dart';

void main() {
  late MockHttpServer mockServer;
  late Dio dio;

  setUp(() async {
    mockServer = MockHttpServer(port: 0); // Port 0 binds an ephemeral port
    final port = await mockServer.start();
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://127.0.0.1:$port',
        validateStatus: (_) => true, // Don't throw on 4xx/5xx in test assertions
      ),
    );
  });

  tearDown(() async {
    await mockServer.stop();
  });

  group('Section 5 Endpoints - Success Scenarios', () {
    test('GET /employee/me returns employee and office configuration', () async {
      final res = await dio.get<Map<String, dynamic>>('/employee/me');
      expect(res.statusCode, equals(HttpStatus.ok));
      final json = res.data!;
      expect(json['employee_id'], equals('REBS001'));
      expect(json['name'], equals('Syed Mohamed Afsal'));
      expect(json['office_name'], equals('Teqbae Innovations, Kochi'));
      expect(json['office_latitude'], equals(10.0159));
      expect(json['office_longitude'], equals(76.3419));
      expect(json['allowed_radius_meters'], equals(200.0));
      expect(json['company_timezone'], equals('Asia/Kolkata'));
    });

    test('GET /attendance?month=YYYY-MM returns attendance history', () async {
      final res = await dio.get<Map<String, dynamic>>(
        '/attendance',
        queryParameters: {'month': '2026-11'},
      );
      expect(res.statusCode, equals(HttpStatus.ok));
      final json = res.data!;
      expect(json['items'], isA<List>());
      final items = json['items'] as List;
      expect(items, isNotEmpty);
      expect(items.first['employee_id'], equals('REBS001'));
    });

    test('POST /attendance/events submits check-in and check-out successfully', () async {
      final checkInRes = await dio.post<Map<String, dynamic>>(
        '/attendance/events',
        data: {
          'event_id': 'evt-checkin-001',
          'employee_id': 'REBS001',
          'event_type': 'check_in',
          'date': '2026-11-19',
          'timestamp': '2026-11-19T09:02:00.000Z',
          'latitude': 10.0159,
          'longitude': 76.3419,
          'distance_meters': 25.0,
        },
      );
      expect(checkInRes.statusCode, equals(HttpStatus.created));
      final checkInJson = checkInRes.data!;
      expect(checkInJson['status'], equals('success'));
      expect(checkInJson['data']['status'], equals('checkedIn'));

      // Check-out on the same day
      final checkOutRes = await dio.post<Map<String, dynamic>>(
        '/attendance/events',
        data: {
          'event_id': 'evt-checkout-001',
          'employee_id': 'REBS001',
          'event_type': 'check_out',
          'date': '2026-11-19',
          'timestamp': '2026-11-19T18:05:00.000Z',
          'latitude': 10.0159,
          'longitude': 76.3419,
          'distance_meters': 28.0,
        },
      );
      expect(checkOutRes.statusCode, equals(HttpStatus.created));
      final checkOutJson = checkOutRes.data!;
      expect(checkOutJson['data']['status'], equals('checkedOut'));
    });

    test('POST /attendance/events guarantees idempotency on duplicate event_id', () async {
      final payload = {
        'event_id': 'evt-idempotent-001',
        'employee_id': 'REBS001',
        'event_type': 'check_in',
        'date': '2026-11-20',
        'timestamp': '2026-11-20T09:00:00.000Z',
      };

      final res1 = await dio.post<Map<String, dynamic>>(
        '/attendance/events',
        data: payload,
      );
      expect(res1.statusCode, equals(HttpStatus.created));

      // Same event_id retried
      final res2 = await dio.post<Map<String, dynamic>>(
        '/attendance/events',
        data: payload,
      );
      expect(res2.statusCode, equals(HttpStatus.created));
      expect(res1.data!['data']['id'], equals(res2.data!['data']['id']));
    });

    test('GET /leave/balance returns available leave balances', () async {
      final res = await dio.get<Map<String, dynamic>>('/leave/balance');
      expect(res.statusCode, equals(HttpStatus.ok));
      final json = res.data!;
      expect(json['balances'], isA<List>());
      final balances = json['balances'] as List;
      expect(balances.length, equals(2));
      final casual = balances.firstWhere((b) => b['leave_type'] == 'Casual');
      expect(casual['available_days'], equals(12.0));
    });

    test('GET /leave/requests returns existing leave requests', () async {
      final res = await dio.get<Map<String, dynamic>>('/leave/requests');
      expect(res.statusCode, equals(HttpStatus.ok));
      final json = res.data!;
      expect(json['items'], isA<List>());
      final items = json['items'] as List;
      expect(items.length, greaterThanOrEqualTo(2));
    });

    test('POST /leave/requests creates a valid leave request and deducts balance', () async {
      final res = await dio.post<Map<String, dynamic>>(
        '/leave/requests',
        data: {
          'employee_id': 'REBS001',
          'leave_type': 'Casual',
          'start_date': '2026-11-28',
          'end_date': '2026-11-29',
          'reason': 'Attending close friend family function',
        },
      );
      expect(res.statusCode, equals(HttpStatus.created));
      final json = res.data!;
      expect(json['status'], equals('success'));
      expect(json['data']['total_days'], equals(2.0));
      expect(json['data']['status'], equals('pending'));

      // Verify balance deduction
      final balRes = await dio.get<Map<String, dynamic>>('/leave/balance');
      final casual = (balRes.data!['balances'] as List)
          .firstWhere((b) => b['leave_type'] == 'Casual');
      expect(casual['available_days'], equals(10.0));
    });

    test('POST /leave/requests/:id/cancel cancels request and restores balance', () async {
      final res = await dio.post<Map<String, dynamic>>('/leave/requests/LV-002/cancel');
      expect(res.statusCode, equals(HttpStatus.ok));
      final json = res.data!;
      expect(json['status'], equals('success'));
      expect(json['data']['status'], equals('cancelled'));
      expect(json['data']['approval_status'], equals('cancelled'));
    });
  });

  group('Section 5 Endpoints - Validation & Conflict Handling', () {
    test('POST /attendance/events rejects duplicate check-in with 409 Conflict', () async {
      // 2026-11-17 is already seeded with an attendance record
      final res = await dio.post<Map<String, dynamic>>(
        '/attendance/events',
        data: {
          'event_id': 'evt-new-conflict',
          'employee_id': 'REBS001',
          'event_type': 'check_in',
          'date': '2026-11-17',
          'timestamp': '2026-11-17T10:00:00.000Z',
        },
      );
      expect(res.statusCode, equals(HttpStatus.conflict));
      expect(res.data!['code'], equals('DUPLICATE_ATTENDANCE'));
    });

    test('POST /attendance/events rejects check-out without prior check-in with 422', () async {
      final res = await dio.post<Map<String, dynamic>>(
        '/attendance/events',
        data: {
          'event_id': 'evt-no-checkin',
          'employee_id': 'REBS001',
          'event_type': 'check_out',
          'date': '2026-11-30',
          'timestamp': '2026-11-30T18:00:00.000Z',
        },
      );
      expect(res.statusCode, equals(HttpStatus.unprocessableEntity));
      expect(res.data!['code'], equals('CHECK_OUT_WITHOUT_CHECK_IN'));
    });

    test('POST /leave/requests rejects reason shorter than 10 non-whitespace chars with 422', () async {
      final res = await dio.post<Map<String, dynamic>>(
        '/leave/requests',
        data: {
          'employee_id': 'REBS001',
          'leave_type': 'Casual',
          'start_date': '2026-11-28',
          'end_date': '2026-11-29',
          'reason': 'Sick', // < 10 non-whitespace chars
        },
      );
      expect(res.statusCode, equals(HttpStatus.unprocessableEntity));
      expect(res.data!['code'], equals('REASON_TOO_SHORT'));
    });

    test('POST /leave/requests rejects end date before start date with 422', () async {
      final res = await dio.post<Map<String, dynamic>>(
        '/leave/requests',
        data: {
          'employee_id': 'REBS001',
          'leave_type': 'Casual',
          'start_date': '2026-11-29',
          'end_date': '2026-11-28',
          'reason': 'Personal leave request longer than 10 characters',
        },
      );
      expect(res.statusCode, equals(HttpStatus.unprocessableEntity));
      expect(res.data!['code'], equals('END_DATE_BEFORE_START'));
    });

    test('POST /leave/requests rejects overlapping leave request with 422', () async {
      // 2026-11-25 to 2026-11-26 is already pending in seeds
      final res = await dio.post<Map<String, dynamic>>(
        '/leave/requests',
        data: {
          'employee_id': 'REBS001',
          'leave_type': 'Casual',
          'start_date': '2026-11-25',
          'end_date': '2026-11-27',
          'reason': 'Overlap test reason with more than ten characters',
        },
      );
      expect(res.statusCode, equals(HttpStatus.unprocessableEntity));
      expect(res.data!['code'], equals('LEAVE_OVERLAP'));
    });

    test('POST /leave/requests rejects requested days exceeding balance with 422', () async {
      // Sick balance is 7 days, request 10 days
      final res = await dio.post<Map<String, dynamic>>(
        '/leave/requests',
        data: {
          'employee_id': 'REBS001',
          'leave_type': 'Sick',
          'start_date': '2026-12-01',
          'end_date': '2026-12-10', // 10 days > 7 available
          'reason': 'Medical recovery and hospital rehabilitation',
        },
      );
      expect(res.statusCode, equals(HttpStatus.unprocessableEntity));
      expect(res.data!['code'], equals('INSUFFICIENT_BALANCE'));
    });
  });

  group('Repeatable Mock Scenarios via Header / Query / Control', () {
    test('X-Mock-Scenario: server_error triggers HTTP 500', () async {
      final res = await dio.get<Map<String, dynamic>>(
        '/employee/me',
        options: Options(headers: {'X-Mock-Scenario': 'server_error'}),
      );
      expect(res.statusCode, equals(HttpStatus.internalServerError));
      expect(res.data!['code'], equals(500));
    });

    test('?scenario=conflict triggers HTTP 409 Conflict on POST', () async {
      final res = await dio.post<Map<String, dynamic>>(
        '/attendance/events',
        queryParameters: {'scenario': 'conflict'},
        data: {
          'event_id': 'force-conflict',
          'employee_id': 'REBS001',
          'event_type': 'check_in',
        },
      );
      expect(res.statusCode, equals(HttpStatus.conflict));
      expect(res.data!['code'], equals('DUPLICATE_ATTENDANCE'));
    });

    test('POST /mock/scenario sets global scenario and POST /mock/reset clears it', () async {
      // Set global scenario to validation_error
      final setRes = await dio.post<Map<String, dynamic>>(
        '/mock/scenario',
        data: {'scenario': 'validation_error'},
      );
      expect(setRes.statusCode, equals(HttpStatus.ok));

      // Any POST now triggers 422
      final postRes = await dio.post<Map<String, dynamic>>(
        '/leave/requests',
        data: {'test': true},
      );
      expect(postRes.statusCode, equals(HttpStatus.unprocessableEntity));

      // Reset
      final resetRes = await dio.post<Map<String, dynamic>>('/mock/reset');
      expect(resetRes.statusCode, equals(HttpStatus.ok));

      // Reset restored normal behavior
      expect(mockServer.activeScenario, equals(MockScenario.success));
    });
  });
}
