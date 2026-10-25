import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/theme.dart';
import 'auth_service.dart';
import 'jwt_helper.dart';
import 'mfa_pages.dart';

class ProfileSecurityCard extends StatefulWidget {
  const ProfileSecurityCard({super.key});

  @override
  State<ProfileSecurityCard> createState() => _ProfileSecurityCardState();
}

class _ProfileSecurityCardState extends State<ProfileSecurityCard> {
  Factor? _totpFactor;
  bool _isLoadingFactor = true;

  @override
  void initState() {
    super.initState();
    _loadMfaStatus();
  }

  Future<void> _loadMfaStatus() async {
    try {
      final factor = await AuthService.instance.getVerifiedTotpFactor();
      if (mounted) {
        setState(() {
          _totpFactor = factor;
          _isLoadingFactor = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingFactor = false);
      }
    }
  }

  void _showJwtClaimsDialog(BuildContext context, JwtClaims? claims) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.token_outlined, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Text('JWT Session Claims', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildClaimRow('Username', AuthService.instance.currentUsername ?? 'N/A'),
                _buildClaimRow('User ID (sub)', claims?.subject ?? 'N/A'),
                _buildClaimRow('Role', claims?.role ?? 'authenticated'),
                _buildClaimRow(
                  'Assurance (aal)',
                  claims?.aal?.toUpperCase() ?? 'AAL1',
                ),
                _buildClaimRow('Issued At', claims?.issuedAt?.toString() ?? 'N/A'),
                _buildClaimRow('Expires At', claims?.expiresAt?.toString() ?? 'N/A'),
                _buildClaimRow('Time Remaining', claims?.formattedExpiry ?? 'N/A'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '🔒 Cryptographically signed JWT issued by Supabase Auth with PKCE verification.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClaimRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }

  void _openChangePasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool saving = false;
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your new password.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                        ),
                      ),
                      validator: AuthService.validatePassword,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => saving = true);
                          try {
                            await AuthService.instance.updatePassword(
                              passwordController.text,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } on AuthException catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.message),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openMfaEnroll() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MfaEnrollPage(
          canSkip: true,
          onDone: () {
            Navigator.pop(context);
            _loadMfaStatus();
          },
        ),
      ),
    );
  }

  void _confirmSignOut({required bool allDevices}) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(allDevices ? 'Sign Out Everywhere' : 'Sign Out'),
          content: Text(
            allDevices
                ? 'This will terminate your session across all devices and browsers.'
                : 'Are you sure you want to sign out from Caferio?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await AuthService.instance.signOut(allDevices: allDevices);
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteAccount() {
    final username = AuthService.instance.currentUsername ?? 'User';
    bool deleting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 10),
                  Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to permanently delete @$username?',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This action is irreversible. All your profile information, preferences, session tokens, and account history will be permanently deleted.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: deleting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: deleting
                      ? null
                      : () async {
                          setDialogState(() => deleting = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            Navigator.pop(ctx);
                            await AuthService.instance.deleteAccount();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                    SizedBox(width: 10),
                                    Text('Account deleted permanently.'),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete account: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGuestCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_circle_outlined,
                    color: Colors.black54,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guest Mode',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Browsing Caferio as a Guest',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'GUEST',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            const Text(
              'You are exploring Caferio in guest mode. Sign in with your username or create an account to unlock full security, order tracking, and favourites sync.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.login, size: 18),
                label: const Text(
                  'Log In / Sign Up',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () {
                  AuthService.instance.exitGuestMode();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isAuthenticated || AuthService.instance.isGuest) {
      return _buildGuestCard(context);
    }

    final claims = AuthService.instance.currentClaims;
    final bool has2fa = _totpFactor != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security & Authentication',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Supabase JWT & PKCE Session',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Active badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        claims?.aal?.toUpperCase() ?? 'AAL1',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Token Info Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'JWT Token Expiry',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      claims?.formattedExpiry ?? 'Active Session',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Inspect Claims', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showJwtClaimsDialog(context, claims),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Two-Factor Authentication Tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                has2fa ? Icons.lock : Icons.lock_open,
                color: has2fa ? Colors.green : Colors.grey,
              ),
              title: const Text(
                'Two-Factor Auth (2FA)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _isLoadingFactor
                    ? 'Checking 2FA status...'
                    : has2fa
                        ? 'TOTP Authenticator active'
                        : 'Optional — add extra layer of security',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: has2fa
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: () async {
                        if (_totpFactor != null) {
                          await AuthService.instance.removeTotp(_totpFactor!.id);
                          _loadMfaStatus();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('2FA disabled')),
                            );
                          }
                        }
                      },
                      child: const Text('Disable', style: TextStyle(fontSize: 12)),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: _openMfaEnroll,
                      child: const Text('Enable', style: TextStyle(fontSize: 12)),
                    ),
            ),

            // Change Password Tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.password, color: AppTheme.primaryColor),
              title: const Text(
                'Change Password',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Update your account password',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: _openChangePasswordDialog,
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Sign out buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign Out'),
                    onPressed: () => _confirmSignOut(allDevices: false),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Sign Out All Devices',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.devices, color: Colors.black54),
                  onPressed: () => _confirmSignOut(allDevices: true),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Danger Zone: Delete Account
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          'Permanently remove account & data',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade800,
                      side: BorderSide(color: Colors.red.shade400),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _confirmDeleteAccount,
                    child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
