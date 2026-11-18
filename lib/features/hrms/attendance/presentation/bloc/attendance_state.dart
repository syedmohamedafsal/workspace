import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../domain/entities/attendance_record.dart';

enum AttendanceViewStatus { initial, loading, loaded, submitting, failure }

class AttendanceState extends Equatable {
  const AttendanceState({
    this.status = AttendanceViewStatus.initial,
    this.todayRecord,
    this.history = const [],
    this.errorMessage,
    this.lastFailure,
    this.feedbackMessage,
    this.feedbackSequence = 0,
  });

  final AttendanceViewStatus status;
  final AttendanceRecord? todayRecord;
  final List<AttendanceRecord> history;
  final String? errorMessage;
  final Failure? lastFailure;
  final String? feedbackMessage;

  /// Increments on every check-in/out result so repeated failures (e.g. tapping
  /// twice while outside the geofence) reliably surface feedback to the user.
  final int feedbackSequence;

  AttendanceState copyWith({
    AttendanceViewStatus? status,
    AttendanceRecord? todayRecord,
    bool clearTodayRecord = false,
    List<AttendanceRecord>? history,
    String? errorMessage,
    Failure? lastFailure,
    bool clearError = false,
    String? feedbackMessage,
    bool clearFeedback = false,
    int? feedbackSequence,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      todayRecord: clearTodayRecord ? null : (todayRecord ?? this.todayRecord),
      history: history ?? this.history,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastFailure: clearError ? null : (lastFailure ?? this.lastFailure),
      feedbackMessage:
          clearFeedback ? null : (feedbackMessage ?? this.feedbackMessage),
      feedbackSequence: feedbackSequence ?? this.feedbackSequence,
    );
  }

  @override
  List<Object?> get props => [
        status,
        todayRecord,
        history,
        errorMessage,
        lastFailure,
        feedbackMessage,
        feedbackSequence,
      ];
}
