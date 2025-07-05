import 'package:flutter/material.dart';
import 'package:microinvestment/auth/login_screen.dart';
import 'package:microinvestment/auth/registration_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/portfolio_provider.dart';
import 'providers/watchlist_provider.dart';
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
        apiKey: "AIzaSyBRkFfZoxl9GfRF6oJ6oiEL89Tf3w5qfMM",
        appId: "1:241983748173:android:c348b39a142c78d4e1c404",
        messagingSenderId: "241983748173",
        projectId: "microinvestment-7bbb4",
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
        ChangeNotifierProxyProvider<AuthProvider, PortfolioProvider>(
          create: (_) => PortfolioProvider(),
          update: (_, authProvider, portfolioProvider) {
            portfolioProvider?.setUserUid(authProvider.userUid);
            return portfolioProvider!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, WatchlistProvider>(
          create: (_) => WatchlistProvider(),
          update: (_, authProvider, watchlistProvider) {
            watchlistProvider?.setUserUid(authProvider.userUid);
            return watchlistProvider!;
          },
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp(
            title: 'Investment Tracker',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            home: FutureBuilder(
              future: Future.delayed(Duration.zero),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return authProvider.isAuthenticated
                      ? const SplashScreen(child: MainScreen())
                      : const SplashScreen(child: LoginScreen());
                }
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
            routes: {
              '/main': (context) => const MainScreen(),
              '/auth': (context) => const AuthScreen(),
              '/register': (context) => const LoginScreen(),
            },
          );
        },
      ),
    );
  }
}
