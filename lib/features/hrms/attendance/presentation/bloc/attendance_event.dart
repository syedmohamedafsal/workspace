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
  });

  final String? workLocation;
  final String? note;

  @override
  List<Object?> get props => [workLocation, note];
}

final class CheckOutSubmitted extends AttendanceEvent {
  const CheckOutSubmitted({this.note});

  final String? note;

  @override
  List<Object?> get props => [note];
}
