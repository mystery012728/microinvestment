import 'package:flutter/material.dart';
import 'package:microinvestment/auth/login_screen.dart';
import 'package:microinvestment/screens/wallet_screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
                    StreamBuilder<DocumentSnapshot>(
                      stream: _getBiometricStream(authProvider.user?.uid),
                      builder: (context, snapshot) {
                        final biometricEnabled = snapshot.data?.data() as Map<String, dynamic>?;
                        final isEnabled = biometricEnabled?['biometricEnabled'] ?? false;

                        return FutureBuilder<bool>(
                          future: authProvider.checkBiometricSupport(),
                          builder: (context, biometricSnapshot) {
                            final isSupported = biometricSnapshot.data ?? false;
                            return _buildTile(
                              context,
                              Icons.fingerprint_rounded,
                              'Biometric Authentication',
                              isSupported ? (isEnabled ? 'Enabled' : 'Disabled') : 'Not supported',
                              trailing: isSupported
                                  ? Switch.adaptive(
                                value: isEnabled,
                                onChanged: authProvider.isLoading
                                    ? null
                                    : (value) => _toggleBiometric(context, authProvider, value),
                              )
                                  : null,
                            );
                          },
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
                  _buildSection(context, 'App Information', [
                    _buildTile(context, Icons.info_outline_rounded, 'Version', '1.0.0'),
                    _buildTile(context, Icons.description_rounded, 'Privacy Policy', 'View our privacy policy',
                        onTap: () => _showInfoDialog(context, 'Privacy Policy', 'This is a demo investment tracking app.')),
                    _buildTile(context, Icons.gavel_rounded, 'Terms of Service', 'View terms and conditions',
                        onTap: () => _showInfoDialog(context, 'Terms of Service', 'This is a demo application for educational purposes only.')),
                  ]),
                  const SizedBox(height: 32),
                  if (authProvider.error != null) _buildErrorContainer(context, authProvider),
                  _buildLogoutButton(context, authProvider),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Stream<DocumentSnapshot> _getBiometricStream(String? uid) {
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
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

  Widget _buildTile(BuildContext context, IconData icon, String title, String subtitle,
      {Widget? trailing, VoidCallback? onTap, Color? titleColor}) =>
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

  Widget _buildErrorContainer(BuildContext context, custom_auth.AuthProvider authProvider) => Column(
    children: [
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
            Expanded(child: Text(authProvider.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            IconButton(onPressed: authProvider.clearError, icon: const Icon(Icons.close_rounded)),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget _buildLogoutButton(BuildContext context, custom_auth.AuthProvider authProvider) => SizedBox(
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
  );

  Future<void> _toggleBiometric(BuildContext context, custom_auth.AuthProvider authProvider, bool value) async {
    try {
      if (value) {
        final success = await authProvider.authenticateWithBiometrics();
        if (success) {
          await _saveBiometricStatus(authProvider.user?.uid, true);
          await authProvider.enableBiometric();
          if (context.mounted) _showSnackBar(context, 'Biometric authentication enabled', Colors.green);
        }
      } else {
        await _saveBiometricStatus(authProvider.user?.uid, false);
        await authProvider.disableBiometric();
        if (context.mounted) _showSnackBar(context, 'Biometric authentication disabled', Colors.orange);
      }
    } catch (e) {
      if (context.mounted) _showSnackBar(context, 'Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _saveBiometricStatus(String? uid, bool enabled) async {
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'biometricEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _sendEmailVerification(BuildContext context, custom_auth.AuthProvider authProvider) async {
    try {
      await authProvider.user?.sendEmailVerification();
      if (context.mounted) _showSnackBar(context, 'Verification email sent. Please check your inbox.', Colors.green);
    } catch (e) {
      if (context.mounted) _showSnackBar(context, 'Error sending verification email: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _logout(BuildContext context, custom_auth.AuthProvider authProvider) async {
    final confirmLogout = await _showLogoutDialog(context);
    if (confirmLogout == true) {
      await _handleBiometricLogout(context, authProvider);
    }
  }

  Future<bool?> _showLogoutDialog(BuildContext context) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Confirm Logout'),
      content: const Text('You will need to authenticate with biometrics to confirm this action.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Logout'),
        ),
      ],
    ),
  );

  Future<void> _handleBiometricLogout(BuildContext context, custom_auth.AuthProvider authProvider) async {
    try {
      final biometricResult = await _showBiometricDialog(context, authProvider);
      if (biometricResult == true) {
        await authProvider.signOut();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, _) => const LoginScreen(),
              transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
            ),
                (route) => false,
          );
        }
      }
    } catch (e) {
      if (context.mounted) _showSnackBar(context, 'Error during logout: ${e.toString()}', Colors.red);
    }
  }

  Future<bool?> _showBiometricDialog(BuildContext context, custom_auth.AuthProvider authProvider) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        bool isAuthenticating = false;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Biometric Authentication'),
          content: const Text('Please authenticate to confirm logout'),
          actions: isAuthenticating
              ? [const CircularProgressIndicator()]
              : [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () async {
                setState(() => isAuthenticating = true);
                final success = await authProvider.authenticateWithBiometrics();
                if (context.mounted) {
                  if (success) {
                    Navigator.pop(context, true);
                  } else {
                    setState(() => isAuthenticating = false);
                    _showSnackBar(context, authProvider.error ?? 'Authentication failed', Colors.red);
                  }
                }
              },
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Authenticate'),
            ),
          ],
        );
      },
    ),
  );

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
                  _showSnackBar(context, success ? 'Password reset email sent!' : 'Failed to send reset email',
                      success ? Colors.green : Colors.red);
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: SingleChildScrollView(child: Text(content)),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}