import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/leave_request.dart';

class ApplyLeaveFormResult {
  const ApplyLeaveFormResult({
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.isHalfDay,
    required this.reason,
  });

  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final bool isHalfDay;
  final String reason;
}

class ApplyLeaveSheet extends StatefulWidget {
  const ApplyLeaveSheet({super.key});

  @override
  State<ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<ApplyLeaveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  LeaveType _leaveType = LeaveType.annual;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isHalfDay = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate) || _isHalfDay) {
          _endDate = _startDate;
        }
      } else {
        _endDate = picked;
        if (_endDate != _startDate) {
          _isHalfDay = false;
        }
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ApplyLeaveFormResult(
        leaveType: _leaveType,
        startDate: _startDate,
        endDate: _isHalfDay ? _startDate : _endDate,
        isHalfDay: _isHalfDay,
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Apply for Leave',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<LeaveType>(
                initialValue: _leaveType,
                decoration: const InputDecoration(labelText: 'Leave Type'),
                items: LeaveType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _leaveType = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text('From: ${dateFmt.format(_startDate)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _isHalfDay ? null : () => _pickDate(isStart: false),
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text('To: ${dateFmt.format(_endDate)}'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Half-day leave'),
                value: _isHalfDay,
                onChanged: (value) {
                  setState(() {
                    _isHalfDay = value;
                    if (_isHalfDay) {
                      _endDate = _startDate;
                    }
                  });
                },
              ),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Briefly describe the reason for leave',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: const Text('Submit Leave Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
