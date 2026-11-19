import 'dart:io';
import 'package:rebs/core/network/mock_server.dart';

Future<void> main(List<String> args) async {
  final portEnv = Platform.environment['PORT'];
  final port = int.tryParse(portEnv ?? '') ?? 8080;

  final server = MockHttpServer(port: port);
  final boundPort = await server.start(port: port);

  stdout.writeln('╔══════════════════════════════════════════════════════════════╗');
  stdout.writeln('║       REBS HRMS Mock HTTP API Server (Section 5 Spec)        ║');
  stdout.writeln('╠══════════════════════════════════════════════════════════════╣');
  stdout.writeln('║ Base URL: http://127.0.0.1:$boundPort                               ║');
  stdout.writeln('║ Android Emulator: http://10.0.2.2:$boundPort                        ║');
  stdout.writeln('╠══════════════════════════════════════════════════════════════╣');
  stdout.writeln('║ Supported REST Endpoints:                                    ║');
  stdout.writeln('║   GET  /employee/me          (Employee & Office Config)      ║');
  stdout.writeln('║   GET  /attendance?month=..  (Monthly Attendance History)    ║');
  stdout.writeln('║   POST /attendance/events    (Check-in & Check-out Events)   ║');
  stdout.writeln('║   GET  /leave/balance        (Available Leave Balances)      ║');
  stdout.writeln('║   GET  /leave/requests       (Existing Leave Requests)       ║');
  stdout.writeln('║   POST /leave/requests       (Submit Leave Application)      ║');
  stdout.writeln('║   POST /leave/requests/:id/cancel (Cancel Leave Request)     ║');
  stdout.writeln('╠══════════════════════════════════════════════════════════════╣');
  stdout.writeln('║ Repeatable Mock Scenarios (Header: X-Mock-Scenario or ?sc=): ║');
  stdout.writeln('║   • success          - Normal 200/201 response               ║');
  stdout.writeln('║   • slow             - Artificial 2500ms delay               ║');
  stdout.writeln('║   • timeout          - 20s delay triggering client timeout   ║');
  stdout.writeln('║   • server_error     - Returns HTTP 500                      ║');
  stdout.writeln('║   • conflict         - Returns HTTP 409 (duplicate conflict) ║');
  stdout.writeln('║   • validation_error - Returns HTTP 422                      ║');
  stdout.writeln('╠══════════════════════════════════════════════════════════════╣');
  stdout.writeln('║ Scenario Controls:                                           ║');
  stdout.writeln('║   POST /mock/scenario {"scenario": "conflict"}               ║');
  stdout.writeln('║   GET  /mock/scenario                                        ║');
  stdout.writeln('║   POST /mock/reset                                           ║');
  stdout.writeln('╚══════════════════════════════════════════════════════════════╝');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nStopping REBS Mock Server...');
    await server.stop();
    exit(0);
  });
}
