import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/theme.dart';
import 'auth_service.dart';

// -----------------------------------------------------------------------------
// ENROLL: Show QR code, user scans with Authenticator App, enters 6-digit code
// -----------------------------------------------------------------------------
class MfaEnrollPage extends StatefulWidget {
  const MfaEnrollPage({
    super.key,
    required this.onDone,
    this.canSkip = false,
  });

  final VoidCallback onDone;
  final bool canSkip;

  @override
  State<MfaEnrollPage> createState() => _MfaEnrollPageState();
}

class _MfaEnrollPageState extends State<MfaEnrollPage> {
  final TextEditingController _codeController = TextEditingController();

  String? _factorId;
  String? _qrSvg;
  String? _secret;
  String? _error;
  bool _isLoading = true;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startEnrollment();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final AuthMFAEnrollResponse response =
          await AuthService.instance.enrollTotp();

      setState(() {
        _factorId = response.id;
        _qrSvg = response.totp?.qrCode;
        _secret = response.totp?.secret;
        _isLoading = false;
      });
    } on AuthException catch (error) {
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize MFA: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _verify() async {
    final String code = _codeController.text.trim();
    if (code.length != 6 || _factorId == null) {
      setState(() => _error = 'Please enter the 6-digit authentication code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      await AuthService.instance.verifyTotp(factorId: _factorId!, code: code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Two-factor authentication successfully enabled!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      widget.onDone();
    } on AuthException catch (error) {
      setState(() {
        _error = error.message;
        _isVerifying = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Verification failed. Please try again.';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Set Up Two-Factor Auth'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        actions: [
          if (widget.canSkip)
            TextButton(
              onPressed: widget.onDone,
              child: const Text('Skip'),
            )
          else
            TextButton(
              onPressed: () => AuthService.instance.signOut(),
              child: const Text('Sign out', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text('Generating security keys...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.shield,
                                  color: AppTheme.primaryColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Enhance Account Security',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    Text(
                                      'Protect your Caferio account with TOTP',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),

                          const Text(
                            'Step 1: Scan QR Code',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Scan this QR code using Google Authenticator, Microsoft Authenticator, or 1Password.',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),

                          // QR Code Container
                          if (_qrSvg != null)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: SvgPicture.string(
                                  _qrSvg!,
                                  width: 180,
                                  height: 180,
                                ),
                              ),
                            ),

                          // Secret Code Backup
                          if (_secret != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      'Key: $_secret',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    tooltip: 'Copy key',
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: _secret!),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Secret key copied!'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),
                          const Text(
                            'Step 2: Enter 6-digit Code',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Enter the 6-digit security code displayed in your authenticator app.',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              hintText: '000000',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorText: _error,
                            ),
                            onSubmitted: (_) => _verify(),
                          ),

                          const SizedBox(height: 16),

                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isVerifying ? null : _verify,
                            child: _isVerifying
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Verify and Enable 2FA',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// CHALLENGE: Required on login when MFA is enrolled
// -----------------------------------------------------------------------------
class MfaChallengePage extends StatefulWidget {
  const MfaChallengePage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<MfaChallengePage> createState() => _MfaChallengePageState();
}

class _MfaChallengePageState extends State<MfaChallengePage> {
  final TextEditingController _codeController = TextEditingController();

  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final String code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final Factor? factor = await AuthService.instance.getVerifiedTotpFactor();
      if (factor == null) {
        setState(() {
          _error = 'No verified authenticator found for this account';
          _isLoading = false;
        });
        return;
      }

      await AuthService.instance.verifyTotp(factorId: factor.id, code: code);
      widget.onDone();
    } on AuthException catch (error) {
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Verification failed. Try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Two-Factor Verification'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => AuthService.instance.signOut(),
            child: const Text('Sign out', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.security,
                          color: AppTheme.primaryColor,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Enter Security Code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Open your authenticator app and enter the 6-digit code for Caferio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textLight),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        hintText: '000000',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _verify(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _verify,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify Identity',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
