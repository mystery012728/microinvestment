import 'package:flutter/material.dart';
import 'package:microinvestment/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/portfolio_provider.dart';
import 'providers/watchlist_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'screens/biometric_screen.dart';
import 'utils/theme.dart';

// Finnhub API keys for rotation
const List<String> finnhubApiKeys = [
  'd1lag6pr01qt4thevlugd1lag6pr01qt4thevlv0',
  'd1j0r5pr01qhbuvspkpgd1j0r5pr01qhbuvspkq0',
  'd1lah59r01qt4thevrh0d1lah59r01qt4thevrhg',
];

// WorkManager callback - must be top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Background task started: $task');

    try {
      switch (task) {
        case 'newsNotificationTask':
          await _sendNewsNotification();
          break;
        case 'priceAlertTask':
          await _checkPriceAlerts();
          break;
        default:
          print('Unknown task: $task');
      }
    } catch (e) {
      print('Error in background task $task: $e');
    }

    return Future.value(true);
  });
}

// Get API key with rotation
Future<String> _getApiKey() async {
  final prefs = await SharedPreferences.getInstance();
  final currentIndex = prefs.getInt('api_key_index') ?? 0;
  final nextIndex = (currentIndex + 1) % finnhubApiKeys.length;
  await prefs.setInt('api_key_index', nextIndex);
  return finnhubApiKeys[currentIndex];
}

// News notification function - must be top-level
Future<void> _sendNewsNotification() async {
  const String newsApiKey = '86cf54b70f4341219a3ee9a7779ae2dd';

  try {
    final response = await http.get(
      Uri.parse('https://newsapi.org/v2/top-headlines?country=us&category=business&pageSize=1&apiKey=$newsApiKey'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final articles = data['articles'] as List;

      if (articles.isNotEmpty) {
        final article = articles.first;
        final title = article['title'] ?? '';
        final imageUrl = article['urlToImage'] ?? '';
        final url = article['url'] ?? '';

        if (title.isNotEmpty) {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              channelKey: 'news_channel',
              title: '📰 Latest News',
              body: title,
              bigPicture: imageUrl.isNotEmpty ? imageUrl : null,
              notificationLayout: imageUrl.isNotEmpty
                  ? NotificationLayout.BigPicture
                  : NotificationLayout.Default,
              payload: {'url': url},
            ),
          );
          print('News notification sent: $title');
        }
      }
    }
  } catch (e) {
    print('Error sending news notification: $e');
  }
}

// Price alert checking function - must be top-level
Future<void> _checkPriceAlerts() async {
  try {
    // Get all watchlist items with alerts enabled
    final watchlistQuery = await FirebaseFirestore.instance
        .collection('watchlist')
        .where('alertEnabled', isEqualTo: true)
        .get();

    if (watchlistQuery.docs.isEmpty) {
      print('No active price alerts found');
      return;
    }

    final apiKey = await _getApiKey();
    print('Using API key: ${apiKey.substring(0, 10)}...');

    // Process each watchlist item
    for (final doc in watchlistQuery.docs) {
      final data = doc.data();
      final symbol = data['symbol'] as String;
      final alertPrice = (data['alertPrice'] as num).toDouble();
      final lastAlertTriggered = data['lastAlertTriggered'] as bool? ?? false;
      final lastAlertTime = data['lastAlertTime'] as Timestamp?;

      // Skip if alert was triggered recently (within last hour)
      if (lastAlertTriggered && lastAlertTime != null) {
        final timeSinceLastAlert = DateTime.now().difference(lastAlertTime.toDate());
        if (timeSinceLastAlert.inHours < 1) {
          continue;
        }
      }

      try {
        // Get current price from Finnhub
        final currentPrice = await _getCurrentPrice(symbol, apiKey);

        if (currentPrice > 0) {
          // Update current price in Firestore
          await FirebaseFirestore.instance
              .collection('watchlist')
              .doc(doc.id)
              .update({
            'currentPrice': currentPrice,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Check if alert should be triggered
          bool shouldAlert = false;
          String alertMessage = '';

          if (alertPrice > 0) {
            if (currentPrice >= alertPrice && !lastAlertTriggered) {
              shouldAlert = true;
              alertMessage = '$symbol has reached your target price of \$${alertPrice.toStringAsFixed(2)}! Current: \$${currentPrice.toStringAsFixed(2)}';
            } else if (currentPrice < alertPrice && lastAlertTriggered) {
              // Reset alert if price drops below target
              await FirebaseFirestore.instance
                  .collection('watchlist')
                  .doc(doc.id)
                  .update({
                'lastAlertTriggered': false,
                'lastAlertTime': null,
              });
            }
          }

          if (shouldAlert) {
            await _sendPriceAlert(symbol, alertMessage);

            // Mark alert as triggered
            await FirebaseFirestore.instance
                .collection('watchlist')
                .doc(doc.id)
                .update({
              'lastAlertTriggered': true,
              'lastAlertTime': FieldValue.serverTimestamp(),
              'alertTriggeredAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        print('Error checking price for $symbol: $e');
        continue;
      }

      // Small delay between API calls to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 200));
    }
  } catch (e) {
    print('Error in price alert checking: $e');
  }
}

// Get current price from Finnhub API
Future<double> _getCurrentPrice(String symbol, String apiKey) async {
  try {
    final response = await http.get(
      Uri.parse('https://finnhub.io/api/v1/quote?symbol=$symbol&token=$apiKey'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final currentPrice = data['c'] as num?; // 'c' is current price
      return currentPrice?.toDouble() ?? 0.0;
    } else {
      print('API Error for $symbol: ${response.statusCode}');
      return 0.0;
    }
  } catch (e) {
    print('Error fetching price for $symbol: $e');
    return 0.0;
  }
}

// Send price alert notification
Future<void> _sendPriceAlert(String symbol, String message) async {
  try {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'price_alert_channel',
        title: '💰 Price Alert: $symbol',
        body: message,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        fullScreenIntent: true,
        criticalAlert: true,
        payload: {'symbol': symbol, 'type': 'price_alert'},
      ),
    );
    print('Price alert sent for $symbol: $message');
  } catch (e) {
    print('Error sending price alert: $e');
  }
}

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
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // Initialize notifications and WorkManager
  await _initializeNotifications();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

Future<void> _initializeNotifications() async {
  try {
    // Initialize WorkManager
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    print('WorkManager initialized');

    // Initialize Awesome Notifications
    await AwesomeNotifications().initialize(
      'resource://drawable/app_icon',
      [
        NotificationChannel(
          channelKey: 'news_channel',
          channelName: 'News Notifications',
          channelDescription: 'Latest financial news updates',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
        ),
        NotificationChannel(
          channelKey: 'price_alert_channel',
          channelName: 'Price Alerts',
          channelDescription: 'Stock price alerts and notifications',
          defaultColor: Colors.green,
          ledColor: Colors.green,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      ],
    );

    // Request notification permissions
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    // Schedule periodic news notifications (every 1 hour)
    await Workmanager().registerPeriodicTask(
      'newsNotificationTask',
      'newsNotificationTask',
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );

    // Listen for notification actions
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );

    print('Notifications and WorkManager initialized successfully');
  } catch (e) {
    print('Error initializing notifications: $e');
  }
}

// Notification action listeners
@pragma('vm:entry-point')
Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
  print('Notification action received: ${receivedAction.actionType}');

  if (receivedAction.payload != null) {
    final payload = receivedAction.payload!;
    if (payload['type'] == 'price_alert') {
      print('Price alert action for symbol: ${payload['symbol']}');
      // Handle price alert action (e.g., navigate to stock details)
    }
  }
}

@pragma('vm:entry-point')
Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
  print('Notification created: ${receivedNotification.title}');
}

@pragma('vm:entry-point')
Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
  print('Notification displayed: ${receivedNotification.title}');
}

@pragma('vm:entry-point')
Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
  print('Notification dismissed: ${receivedAction.title}');
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
  }
}