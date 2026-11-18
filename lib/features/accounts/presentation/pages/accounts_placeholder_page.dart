import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Base module scaffold for the REBS Accounts module.
class AccountsPlaceholderPage extends StatelessWidget {
  const AccountsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 40,
                color: AppTheme.textMuted,
              ),
              SizedBox(height: 12),
              Text(
                'Accounts Module',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Invoices, expense claims, and ledger records will plug into the shared Clean Architecture and offline sync engine here.',
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
