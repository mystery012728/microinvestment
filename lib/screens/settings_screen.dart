import 'package:flutter/material.dart';
import 'package:microinvestment/auth/login_screen.dart';
import 'package:microinvestment/screens/wallet_screen.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart' as custom_auth;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: Consumer<custom_auth.AuthProvider>(
              builder: (context, authProvider, child) => SliverList(
                delegate: SliverChildListDelegate([
                  if (authProvider.user != null) ...[
                    _buildSection(context, 'Account', [
                      _buildTile(context, Icons.person_rounded, 'Email', authProvider.user?.email ?? 'No email'),
                      _buildTile(
                        context,
                        Icons.verified_user_rounded,
                        'Account Status',
                        authProvider.user?.emailVerified == true ? 'Verified' : 'Not verified',
                        trailing: authProvider.user?.emailVerified != true
                            ? _buildButton(context, 'Verify', () => _sendEmailVerification(context, authProvider))
                            : const Icon(Icons.check_circle_rounded, color: Colors.green),
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],
                  _buildSection(context, 'Wallet', [
                    _buildTile(
                      context,
                      Icons.account_balance_wallet_rounded,
                      'Wallet',
                      'Manage your wallet and transactions',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection(context, 'Security', [
                    FutureBuilder<bool>(
                      future: authProvider.checkBiometricSupport(),
                      builder: (context, snapshot) {
                        final isSupported = snapshot.data ?? false;
                        return _buildTile(
                          context,
                          Icons.fingerprint_rounded,
                          'Biometric Authentication',
                          isSupported
                              ? (authProvider.biometricEnabled ? 'Enabled' : 'Disabled')
                              : 'Not supported',
                          trailing: isSupported
                              ? Switch.adaptive(
                            value: authProvider.biometricEnabled,
                            onChanged: authProvider.isLoading
                                ? null
                                : (value) => _toggleBiometric(context, authProvider, value),
                          )
                              : null,
                        );
                      },
                    ),
                    _buildTile(
                      context,
                      Icons.lock_reset_rounded,
                      'Change Password',
                      'Update your account password',
                      onTap: () => _showChangePasswordDialog(context, authProvider),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection(context, 'Data', [
                    _buildTile(
                      context,
                      Icons.cloud_sync_rounded,
                      'Sync Data',
                      'Last synced: Never',
                      onTap: () => _showInfoDialog(context, 'Sync Data', 'Data sync is not available in this demo version.'),
                    ),
                    _buildTile(
                      context,
                      Icons.delete_forever_rounded,
                      'Clear All Data',
                      'This action cannot be undone',
                      titleColor: Theme.of(context).colorScheme.error,
                      onTap: () => _showClearDataDialog(context),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection(context, 'App Information', [
                    _buildTile(context, Icons.info_outline_rounded, 'Version', '1.0.0'),
                    _buildTile(
                      context,
                      Icons.description_rounded,
                      'Privacy Policy',
                      'View our privacy policy',
                      onTap: () => _showInfoDialog(context, 'Privacy Policy',
                          'This is a demo investment tracking app. No real financial data is stored or transmitted.'),
                    ),
                    _buildTile(
                      context,
                      Icons.gavel_rounded,
                      'Terms of Service',
                      'View terms and conditions',
                      onTap: () => _showInfoDialog(context, 'Terms of Service',
                          'This is a demo application for educational purposes only.'),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  if (authProvider.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(authProvider.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ),
                          IconButton(onPressed: authProvider.clearError, icon: const Icon(Icons.close_rounded)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: authProvider.isLoading ? null : () => _logout(context, authProvider),
                      icon: authProvider.isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.logout_rounded),
                      label: Text(authProvider.isLoading ? 'Signing out...' : 'Sign Out'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
        ),
        child: Column(children: children),
      ),
    ],
  );

  Widget _buildTile(
      BuildContext context,
      IconData icon,
      String title,
      String subtitle, {
        Widget? trailing,
        VoidCallback? onTap,
        Color? titleColor,
      }) =>
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (titleColor ?? Theme.of(context).colorScheme.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: titleColor ?? Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.arrow_forward_ios_rounded, size: 16) : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _buildButton(BuildContext context, String text, VoidCallback onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Future<void> _toggleBiometric(BuildContext context, custom_auth.AuthProvider authProvider, bool value) async {
    try {
      if (value) {
        final success = await authProvider.authenticateWithBiometrics();
        if (success) {
          await authProvider.enableBiometric();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometric authentication enabled'), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        await authProvider.disableBiometric();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication disabled'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendEmailVerification(BuildContext context, custom_auth.AuthProvider authProvider) async {
    try {
      await authProvider.user?.sendEmailVerification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please check your inbox.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending verification email: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context, custom_auth.AuthProvider authProvider) async {
    final confirmLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildLogoutDialog(context),
    );

    if (confirmLogout == true) {
      await _handleBiometricLogout(context, authProvider);
    }
  }

  Widget _buildLogoutDialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.logout_rounded,
                size: 32,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Confirm Logout',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You will need to authenticate with biometrics to confirm this action.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBiometricLogout(BuildContext context, custom_auth.AuthProvider authProvider) async {
    try {
      // Show biometric authentication dialog
      final biometricResult = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildBiometricDialog(context, authProvider),
      );

      if (biometricResult == true) {
        // Perform logout
        await authProvider.signOut();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, _) => const LoginScreen(),
              transitionsBuilder: (context, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
                (route) => false,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBiometricDialog(BuildContext context, custom_auth.AuthProvider authProvider) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isAuthenticating = false;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Biometric Authentication',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please authenticate to confirm logout',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (isAuthenticating)
                  const CircularProgressIndicator()
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            setState(() => isAuthenticating = true);

                            final success = await authProvider.authenticateWithBiometrics();

                            if (context.mounted) {
                              if (success) {
                                Navigator.pop(context, true);
                              } else {
                                setState(() => isAuthenticating = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(authProvider.error ?? 'Authentication failed'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Authenticate'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context, custom_auth.AuthProvider authProvider) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email to receive a password reset link:'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (emailController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                final success = await authProvider.resetPassword(emailController.text.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Password reset email sent!' : 'Failed to send reset email'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Data'),
        content: const Text('This will permanently delete all your portfolio data, watchlist, and settings. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared successfully')));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
