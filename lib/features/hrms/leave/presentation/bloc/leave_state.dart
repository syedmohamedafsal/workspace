import 'package:equatable/equatable.dart';

import '../../domain/entities/leave_balance.dart';
import '../../domain/entities/leave_request.dart';

enum LeaveViewStatus { initial, loading, loaded, submitting, failure }

class LeaveState extends Equatable {
  const LeaveState({
    this.status = LeaveViewStatus.initial,
    this.balances = const [],
    this.requests = const [],
    this.errorMessage,
    this.feedbackMessage,
  });

  final LeaveViewStatus status;
  final List<LeaveBalance> balances;
  final List<LeaveRequest> requests;
  final String? errorMessage;
  final String? feedbackMessage;

  LeaveState copyWith({
    LeaveViewStatus? status,
    List<LeaveBalance>? balances,
    List<LeaveRequest>? requests,
    String? errorMessage,
    bool clearError = false,
    String? feedbackMessage,
    bool clearFeedback = false,
  }) {
    return LeaveState(
      status: status ?? this.status,
      balances: balances ?? this.balances,
      requests: requests ?? this.requests,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      feedbackMessage:
          clearFeedback ? null : (feedbackMessage ?? this.feedbackMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        balances,
        requests,
        errorMessage,
        feedbackMessage,
      ];
}
