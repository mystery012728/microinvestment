import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Security Section
              _buildSectionHeader(context, 'Security'),
              Card(
                child: Column(
                  children: [
                    FutureBuilder<bool>(
                      future: authProvider.checkBiometricSupport(),
                      builder: (context, snapshot) {
                        final isSupported = snapshot.data ?? false;
                        return ListTile(
                          leading: const Icon(Icons.fingerprint),
                          title: const Text('Biometric Authentication'),
                          subtitle: Text(
                            isSupported 
                                ? (authProvider.biometricEnabled ? 'Enabled' : 'Disabled')
                                : 'Not supported on this device',
                          ),
                          trailing: isSupported
                              ? Switch(
                                  value: authProvider.biometricEnabled,
                                  onChanged: (value) async {
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

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showSignOutDialog(context, authProvider);
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
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

  void _showSignOutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              authProvider.signOut();
              Navigator.of(context).pop();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
