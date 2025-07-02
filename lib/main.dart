import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/portfolio_provider.dart';
import 'providers/watchlist_provider.dart';
import 'providers/news_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBoEfynFgftXEWeTKigDaWS0FK1Zczk1rY",
        appId: "1:935307424826:android:6ba63ec26bea64438e3103",
        messagingSenderId: "935307424826",
        projectId: "wastewisepro",
      ),
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        ChangeNotifierProvider(create: (_) => WatchlistProvider()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp(
            title: 'Investment Tracker',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            home: _getHomeScreen(authProvider),
            routes: {
              '/main': (context) => const MainScreen(),
              '/auth': (context) => const AuthScreen(),
            },
          );
        },
      ),
    );
  }

  Widget _getHomeScreen(AuthProvider authProvider) {
    // Always show splash screen first, then check auth state
    return FutureBuilder(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (!authProvider.isAuthenticated) {
          return const AuthScreen();
        }

        return const MainScreen();
      },
    );
  }

  Future<void> _initializeApp() async {
    // Add a small delay to show splash screen
    await Future.delayed(const Duration(seconds: 2));
  }
}