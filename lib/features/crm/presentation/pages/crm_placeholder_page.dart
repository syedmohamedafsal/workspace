import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Base module scaffold for the REBS CRM module.
class CrmPlaceholderPage extends StatelessWidget {
  const CrmPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CRM')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.handshake_outlined,
                size: 40,
                color: AppTheme.textMuted,
              ),
              SizedBox(height: 12),
              Text(
                'CRM Module',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Leads, accounts, and deal pipelines will plug into the shared Clean Architecture and offline sync engine here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
