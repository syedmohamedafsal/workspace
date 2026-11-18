import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/sync/sync_manager.dart';
import '../../../../../core/sync/sync_status.dart';
import '../../domain/usecases/apply_leave.dart';
import '../../domain/usecases/cancel_leave.dart';
import '../../domain/usecases/get_leave_balances.dart';
import '../../domain/usecases/get_leave_requests.dart';
import 'leave_event.dart';
import 'leave_state.dart';

class LeaveBloc extends Bloc<LeaveEvent, LeaveState> {
  LeaveBloc({
    required GetLeaveRequests getLeaveRequests,
    required GetLeaveBalances getLeaveBalances,
    required ApplyLeave applyLeave,
    required CancelLeave cancelLeave,
    required SyncManager syncManager,
  })  : _getLeaveRequests = getLeaveRequests,
        _getLeaveBalances = getLeaveBalances,
        _applyLeave = applyLeave,
        _cancelLeave = cancelLeave,
        _syncManager = syncManager,
        super(const LeaveState()) {
    on<LoadLeaveDataRequested>(_onLoadLeaveData);
    on<ApplyLeaveSubmitted>(_onApplyLeave);
    on<CancelLeaveSubmitted>(_onCancelLeave);

    _syncSubscription = _syncManager.statusStream.listen((snapshot) {
      if (_wasSyncing && !snapshot.isSyncing) {
        add(const LoadLeaveDataRequested());
      }
      _wasSyncing = snapshot.isSyncing;
    });
  }

  final GetLeaveRequests _getLeaveRequests;
  final GetLeaveBalances _getLeaveBalances;
  final ApplyLeave _applyLeave;
  final CancelLeave _cancelLeave;
  final SyncManager _syncManager;

  StreamSubscription<SyncSnapshot>? _syncSubscription;
  bool _wasSyncing = false;

  Future<void> _onLoadLeaveData(
    LoadLeaveDataRequested event,
    Emitter<LeaveState> emit,
  ) async {
    if (state.status == LeaveViewStatus.initial) {
      emit(state.copyWith(status: LeaveViewStatus.loading, clearError: true));
    }

    final balancesResult = await _getLeaveBalances(
      GetLeaveBalancesParams(refreshRemote: event.refreshRemote),
    );
    final requestsResult = await _getLeaveRequests(
      GetLeaveRequestsParams(refreshRemote: event.refreshRemote),
    );

    if (balancesResult.isFailure) {
      emit(
        state.copyWith(
          status: LeaveViewStatus.failure,
          errorMessage: balancesResult.failureOrNull?.message,
        ),
      );
      return;
    }

    if (requestsResult.isFailure) {
      emit(
        state.copyWith(
          status: LeaveViewStatus.failure,
          errorMessage: requestsResult.failureOrNull?.message,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: LeaveViewStatus.loaded,
        balances: balancesResult.dataOrNull ?? const [],
        requests: requestsResult.dataOrNull ?? const [],
        clearError: true,
        clearFeedback: true,
      ),
    );
  }

  Future<void> _onApplyLeave(
    ApplyLeaveSubmitted event,
    Emitter<LeaveState> emit,
  ) async {
    emit(
      state.copyWith(
        status: LeaveViewStatus.submitting,
        clearError: true,
        clearFeedback: true,
      ),
    );

    final result = await _applyLeave(
      ApplyLeaveParams(
        leaveType: event.leaveType,
        startDate: event.startDate,
        endDate: event.endDate,
        isHalfDay: event.isHalfDay,
        reason: event.reason,
      ),
    );

    await result.fold(
      onSuccess: (_) async {
        final balances = await _getLeaveBalances(const GetLeaveBalancesParams());
        final requests = await _getLeaveRequests(const GetLeaveRequestsParams());
        emit(
          state.copyWith(
            status: LeaveViewStatus.loaded,
            balances: balances.dataOrNull ?? state.balances,
            requests: requests.dataOrNull ?? state.requests,
            feedbackMessage: 'Leave request submitted.',
          ),
        );
      },
      onFailure: (failure) async {
        emit(
          state.copyWith(
            status: LeaveViewStatus.loaded,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  Future<void> _onCancelLeave(
    CancelLeaveSubmitted event,
    Emitter<LeaveState> emit,
  ) async {
    emit(
      state.copyWith(
        status: LeaveViewStatus.submitting,
        clearError: true,
        clearFeedback: true,
      ),
    );

    final result = await _cancelLeave(CancelLeaveParams(event.localId));

    await result.fold(
      onSuccess: (_) async {
        final balances = await _getLeaveBalances(const GetLeaveBalancesParams());
        final requests = await _getLeaveRequests(const GetLeaveRequestsParams());
        emit(
          state.copyWith(
            status: LeaveViewStatus.loaded,
            balances: balances.dataOrNull ?? state.balances,
            requests: requests.dataOrNull ?? state.requests,
            feedbackMessage: 'Leave request cancelled.',
          ),
        );
      },
      onFailure: (failure) async {
        emit(
          state.copyWith(
            status: LeaveViewStatus.loaded,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  @override
  Future<void> close() async {
    await _syncSubscription?.cancel();
    return super.close();
  }
}
