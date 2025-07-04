import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:microinvestment/screens/main_screen.dart';
import 'registration_screen.dart';// Add this import

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }

    // Check if username contains only lowercase letters, numbers, and @
    final RegExp regex = RegExp(r'^[a-z0-9@]+$');
    if (!regex.hasMatch(value)) {
      return 'Username can only contain lowercase letters, numbers, and @';
    }

    // Check for spaces
    if (value.contains(' ')) {
      return 'Username cannot contain spaces';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    // Check for uppercase letter
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for lowercase letter
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for number
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    // Check for special character
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Wrong password provided';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This user account has been disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later';
      default:
        return 'Login failed. Please try again';
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Find user by username
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: _usernameController.text.trim())
            .get();

        if (userQuery.docs.isEmpty) {
          throw Exception('Username not found');
        }

        final userDoc = userQuery.docs.first;
        final email = userDoc.data()['email'] as String;

        // Sign in with email and password
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );

        // Navigate to MainScreen on successful login
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MainScreen(),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getAuthErrorMessage(e.code)),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: _validateUsername,
                textInputAction: TextInputAction.next,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: _validatePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegistrationScreen(),
                    ),
                  );
                },
                child: const Text("Don't have an account? Register here"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}