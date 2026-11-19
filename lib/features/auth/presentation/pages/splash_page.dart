import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Application launch screen featuring the official TEQBAE brand logo while
/// restoring or initializing the preconfigured employee session.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const Color _brandDark = Color(0xFF0A0B0D);
  static const Color _brandEmerald = Color(0xFF22B57D);

  Timer? _splashTimer;
  bool _timerElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    final authBloc = context.read<AuthBloc>();
    if (authBloc.state is AuthInitial) {
      authBloc.add(const AuthSessionInitializeRequested());
    }

    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    final splashDuration = isTest
        ? Duration.zero
        : (sl.isRegistered<AppConfig>()
            ? sl<AppConfig>().splashDuration
            : const Duration(seconds: 3));

    if (splashDuration == Duration.zero) {
      _timerElapsed = true;
      _checkAndNavigate();
    } else {
      _splashTimer = Timer(splashDuration, () {
        if (!mounted) return;
        _timerElapsed = true;
        _checkAndNavigate();
      });
    }
  }

  void _checkAndNavigate() {
    if (_navigated || !_timerElapsed || !mounted) return;
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) {
      _navigated = true;
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            _checkAndNavigate();
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: _brandDark,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/teqbae_logo.png',
                        height: 54,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'TEQBAE WORKSPACE',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: _brandEmerald,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HRMS Employee Workspace',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 36),
                      switch (state) {
                        AuthError(:final message) => _SplashErrorSection(
                            message: message,
                            onRetry: () => context
                                .read<AuthBloc>()
                                .add(const AuthSessionRetryRequested()),
                          ),
                        AuthInitial() ||
                        AuthLoading() ||
                        AuthAuthenticated() =>
                          Column(
                            children: [
                              const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: _brandEmerald,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Initializing workspace...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                      },
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SplashErrorSection extends StatelessWidget {
  const _SplashErrorSection({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFF87171),
            size: 32,
          ),
          const SizedBox(height: 10),
          const Text(
            'Initialization Failed',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFD1D5DB),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22B57D),
              foregroundColor: const Color(0xFF0A0B0D),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
