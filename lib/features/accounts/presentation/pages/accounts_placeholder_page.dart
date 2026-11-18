import 'package:flutter/material.dart';

/// Base module scaffold for the REBS Accounts module.
///
/// Follow the same Clean Architecture layers under `lib/features/accounts/`
/// (`domain/`, `data/`, `presentation/`) and register a [SyncHandler] with
/// [SyncManager] for offline-first expenses, invoices, and ledger entries.
class AccountsPlaceholderPage extends StatelessWidget {
  const AccountsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'REBS Accounts Module',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Module scaffold ready. Plug in invoices, expense claims, and ledger features using the shared Clean Architecture & offline sync engine.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
