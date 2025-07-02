import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';

import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _showBiometricSetup = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final authProvider = context.read<AuthProvider>();
    final isSupported = await authProvider.checkBiometricSupport();
    
    if (isSupported && !authProvider.biometricEnabled) {
      setState(() {
        _showBiometricSetup = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Welcome Text
                  Text(
                    'Welcome to Investment Tracker',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Secure your portfolio with biometric authentication',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Biometric Setup or Authentication
                  if (authProvider.biometricEnabled)
                    _buildAuthenticateButton(authProvider)
                  else if (_showBiometricSetup)
                    _buildBiometricSetup(authProvider)
                  else
                    _buildSkipButton(),

                  // Error Message
                  if (authProvider.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        authProvider.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBiometricSetup(AuthProvider authProvider) {
    return Column(
      children: [
        FutureBuilder<List<BiometricType>>(
          future: authProvider.getAvailableBiometrics(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final biometrics = snapshot.data!;
              String biometricType = 'Biometric';
              
              if (biometrics.contains(BiometricType.face)) {
                biometricType = 'Face ID';
              } else if (biometrics.contains(BiometricType.fingerprint)) {
                biometricType = 'Fingerprint';
              }

              return Column(
                children: [
                  Icon(
                    biometrics.contains(BiometricType.face) 
                        ? Icons.face 
                        : Icons.fingerprint,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enable $biometricType',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure your portfolio with $biometricType authentication',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final success = await authProvider.authenticateWithBiometrics();
                      if (success) {
                        await authProvider.enableBiometric();
                      }
                    },
                    child: Text('Enable $biometricType'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _skipBiometric,
                    child: const Text('Skip for now'),
                  ),
                ],
              );
            }
            return const CircularProgressIndicator();
          },
        ),
      ],
    );
  }

  Widget _buildAuthenticateButton(AuthProvider authProvider) {
    return Column(
      children: [
        Icon(
          Icons.security,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Authentication Required',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Please authenticate to access your portfolio',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => authProvider.authenticateWithBiometrics(),
          icon: const Icon(Icons.fingerprint),
          label: const Text('Authenticate'),
        ),
      ],
    );
  }

  Widget _buildSkipButton() {
    return ElevatedButton(
      onPressed: _skipBiometric,
      child: const Text('Continue without Biometric'),
    );
  }

  void _skipBiometric() {
    final authProvider = context.read<AuthProvider>();
    // Set authenticated to true to skip biometric
    authProvider.clearError();
    // Navigate to main screen by setting authenticated state
    Navigator.of(context).pushReplacementNamed('/main');
  }
}
