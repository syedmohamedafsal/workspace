import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';

/// Hub listing the REBS business automation modules (HRMS, CRM, Accounts).
class RebsModulesPage extends StatelessWidget {
  const RebsModulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        const Text(
          'Teqbae Platform Modules',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Unified business automation powered by shared offline sync.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              _ModuleRow(
                icon: Icons.badge_outlined,
                iconColor: AppTheme.primary,
                iconBg: AppTheme.primarySoft,
                title: 'HRMS',
                subtitle: 'Attendance check-in/out & leave management',
                trailingLabel: 'Active',
                isActive: true,
                onTap: () => context.go(AppRoutes.dashboard),
              ),
              const Divider(height: 1, indent: 68, endIndent: 16),
              _ModuleRow(
                icon: Icons.handshake_outlined,
                iconColor: const Color(0xFF0EA5E9),
                iconBg: const Color(0xFFF0F9FF),
                title: 'CRM',
                subtitle: 'Leads, accounts, pipeline & customer tasks',
                trailingLabel: 'Planned',
                isActive: false,
                onTap: () => context.push(AppRoutes.crm),
              ),
              const Divider(height: 1, indent: 68, endIndent: 16),
              _ModuleRow(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF10B981),
                iconBg: const Color(0xFFECFDF5),
                title: 'Accounts',
                subtitle: 'Invoices, expense claims & ledger entries',
                trailingLabel: 'Planned',
                isActive: false,
                onTap: () => context.push(AppRoutes.accounts),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 21, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12.5,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trailingLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? const Color(0xFF166534)
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppTheme.textMuted,
          ),
        ],
      ),
    );
  }
}
