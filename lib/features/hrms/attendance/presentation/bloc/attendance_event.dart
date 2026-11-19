import 'package:equatable/equatable.dart';

sealed class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => const [];
}

final class LoadAttendanceRequested extends AttendanceEvent {
  const LoadAttendanceRequested({this.refreshRemote = false});

  final bool refreshRemote;

  @override
  List<Object?> get props => [refreshRemote];
}

final class CheckInSubmitted extends AttendanceEvent {
  const CheckInSubmitted({
    this.workLocation,
    this.note,
    this.employeeName,
  });

  final String? workLocation;
  final String? note;
  final String? employeeName;

  @override
  List<Object?> get props => [workLocation, note, employeeName];
}

final class CheckOutSubmitted extends AttendanceEvent {
  const CheckOutSubmitted({
    this.note,
    this.employeeName,
    this.isOfficeHoursOver,
  });

  final String? note;
  final String? employeeName;
  final bool? isOfficeHoursOver;

  @override
  List<Object?> get props => [note, employeeName, isOfficeHoursOver];
}

final class ResetTodayAttendanceRequested extends AttendanceEvent {
  const ResetTodayAttendanceRequested({this.employeeName});

  final String? employeeName;

  @override
  List<Object?> get props => [employeeName];
}
