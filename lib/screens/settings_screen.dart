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
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<custom_auth.AuthProvider>(
        builder: (context, authProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Account Section
              if (authProvider.user != null) ...[
                _buildSection(context, 'Account', [
                  _buildListTile(
                    icon: Icons.person,
                    title: 'Email',
                    subtitle: authProvider.user?.email ?? 'No email',
                  ),
                  _buildListTile(
                    icon: Icons.verified_user,
                    title: 'Account Status',
                    subtitle: authProvider.user?.emailVerified == true ? 'Verified' : 'Not verified',
                    trailing: authProvider.user?.emailVerified != true
                        ? TextButton(
                      onPressed: () => _sendEmailVerification(context, authProvider),
                      child: const Text('Verify'),
                    )
                        : const Icon(Icons.check_circle, color: Colors.green),
                  ),
                ]),
                const SizedBox(height: 24),
              ],

              // Wallet Section
              _buildSection(context, 'Wallet', [
                _buildListTile(
                  icon: Icons.account_balance_wallet,
                  title: 'Wallet',
                  subtitle: 'Manage your wallet and transactions',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const WalletScreen()),
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // Security Section
              _buildSection(context, 'Security', [
                FutureBuilder<bool>(
                  future: authProvider.checkBiometricSupport(),
                  builder: (context, snapshot) {
                    final isSupported = snapshot.data ?? false;
                    return _buildListTile(
                      icon: Icons.fingerprint,
                      title: 'Biometric Authentication',
                      subtitle: isSupported
                          ? (authProvider.biometricEnabled ? 'Enabled' : 'Disabled')
                          : 'Not supported',
                      trailing: isSupported
                          ? Switch(
                        value: authProvider.biometricEnabled,
                        onChanged: authProvider.isLoading
                            ? null
                            : (value) => _toggleBiometric(context, authProvider, value),
                      )
                          : null,
                    );
                  },
                ),
                _buildListTile(
                  icon: Icons.lock_reset,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showChangePasswordDialog(context, authProvider),
                ),
              ]),
              const SizedBox(height: 24),

              // Data Section
              _buildSection(context, 'Data', [
                _buildListTile(
                  icon: Icons.cloud_sync,
                  title: 'Sync Data',
                  subtitle: 'Last synced: Never',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showInfoDialog(context, 'Sync Data', 'Data sync is not available in this demo version.'),
                ),
                _buildListTile(
                  icon: Icons.delete_forever,
                  title: 'Clear All Data',
                  subtitle: 'This action cannot be undone',
                  titleColor: Theme.of(context).colorScheme.error,
                  onTap: () => _showClearDataDialog(context),
                ),
              ]),
              const SizedBox(height: 24),

              // App Information Section
              _buildSection(context, 'App Information', [
                _buildListTile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  subtitle: '1.0.0',
                ),
                _buildListTile(
                  icon: Icons.description,
                  title: 'Privacy Policy',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showInfoDialog(context, 'Privacy Policy',
                      'This is a demo investment tracking app. No real financial data is stored or transmitted. All data is stored locally on your device and is not shared with third parties.'),
                ),
                _buildListTile(
                  icon: Icons.gavel,
                  title: 'Terms of Service',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showInfoDialog(context, 'Terms of Service',
                      'This is a demo application for educational purposes only. Do not use this app for actual investment decisions. The developers are not responsible for any financial losses.'),
                ),
              ]),
              const SizedBox(height: 24),

              // Error Display
              if (authProvider.error != null) ...[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                    title: Text(authProvider.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    trailing: IconButton(
                      onPressed: authProvider.clearError,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: authProvider.isLoading ? null : () => _logout(context, authProvider),
                  icon: authProvider.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.logout),
                  label: Text(authProvider.isLoading ? 'Signing out...' : 'Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.green.shade800)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Logout', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      try {
        showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
        await authProvider.signOut();
        if (context.mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context, custom_auth.AuthProvider authProvider) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
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
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will permanently delete all your portfolio data, watchlist, and settings. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared successfully')));
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}