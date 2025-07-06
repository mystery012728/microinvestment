import 'package:flutter/material.dart';
import 'package:microinvestment/auth/login_screen.dart';
import 'package:microinvestment/auth/registration_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'providers/portfolio_provider.dart';
import 'providers/watchlist_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'screens/biometric_screen.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
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

  // Initialize notification service
  try {
    await NotificationService().initialize();

    // Set up notification action handler
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: NotificationService.onActionReceivedMethod,
      onNotificationCreatedMethod: (ReceivedNotification receivedNotification) async {
        print('Notification created: ${receivedNotification.title}');
      },
      onNotificationDisplayedMethod: (ReceivedNotification receivedNotification) async {
        print('Notification displayed: ${receivedNotification.title}');
      },
      onDismissActionReceivedMethod: (ReceivedAction receivedAction) async {
        print('Notification dismissed: ${receivedAction.id}');
      },
    );
  } catch (e) {
    print('Notification service initialization error: $e');
  }

  // Initialize background service
  try {
    await BackgroundService.initialize();
  } catch (e) {
    print('Background service initialization error: $e');
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
              future: _initializeApp(authProvider),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  // Determine which screen to show based on auth state
                  Widget targetScreen;

                  if (authProvider.user == null) {
                    // User not signed in with Firebase - show login
                    targetScreen = const LoginScreen();
                  } else if (authProvider.biometricEnabled && !authProvider.isAuthenticated) {
                    // User signed in with Firebase but biometric required - show biometric screen
                    targetScreen = const BiometricScreen();
                  } else if (authProvider.isAuthenticated) {
                    // User fully authenticated - show main screen
                    targetScreen = const MainScreen();
                  } else {
                    // Fallback to login
                    targetScreen = const LoginScreen();
                  }

                  return SplashScreen(child: targetScreen);
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
              '/biometric': (context) => const BiometricScreen(),
            },
          );
        },
      ),
    );
  }

  Future<void> _initializeApp(AuthProvider authProvider) async {
    // Wait for auth state to be determined
    await Future.delayed(Duration.zero);

    // Register background tasks if user is authenticated
    if (authProvider.isAuthenticated) {
      try {
        await BackgroundService.registerPeriodicTasks();
        print('Background tasks registered successfully');
      } catch (e) {
        print('Error registering background tasks: $e');
      }
    }
  }
}
