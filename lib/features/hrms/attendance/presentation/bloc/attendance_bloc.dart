import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/sync/sync_manager.dart';
import '../../../../../core/sync/sync_status.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/usecases/check_in.dart';
import '../../domain/usecases/check_out.dart';
import '../../domain/usecases/get_attendance_history.dart';
import '../../domain/usecases/get_today_attendance.dart';
import '../../domain/usecases/reset_today_attendance.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  AttendanceBloc({
    required GetTodayAttendance getTodayAttendance,
    required GetAttendanceHistory getAttendanceHistory,
    required CheckIn checkIn,
    required CheckOut checkOut,
    ResetTodayAttendance? resetTodayAttendance,
    required SyncManager syncManager,
  })  : _getTodayAttendance = getTodayAttendance,
        _getAttendanceHistory = getAttendanceHistory,
        _checkIn = checkIn,
        _checkOut = checkOut,
        _resetTodayAttendance = resetTodayAttendance,
        _syncManager = syncManager,
        super(const AttendanceState()) {
    on<LoadAttendanceRequested>(_onLoadAttendance);
    on<CheckInSubmitted>(_onCheckIn);
    on<CheckOutSubmitted>(_onCheckOut);
    on<ResetTodayAttendanceRequested>(_onResetTodayAttendance);

    // Reload local records whenever background sync completes so sync badges
    // update live without extra user interaction.
    _syncSubscription = _syncManager.statusStream.listen((snapshot) {
      if (_wasSyncing && !snapshot.isSyncing) {
        add(const LoadAttendanceRequested());
      }
      _wasSyncing = snapshot.isSyncing;
    });
  }

  final GetTodayAttendance _getTodayAttendance;
  final GetAttendanceHistory _getAttendanceHistory;
  final CheckIn _checkIn;
  final CheckOut _checkOut;
  final ResetTodayAttendance? _resetTodayAttendance;
  final SyncManager _syncManager;

  StreamSubscription<SyncSnapshot>? _syncSubscription;
  bool _wasSyncing = false;
  DateTime? _lastCheckInSuccessAt;
  DateTime? _lastCheckOutSuccessAt;

  static const Duration _doubleTapGuardWindow = Duration(seconds: 2);

  Future<void> _onLoadAttendance(
    LoadAttendanceRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    if (state.status == AttendanceViewStatus.initial) {
      emit(state.copyWith(status: AttendanceViewStatus.loading, clearError: true));
    }

    final todayResult = await _getTodayAttendance(const NoParams());
    final historyResult = await _getAttendanceHistory(
      GetAttendanceHistoryParams(refreshRemote: event.refreshRemote),
    );

    if (todayResult.isFailure) {
      emit(
        state.copyWith(
          status: AttendanceViewStatus.failure,
          errorMessage: todayResult.failureOrNull?.message,
          lastFailure: todayResult.failureOrNull,
        ),
      );
      return;
    }

    if (historyResult.isFailure) {
      emit(
        state.copyWith(
          status: AttendanceViewStatus.failure,
          errorMessage: historyResult.failureOrNull?.message,
          lastFailure: historyResult.failureOrNull,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AttendanceViewStatus.loaded,
        todayRecord: todayResult.dataOrNull,
        clearTodayRecord: todayResult.dataOrNull == null,
        history: historyResult.dataOrNull ?? const [],
        clearError: true,
        clearFeedback: true,
      ),
    );
  }

  Future<void> _onCheckIn(
    CheckInSubmitted event,
    Emitter<AttendanceState> emit,
  ) async {
    // Ignore repeated taps while submitting or queued immediately after success.
    if (state.status == AttendanceViewStatus.submitting) return;
    if (_lastCheckInSuccessAt != null &&
        DateTime.now().difference(_lastCheckInSuccessAt!) <
            _doubleTapGuardWindow) {
      return;
    }

    emit(
      state.copyWith(
        status: AttendanceViewStatus.submitting,
        clearError: true,
        clearFeedback: true,
      ),
    );

    final result = await _checkIn(
      CheckInParams(workLocation: event.workLocation, note: event.note),
    );

    await result.fold(
      onSuccess: (record) async {
        _lastCheckInSuccessAt = DateTime.now();
        final historyResult = await _getAttendanceHistory(
          const GetAttendanceHistoryParams(),
        );
        final rawName = event.employeeName?.trim();
        final firstName = (rawName != null && rawName.isNotEmpty)
            ? rawName.split(' ').first
            : 'there';
        final dist = record.checkInDistanceMeters != null
            ? ' • ${record.checkInDistanceMeters!.round()}m from office'
            : '';
        emit(
          state.copyWith(
            status: AttendanceViewStatus.loaded,
            todayRecord: record,
            history: historyResult.dataOrNull ?? state.history,
            feedbackMessage:
                'Hey $firstName, take a coffee and code, and don\'t forget to commit! ☕💻🚀$dist',
            feedbackSequence: state.feedbackSequence + 1,
          ),
        );
      },
      onFailure: (failure) async {
        emit(
          state.copyWith(
            status: AttendanceViewStatus.loaded,
            errorMessage: failure.message,
            lastFailure: failure,
            feedbackSequence: state.feedbackSequence + 1,
          ),
        );
      },
    );
  }

  Future<void> _onCheckOut(
    CheckOutSubmitted event,
    Emitter<AttendanceState> emit,
  ) async {
    // Ignore repeated taps while submitting or queued immediately after success.
    if (state.status == AttendanceViewStatus.submitting) return;
    if (_lastCheckOutSuccessAt != null &&
        DateTime.now().difference(_lastCheckOutSuccessAt!) <
            _doubleTapGuardWindow) {
      return;
    }

    emit(
      state.copyWith(
        status: AttendanceViewStatus.submitting,
        clearError: true,
        clearFeedback: true,
      ),
    );

    final result = await _checkOut(CheckOutParams(note: event.note));

    await result.fold(
      onSuccess: (record) async {
        _lastCheckOutSuccessAt = DateTime.now();
        final historyResult = await _getAttendanceHistory(
          const GetAttendanceHistoryParams(),
        );
        final rawName = event.employeeName?.trim();
        final firstName = (rawName != null && rawName.isNotEmpty)
            ? rawName.split(' ').first
            : 'bro';
        final isOver = event.isOfficeHoursOver ??
            (record.workedDuration != null &&
                record.workedDuration!.inHours >= 8);
        final sweetMessage = isOver
            ? 'Checked out! Office hours are over, enjoy your own time and recharge, $firstName! 🌙🛋️'
            : 'Checked out! It\'s office time bro, take care of your personal errands! 👍';
        emit(
          state.copyWith(
            status: AttendanceViewStatus.loaded,
            todayRecord: record,
            history: historyResult.dataOrNull ?? state.history,
            feedbackMessage: sweetMessage,
            feedbackSequence: state.feedbackSequence + 1,
          ),
        );
      },
      onFailure: (failure) async {
        emit(
          state.copyWith(
            status: AttendanceViewStatus.loaded,
            errorMessage: failure.message,
            lastFailure: failure,
            feedbackSequence: state.feedbackSequence + 1,
          ),
        );
      },
    );
  }

  Future<void> _onResetTodayAttendance(
    ResetTodayAttendanceRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    if (_resetTodayAttendance != null) {
      await _resetTodayAttendance(const NoParams());
    }
    _lastCheckInSuccessAt = null;
    _lastCheckOutSuccessAt = null;
    final historyResult = await _getAttendanceHistory(
      const GetAttendanceHistoryParams(),
    );
    emit(
      state.copyWith(
        status: AttendanceViewStatus.loaded,
        clearTodayRecord: true,
        history: historyResult.dataOrNull ?? state.history,
        feedbackMessage:
            'Today\'s attendance reset! You can now test Check In and Check Out again fresh. 🔄',
        feedbackSequence: state.feedbackSequence + 1,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _syncSubscription?.cancel();
    return super.close();
  }
}
