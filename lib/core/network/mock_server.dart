import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Scenario mode for repeatable mock behavior.
enum MockScenario {
  success('success'),
  slow('slow'),
  timeout('timeout'),
  serverError('server_error'),
  conflict('conflict'),
  validationError('validation_error');

  const MockScenario(this.value);
  final String value;

  static MockScenario fromString(String? raw) {
    if (raw == null) return MockScenario.success;
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    return MockScenario.values.firstWhere(
      (s) => s.value == normalized,
      orElse: () => MockScenario.success,
    );
  }
}

/// Standalone, pure-Dart mock HTTP server for the REBS workspace application.
///
/// Implements all 6 Section 5 endpoints:
/// - `GET  /employee/me`
/// - `GET  /attendance?month=YYYY-MM`
/// - `POST /attendance/events`
/// - `GET  /leave/balance`
/// - `GET  /leave/requests`
/// - `POST /leave/requests`
///
/// Supports repeatable mock scenarios selectable via:
/// 1. `X-Mock-Scenario` HTTP request header
/// 2. `?scenario=` query parameter
/// 3. `POST /mock/scenario` dynamic control endpoint
class MockHttpServer {
  MockHttpServer({
    this.port = 8080,
    this.host = '0.0.0.0',
  });

  final int port;
  final String host;

  HttpServer? _server;
  MockScenario _activeScenario = MockScenario.success;

  // In-memory data store
  late Map<String, dynamic> _employee;
  late List<Map<String, dynamic>> _attendanceRecords;
  late List<Map<String, dynamic>> _leaveBalances;
  late List<Map<String, dynamic>> _leaveRequests;
  final Map<String, Map<String, dynamic>> _idempotencyCache = {};

  bool get isRunning => _server != null;
  int get boundPort => _server?.port ?? port;
  MockScenario get activeScenario => _activeScenario;

  /// Starts the mock server.
  Future<int> start({int? port}) async {
    resetDataStore();
    final targetPort = port ?? this.port;
    _server = await HttpServer.bind(
      host == '0.0.0.0' ? InternetAddress.anyIPv4 : host,
      targetPort,
    );
    _server!.listen(_handleRequest);
    return _server!.port;
  }

  /// Stops the mock server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// Sets the active repeatable scenario.
  void setScenario(MockScenario scenario) {
    _activeScenario = scenario;
  }

  /// Resets the in-memory data store to initial seed state.
  void resetDataStore() {
    _activeScenario = MockScenario.success;
    _idempotencyCache.clear();

    _employee = {
      'id': 'REBS001',
      'employee_id': 'REBS001',
      'name': 'Syed Mohamed Afsal',
      'email': 'afsal@teqbae.com',
      'role': 'Flutter Developer',
      'designation': 'Flutter Developer',
      'department': 'Engineering',
      'office_id': 'OFF_KOCHI_01',
      'office_name': 'Teqbae Innovations, Kochi',
      'office_latitude': 10.0159,
      'office_longitude': 76.3419,
      'allowed_radius_meters': 200.0,
      'company_timezone': 'Asia/Kolkata',
    };

    _leaveBalances = [
      {
        'leave_type': 'Casual',
        'available_days': 12.0,
        'total_days': 15.0,
        'used_days': 3.0,
        'pending_days': 0.0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      {
        'leave_type': 'Sick',
        'available_days': 7.0,
        'total_days': 10.0,
        'used_days': 3.0,
        'pending_days': 0.0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    ];

    _leaveRequests = [
      {
        'id': 'LV-001',
        'client_id': 'seed-lv-001',
        'employee_id': 'REBS001',
        'leave_type': 'Sick',
        'start_date': '2026-11-05',
        'end_date': '2026-11-06',
        'total_days': 2.0,
        'is_half_day': false,
        'reason': 'Viral fever recovery with medical prescription',
        'status': 'approved',
        'approval_status': 'approved',
        'applied_at': '2026-11-04T09:15:00.000Z',
        'created_at': '2026-11-04T09:15:00.000Z',
        'updated_at': '2026-11-04T12:00:00.000Z',
      },
      {
        'id': 'LV-002',
        'client_id': 'seed-lv-002',
        'employee_id': 'REBS001',
        'leave_type': 'Casual',
        'start_date': '2026-11-25',
        'end_date': '2026-11-26',
        'total_days': 2.0,
        'is_half_day': false,
        'reason': 'Family wedding ceremony attendance',
        'status': 'pending',
        'approval_status': 'pending',
        'applied_at': '2026-11-15T11:00:00.000Z',
        'created_at': '2026-11-15T11:00:00.000Z',
        'updated_at': '2026-11-15T11:00:00.000Z',
      },
    ];

    _attendanceRecords = [
      {
        'id': 'SRV-ATT-101',
        'client_id': 'seed-att-101',
        'employee_id': 'REBS001',
        'date': '2026-11-17',
        'attendance_date': '2026-11-17',
        'check_in_at': '2026-11-17T09:12:00.000Z',
        'check_out_at': '2026-11-17T18:02:00.000Z',
        'check_in_latitude': 10.0159,
        'check_in_longitude': 76.3419,
        'check_in_distance_meters': 18.0,
        'check_out_latitude': 10.0159,
        'check_out_longitude': 76.3419,
        'check_out_distance_meters': 25.0,
        'work_location': 'Teqbae Innovations, Kochi',
        'status': 'checkedOut',
        'sync_status': 'synced',
        'created_at': '2026-11-17T09:12:00.000Z',
        'updated_at': '2026-11-17T18:02:00.000Z',
      },
      {
        'id': 'SRV-ATT-102',
        'client_id': 'seed-att-102',
        'employee_id': 'REBS001',
        'date': '2026-11-16',
        'attendance_date': '2026-11-16',
        'check_in_at': '2026-11-16T08:58:00.000Z',
        'check_out_at': '2026-11-16T17:45:00.000Z',
        'check_in_latitude': 10.0158,
        'check_in_longitude': 76.3420,
        'check_in_distance_meters': 24.0,
        'check_out_latitude': 10.0159,
        'check_out_longitude': 76.3419,
        'check_out_distance_meters': 20.0,
        'work_location': 'Teqbae Innovations, Kochi',
        'status': 'checkedOut',
        'sync_status': 'synced',
        'created_at': '2026-11-16T08:58:00.000Z',
        'updated_at': '2026-11-16T17:45:00.000Z',
      },
    ];
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _applyCors(request);

    // Handle preflight
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    final method = request.method;

    // Check for scenario override
    final headerScenario = request.headers.value('x-mock-scenario');
    final queryScenario = request.uri.queryParameters['scenario'];
    final effectiveScenario = headerScenario != null
        ? MockScenario.fromString(headerScenario)
        : queryScenario != null
            ? MockScenario.fromString(queryScenario)
            : _activeScenario;

    // Intercept control endpoints first (these bypass scenario simulation)
    if (path == '/mock/scenario') {
      if (method == 'POST') {
        final body = await _readJsonBody(request);
        final sc = body['scenario'] as String?;
        if (sc != null) {
          _activeScenario = MockScenario.fromString(sc);
        }
        await _sendJson(request, {
          'status': 'ok',
          'active_scenario': _activeScenario.value,
        });
        return;
      }
      await _sendJson(request, {
        'active_scenario': _activeScenario.value,
      });
      return;
    }

    if (path == '/mock/reset' && method == 'POST') {
      resetDataStore();
      await _sendJson(request, {
        'status': 'ok',
        'message': 'Mock server data and scenario reset successfully.',
      });
      return;
    }

    // Apply Repeatable Scenarios
    switch (effectiveScenario) {
      case MockScenario.slow:
        await Future.delayed(const Duration(milliseconds: 2500));
        break;
      case MockScenario.timeout:
        // Delay beyond typical client timeout (20 seconds)
        await Future.delayed(const Duration(seconds: 20));
        break;
      case MockScenario.serverError:
        await _sendJson(
          request,
          {
            'error': 'Internal server error: simulated REBS service failure.',
            'code': 500,
          },
          statusCode: HttpStatus.internalServerError,
        );
        return;
      case MockScenario.conflict:
        if (method == 'POST') {
          await _sendJson(
            request,
            {
              'error': 'Attendance already recorded for this working day.',
              'code': 'DUPLICATE_ATTENDANCE',
            },
            statusCode: HttpStatus.conflict,
          );
          return;
        }
        break;
      case MockScenario.validationError:
        if (method == 'POST') {
          await _sendJson(
            request,
            {
              'error': 'Validation failed: simulated mock validation rejection.',
              'code': 'VALIDATION_FAILED',
            },
            statusCode: HttpStatus.unprocessableEntity,
          );
          return;
        }
        break;
      case MockScenario.success:
        break;
    }

    try {
      // 0. Health Check
      if (method == 'GET' && (path == '/health' || path == '/')) {
        await _sendJson(request, {
          'status': 'ok',
          'service': 'REBS Mock Server',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      }

      // 1. Employee Me
      if (method == 'GET' && path == '/employee/me') {
        await _sendJson(request, {'data': _employee, ..._employee});
        return;
      }

      // 2. Attendance History
      if (method == 'GET' &&
          (path == '/attendance' || path == '/hrms/attendance/history')) {
        final month = request.uri.queryParameters['month'];
        var records = _attendanceRecords;
        if (month != null && month.isNotEmpty) {
          records = records.where((r) {
            final date = r['date'] as String? ?? '';
            return date.startsWith(month);
          }).toList();
        }
        await _sendJson(request, {
          'items': records,
          'data': records,
        });
        return;
      }

      // 3. Attendance Events
      if (method == 'POST' &&
          (path == '/attendance/events' ||
              path == '/hrms/attendance/check-in' ||
              path == '/hrms/attendance/check-out')) {
        await _handleAttendanceEvent(request, path);
        return;
      }

      // 4. Leave Balance
      if (method == 'GET' && path == '/leave/balance') {
        await _sendJson(request, {
          'employee_id': _employee['employee_id'],
          'balances': _leaveBalances,
          'items': _leaveBalances,
        });
        return;
      }

      // 5. Existing Leave Requests
      if (method == 'GET' && path == '/leave/requests') {
        await _sendJson(request, {
          'items': _leaveRequests,
          'data': _leaveRequests,
        });
        return;
      }

      // 6. Submit Leave Application
      if (method == 'POST' && path == '/leave/requests') {
        await _handleLeaveSubmission(request);
        return;
      }

      // 7. Cancel Leave Application
      final cancelMatch = RegExp(
        r'^(?:/hrms)?/leave/requests/([^/]+)/cancel/?$',
        caseSensitive: false,
      ).firstMatch(path);
      final deleteLeaveMatch = RegExp(
        r'^(?:/hrms)?/leave/requests/([^/]+)/?$',
        caseSensitive: false,
      ).firstMatch(path);

      if ((method == 'POST' && cancelMatch != null) ||
          (method == 'DELETE' && deleteLeaveMatch != null)) {
        final leaveId = (cancelMatch ?? deleteLeaveMatch)!.group(1)!;
        await _handleLeaveCancellation(request, leaveId);
        return;
      }

      // 404 Fallback
      await _sendJson(
        request,
        {
          'error': 'Endpoint not found on REBS mock server: $method $path',
          'code': 404,
        },
        statusCode: HttpStatus.notFound,
      );
    } catch (e) {
      await _sendJson(
        request,
        {
          'error': 'Server error handling $method $path: $e',
          'code': 500,
        },
        statusCode: HttpStatus.internalServerError,
      );
    }
  }

  Future<void> _handleAttendanceEvent(HttpRequest request, String path) async {
    final body = await _readJsonBody(request);
    final eventId = (body['event_id'] ??
            request.headers.value('x-idempotency-key') ??
            body['client_id'] ??
            '')
        .toString();

    // Idempotency check: if already processed, return existing response
    if (eventId.isNotEmpty && _idempotencyCache.containsKey(eventId)) {
      final cached = _idempotencyCache[eventId]!;
      await _sendJson(request, cached, statusCode: HttpStatus.created);
      return;
    }

    final rawType = (body['event_type'] as String? ?? '').toLowerCase();
    final isCheckIn = rawType.contains('in') || path.contains('check-in');
    final isCheckOut = rawType.contains('out') || path.contains('check-out');

    final employeeId =
        (body['employee_id'] as String?) ?? _employee['employee_id'] as String;
    final timestampStr = (body['timestamp'] ??
            body['check_in_at'] ??
            body['check_out_at'] ??
            DateTime.now().toUtc().toIso8601String())
        .toString();
    final timestamp = DateTime.tryParse(timestampStr) ?? DateTime.now();
    final dateKey = (body['date'] ??
            body['attendance_date'] ??
            _formatDateKey(timestamp))
        .toString();

    final lat = (body['latitude'] as num?)?.toDouble() ??
        (body['check_in_latitude'] as num?)?.toDouble() ??
        (body['check_out_latitude'] as num?)?.toDouble();
    final lng = (body['longitude'] as num?)?.toDouble() ??
        (body['check_in_longitude'] as num?)?.toDouble() ??
        (body['check_out_longitude'] as num?)?.toDouble();
    final distance = (body['distance_meters'] as num?)?.toDouble();

    if (isCheckIn) {
      // Check for duplicate attendance on the same calendar day
      final duplicate = _attendanceRecords.where((r) {
        return r['employee_id'] == employeeId &&
            r['date'] == dateKey &&
            r['check_in_at'] != null;
      }).firstOrNull;

      if (duplicate != null) {
        await _sendJson(
          request,
          {
            'error':
                'Attendance already recorded for this working day ($dateKey).',
            'code': 'DUPLICATE_ATTENDANCE',
            'existing_record': duplicate,
          },
          statusCode: HttpStatus.conflict,
        );
        return;
      }

      final serverId = 'SRV-ATT-${_attendanceRecords.length + 101}';
      final record = {
        'id': serverId,
        'server_id': serverId,
        'client_id': body['client_id'] ?? eventId,
        'employee_id': employeeId,
        'date': dateKey,
        'attendance_date': dateKey,
        'check_in_at': timestamp.toIso8601String(),
        'check_in_latitude': lat,
        'check_in_longitude': lng,
        'check_in_distance_meters': distance,
        'work_location': body['work_location'] ?? 'Teqbae Innovations, Kochi',
        'status': 'checkedIn',
        'sync_status': 'synced',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      _attendanceRecords.insert(0, record);
      final responsePayload = {'status': 'success', 'data': record};
      if (eventId.isNotEmpty) {
        _idempotencyCache[eventId] = responsePayload;
      }
      await _sendJson(request, responsePayload, statusCode: HttpStatus.created);
      return;
    }

    if (isCheckOut) {
      // Check-out is permitted only after check-in
      final existingIndex = _attendanceRecords.indexWhere((r) {
        return r['employee_id'] == employeeId && r['date'] == dateKey;
      });

      if (existingIndex < 0 ||
          _attendanceRecords[existingIndex]['check_in_at'] == null) {
        await _sendJson(
          request,
          {
            'error': 'You have to check in before you check out.',
            'code': 'CHECK_OUT_WITHOUT_CHECK_IN',
          },
          statusCode: HttpStatus.unprocessableEntity,
        );
        return;
      }

      final existing =
          Map<String, dynamic>.from(_attendanceRecords[existingIndex]);
      existing['check_out_at'] = timestamp.toIso8601String();
      existing['check_out_latitude'] = lat;
      existing['check_out_longitude'] = lng;
      existing['check_out_distance_meters'] = distance;
      existing['status'] = 'checkedOut';
      existing['updated_at'] = DateTime.now().toUtc().toIso8601String();

      _attendanceRecords[existingIndex] = existing;
      final responsePayload = {'status': 'success', 'data': existing};
      if (eventId.isNotEmpty) {
        _idempotencyCache[eventId] = responsePayload;
      }
      await _sendJson(request, responsePayload, statusCode: HttpStatus.created);
      return;
    }

    await _sendJson(
      request,
      {
        'error': 'Unknown event_type: $rawType',
        'code': 'INVALID_EVENT_TYPE',
      },
      statusCode: HttpStatus.badRequest,
    );
  }

  Future<void> _handleLeaveSubmission(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final idempotencyKey = request.headers.value('x-idempotency-key') ??
        body['idempotency_key']?.toString();

    if (idempotencyKey != null &&
        idempotencyKey.isNotEmpty &&
        _idempotencyCache.containsKey(idempotencyKey)) {
      final cached = _idempotencyCache[idempotencyKey]!;
      await _sendJson(request, cached, statusCode: HttpStatus.created);
      return;
    }

    final reason = (body['reason'] as String? ?? '').trim();
    final leaveTypeStr = (body['leave_type'] as String? ?? 'Casual').trim();
    final startDateStr = (body['start_date'] as String? ?? '').trim();
    final endDateStr = (body['end_date'] as String? ?? '').trim();

    // 1. Reason non-whitespace length validation (>= 10 chars)
    final nonWhitespaceReason = reason.replaceAll(RegExp(r'\s+'), '');
    if (nonWhitespaceReason.length < 10) {
      await _sendJson(
        request,
        {
          'error': 'Reason must contain at least 10 non-whitespace characters.',
          'code': 'REASON_TOO_SHORT',
        },
        statusCode: HttpStatus.unprocessableEntity,
      );
      return;
    }

    // 2. Dates validation
    final startDate = DateTime.tryParse(startDateStr);
    final endDate = DateTime.tryParse(endDateStr);
    if (startDate == null || endDate == null) {
      await _sendJson(
        request,
        {
          'error': 'Invalid start_date or end_date format.',
          'code': 'INVALID_DATES',
        },
        statusCode: HttpStatus.unprocessableEntity,
      );
      return;
    }

    if (endDate.isBefore(startDate)) {
      await _sendJson(
        request,
        {
          'error': 'End date cannot be before start date.',
          'code': 'END_DATE_BEFORE_START',
        },
        statusCode: HttpStatus.unprocessableEntity,
      );
      return;
    }

    // Requested days: count all calendar days
    final requestedDays =
        endDate.difference(startDate).inDays + 1; // All calendar days count

    // 3. Balance validation
    final balanceItem = _leaveBalances.where((b) {
      final t = (b['leave_type'] as String).toLowerCase();
      return t == leaveTypeStr.toLowerCase();
    }).firstOrNull;

    if (balanceItem != null) {
      final available = (balanceItem['available_days'] as num).toDouble();
      if (requestedDays > available) {
        await _sendJson(
          request,
          {
            'error':
                'Requested days ($requestedDays) exceed available balance ($available).',
            'code': 'INSUFFICIENT_BALANCE',
          },
          statusCode: HttpStatus.unprocessableEntity,
        );
        return;
      }
    }

    // 4. Overlap validation with Pending or Approved requests
    final overlaps = _leaveRequests.any((r) {
      final status = (r['status'] as String? ?? '').toLowerCase();
      if (status != 'pending' && status != 'approved') return false;
      final exStart = DateTime.tryParse(r['start_date'] as String? ?? '');
      final exEnd = DateTime.tryParse(r['end_date'] as String? ?? '');
      if (exStart == null || exEnd == null) return false;

      final endsBefore = endDate.isBefore(exStart);
      final startsAfter = startDate.isAfter(exEnd);
      return !(endsBefore || startsAfter);
    });

    if (overlaps) {
      await _sendJson(
        request,
        {
          'error':
              'Requested leave dates overlap with an existing pending or approved request.',
          'code': 'LEAVE_OVERLAP',
        },
        statusCode: HttpStatus.unprocessableEntity,
      );
      return;
    }

    // Create leave request
    final newId = 'LV-${_leaveRequests.length + 101}';
    final newRequest = {
      'id': newId,
      'client_id': body['client_id'] ?? newId,
      'employee_id': body['employee_id'] ?? _employee['employee_id'],
      'leave_type': leaveTypeStr,
      'start_date': startDateStr,
      'end_date': endDateStr,
      'total_days': requestedDays.toDouble(),
      'is_half_day': body['is_half_day'] ?? false,
      'reason': reason,
      'status': 'pending',
      'approval_status': 'pending',
      'applied_at': DateTime.now().toUtc().toIso8601String(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Deduct available balance
    if (balanceItem != null) {
      final currentAvailable =
          (balanceItem['available_days'] as num).toDouble();
      final currentUsed = (balanceItem['used_days'] as num).toDouble();
      balanceItem['available_days'] = currentAvailable - requestedDays;
      balanceItem['used_days'] = currentUsed + requestedDays;
      balanceItem['updated_at'] = DateTime.now().toUtc().toIso8601String();
    }

    _leaveRequests.insert(0, newRequest);
    final responsePayload = {'status': 'success', 'data': newRequest};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      _idempotencyCache[idempotencyKey] = responsePayload;
    }
    await _sendJson(request, responsePayload, statusCode: HttpStatus.created);
  }

  Future<void> _handleLeaveCancellation(
    HttpRequest request,
    String leaveId,
  ) async {
    final idempotencyKey = request.headers.value('x-idempotency-key');
    if (idempotencyKey != null &&
        idempotencyKey.isNotEmpty &&
        _idempotencyCache.containsKey(idempotencyKey)) {
      await _sendJson(request, _idempotencyCache[idempotencyKey]!);
      return;
    }

    var target = _leaveRequests.where((r) {
      return r['id'] == leaveId || r['client_id'] == leaveId;
    }).firstOrNull;

    if (target == null) {
      target = {
        'id': leaveId,
        'client_id': leaveId,
        'employee_id': _employee['employee_id'],
        'leave_type': 'Casual',
        'start_date': DateTime.now().toUtc().toIso8601String(),
        'end_date': DateTime.now().toUtc().toIso8601String(),
        'total_days': 1.0,
        'is_half_day': false,
        'reason': 'Cancelled by employee',
        'status': 'cancelled',
        'approval_status': 'cancelled',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      _leaveRequests.insert(0, target);
    } else {
      target['status'] = 'cancelled';
      target['approval_status'] = 'cancelled';
      target['updated_at'] = DateTime.now().toUtc().toIso8601String();

      // Restore leave balance
      final leaveTypeStr = target['leave_type'] as String? ?? 'Casual';
      final totalDays = (target['total_days'] as num?)?.toDouble() ?? 1.0;
      final balanceItem = _leaveBalances.where((b) {
        final t = (b['leave_type'] as String).toLowerCase();
        return t == leaveTypeStr.toLowerCase();
      }).firstOrNull;

      if (balanceItem != null) {
        final currentAvailable =
            (balanceItem['available_days'] as num).toDouble();
        final currentUsed = (balanceItem['used_days'] as num).toDouble();
        balanceItem['available_days'] = currentAvailable + totalDays;
        balanceItem['used_days'] = (currentUsed - totalDays).clamp(0.0, 999.0);
        balanceItem['updated_at'] = DateTime.now().toUtc().toIso8601String();
      }
    }

    final responsePayload = {'status': 'success', 'data': target};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      _idempotencyCache[idempotencyKey] = responsePayload;
    }
    await _sendJson(request, responsePayload, statusCode: HttpStatus.ok);
  }

  void _applyCors(HttpRequest request) {
    request.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set(
        'Access-Control-Allow-Methods',
        'GET, POST, PUT, DELETE, OPTIONS',
      )
      ..set(
        'Access-Control-Allow-Headers',
        'Origin, Content-Type, Accept, Authorization, X-Idempotency-Key, X-Mock-Scenario',
      )
      ..set('Access-Control-Max-Age', '86400');
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    if (content.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _sendJson(
    HttpRequest request,
    Map<String, dynamic> data, {
    int statusCode = HttpStatus.ok,
  }) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }

  static String _formatDateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
