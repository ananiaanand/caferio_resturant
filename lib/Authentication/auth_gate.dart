import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/main_layout.dart';
import '../utils/theme.dart';
import 'auth_service.dart';
import 'login_page.dart';
import 'mfa_pages.dart';

/// By default MFA is optional so users can register and use the app freely,
/// but if they enroll in 2FA, it will be strictly challenged on each session.
/// Change to true if your platform requires mandatory 2FA enrollment.
const bool requireMfaByDefault = false;

class AuthGate extends StatefulWidget {
  final bool requireMfa;

  const AuthGate({
    super.key,
    this.requireMfa = requireMfaByDefault,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.instance.onAuthStateChange,
      builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
        final AuthState? state = snapshot.data;

        // User opened the password recovery link from their email
        if (state?.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordPage();
        }

        final bool isAuth = AuthService.instance.isAuthenticated;
        final bool isGuest = AuthService.instance.isGuest;
        final Session? session =
            state?.session ?? AuthService.instance.currentSession;

        // Neither authenticated nor guest -> show Instagram-style LoginPage
        if (!isAuth && !isGuest && session == null) {
          return LoginPage(
            onGuestBrowse: () {
              AuthService.instance.enterGuestMode();
            },
          );
        }

        // Guest mode -> allow exploring MainLayout
        if (isGuest && !isAuth) {
          return const MainLayout();
        }

        // Authenticated user -> pass through MFA Gate
        return _MfaGate(
          key: ValueKey<String>(
            session?.accessToken ??
                AuthService.instance.currentAccessToken ??
                'session',
          ),
          requireMfa: widget.requireMfa,
        );
      },
    );
  }
}

/// Decides whether to challenge for MFA or allow access to MainLayout.
class _MfaGate extends StatefulWidget {
  final bool requireMfa;

  const _MfaGate({
    super.key,
    required this.requireMfa,
  });

  @override
  State<_MfaGate> createState() => _MfaGateState();
}

class _MfaGateState extends State<_MfaGate> {
  late Future<MfaStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<MfaStatus> _loadStatus() async {
    try {
      final MfaStatus status = await AuthService.instance.resolveMfaStatus();
      if (!widget.requireMfa && status == MfaStatus.needsEnroll) {
        // Optional MFA: user hasn't enrolled yet, so let them through.
        return MfaStatus.ok;
      }
      return status;
    } catch (_) {
      // In case of network timeout or unexpected error, fallback to ok if session is valid
      return MfaStatus.ok;
    }
  }

  void _refresh() {
    setState(() {
      _statusFuture = _loadStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MfaStatus>(
      future: _statusFuture,
      builder: (BuildContext context, AsyncSnapshot<MfaStatus> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Verifying security session...',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.shield_outlined,
                      size: 64,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Security Verification Failed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Could not verify your security status. Please try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textLight),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _refresh,
                      child: const Text('Retry Verification'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => AuthService.instance.signOut(),
                      child: const Text(
                        'Sign out',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final status = snapshot.data ?? MfaStatus.ok;
        switch (status) {
          case MfaStatus.needsEnroll:
            return MfaEnrollPage(onDone: _refresh);
          case MfaStatus.needsChallenge:
            return MfaChallengePage(onDone: _refresh);
          case MfaStatus.ok:
            return const MainLayout();
        }
      },
    );
  }
}
