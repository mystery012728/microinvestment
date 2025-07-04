import 'package:flutter/material.dart';
import 'package:microinvestment/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart' as custom_auth;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.green.shade800),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Sign out from your custom auth provider (this will handle Firebase signout internally)
        final authProvider = Provider.of<custom_auth.AuthProvider>(context, listen: false);
        await authProvider.signOut();

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Navigate to login screen and clear navigation stack
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        }
      } catch (e) {
        // Close loading dialog if it's still open
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<custom_auth.AuthProvider>(
        builder: (context, authProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // User Info Section
              if (authProvider.user != null) ...[
                _buildSectionHeader(context, 'Account'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Email'),
                        subtitle: Text(authProvider.user?.email ?? 'No email'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.verified_user),
                        title: const Text('Account Status'),
                        subtitle: Text(
                          authProvider.user?.emailVerified == true
                              ? 'Verified'
                              : 'Not verified',
                        ),
                        trailing: authProvider.user?.emailVerified != true
                            ? TextButton(
                          onPressed: () => _sendEmailVerification(context, authProvider),
                          child: const Text('Verify'),
                        )
                            : const Icon(Icons.check_circle, color: Colors.green),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Security Section
              _buildSectionHeader(context, 'Security'),
              Card(
                child: Column(
                  children: [
                    FutureBuilder<bool>(
                      future: authProvider.checkBiometricSupport(),
                      builder: (context, snapshot) {
                        final isSupported = snapshot.data ?? false;
                        final biometricEnabled = authProvider.biometricEnabled;

                        return ListTile(
                          leading: const Icon(Icons.fingerprint),
                          title: const Text('Biometric Authentication'),
                          subtitle: Text(
                            isSupported
                                ? (biometricEnabled ? 'Enabled' : 'Disabled')
                                : 'Not supported on this device',
                          ),
                          trailing: isSupported
                              ? Switch(
                            value: biometricEnabled,
                            onChanged: authProvider.isLoading
                                ? null
                                : (value) async {
                              if (value) {
                                final success = await authProvider.authenticateWithBiometrics();
                                if (success) {
                                  await authProvider.enableBiometric();
                                }
                              } else {
                                await authProvider.disableBiometric();
                              }
                            },
                          )
                              : null,
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_reset),
                      title: const Text('Change Password'),
                      subtitle: const Text('Update your account password'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showChangePasswordDialog(context, authProvider),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // App Information Section
              _buildSectionHeader(context, 'App Information'),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Version'),
                      subtitle: Text('1.0.0'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showPrivacyPolicy(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.gavel),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showTermsOfService(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Data Section
              _buildSectionHeader(context, 'Data'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_sync),
                      title: const Text('Sync Data'),
                      subtitle: const Text('Last synced: Never'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showSyncDialog(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Clear All Data',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      subtitle: const Text('This action cannot be undone'),
                      onTap: () {
                        _showClearDataDialog(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error Display
              if (authProvider.error != null) ...[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            authProvider.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => authProvider.clearError(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: authProvider.isLoading ? null : () => _logout(context),
                  icon: authProvider.isLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _sendEmailVerification(BuildContext context, custom_auth.AuthProvider authProvider) async {
    try {
      await authProvider.user?.sendEmailVerification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending verification email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                final success = await authProvider.resetPassword(emailController.text.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Password reset email sent!'
                          : 'Failed to send reset email'),
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

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'This is a demo investment tracking app. No real financial data is stored or transmitted. '
                'All data is stored locally on your device and is not shared with third parties.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'This is a demo application for educational purposes only. '
                'Do not use this app for actual investment decisions. '
                'The developers are not responsible for any financial losses.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Data'),
        content: const Text('Data sync is not available in this demo version.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your portfolio data, watchlist, and settings. '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement clear data functionality
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data cleared successfully')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}