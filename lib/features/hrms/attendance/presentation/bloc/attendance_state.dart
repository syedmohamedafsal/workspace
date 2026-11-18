import 'package:equatable/equatable.dart';

import '../../domain/entities/attendance_record.dart';

enum AttendanceViewStatus { initial, loading, loaded, submitting, failure }

class AttendanceState extends Equatable {
  const AttendanceState({
    this.status = AttendanceViewStatus.initial,
    this.todayRecord,
    this.history = const [],
    this.errorMessage,
    this.feedbackMessage,
  });

  final AttendanceViewStatus status;
  final AttendanceRecord? todayRecord;
  final List<AttendanceRecord> history;
  final String? errorMessage;
  final String? feedbackMessage;

  AttendanceState copyWith({
    AttendanceViewStatus? status,
    AttendanceRecord? todayRecord,
    bool clearTodayRecord = false,
    List<AttendanceRecord>? history,
    String? errorMessage,
    bool clearError = false,
    String? feedbackMessage,
    bool clearFeedback = false,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      todayRecord: clearTodayRecord ? null : (todayRecord ?? this.todayRecord),
      history: history ?? this.history,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      feedbackMessage:
          clearFeedback ? null : (feedbackMessage ?? this.feedbackMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        todayRecord,
        history,
        errorMessage,
        feedbackMessage,
      ];
}
