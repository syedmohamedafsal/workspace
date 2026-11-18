import 'package:flutter/material.dart';

/// Minimal placeholder screen for the Employee Dashboard route.
///
/// Kept intentionally isolated so it can be replaced directly when the
/// Employee Dashboard feature is implemented in Step 3.
class EmployeeDashboardPlaceholderPage extends StatelessWidget {
  const EmployeeDashboardPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('REBS'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Employee Dashboard - Coming Soon',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
