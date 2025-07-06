import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:math';
import 'api_service.dart';
import 'notification_service.dart';

class BackgroundService {
  static const String _priceCheckTask = 'price_check_task';
  static const String _newsUpdateTask = 'news_update_task';
  static const String _portfolioSummaryTask = 'portfolio_summary_task';

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Set to false in production
    );
  }

  static Future<void> registerPeriodicTasks() async {
    // Register price check task (every 15 minutes)
    await Workmanager().registerPeriodicTask(
      _priceCheckTask,
      _priceCheckTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );

    // Register news update task (every hour)
    await Workmanager().registerPeriodicTask(
      _newsUpdateTask,
      _newsUpdateTask,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );

    // Register daily portfolio summary (once per day at 6 PM)
    await Workmanager().registerPeriodicTask(
      _portfolioSummaryTask,
      _portfolioSummaryTask,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }

  static Future<void> cancelTask(String taskName) async {
    await Workmanager().cancelByUniqueName(taskName);
  }
}

// This is the callback dispatcher that runs in the background
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case BackgroundService._priceCheckTask:
          await _performPriceCheck();
          break;
        case BackgroundService._newsUpdateTask:
          await _performNewsUpdate();
          break;
        case BackgroundService._portfolioSummaryTask:
          await _performPortfolioSummary();
          break;
      }
      return Future.value(true);
    } catch (e) {
      print('Background task error: $e');
      return Future.value(false);
    }
  });
}

Future<void> _performPriceCheck() async {
  try {
    print('Performing background price check...');

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Get all users' watchlist and portfolio data from Firestore
    await _checkWatchlistAlerts(notificationService);
    await _checkPortfolioUpdates(notificationService);

    print('Price check completed successfully');
  } catch (e) {
    print('Error in price check: $e');
  }
}

Future<void> _checkWatchlistAlerts(NotificationService notificationService) async {
  try {
    // Get all watchlist items with alerts enabled
    final watchlistSnapshot = await FirebaseFirestore.instance
        .collection('watchlist')
        .where('alertEnabled', isEqualTo: true)
        .get();

    for (final doc in watchlistSnapshot.docs) {
      final data = doc.data();
      final symbol = data['symbol'] as String;
      final alertPrice = (data['alertPrice'] as num).toDouble();
      final lastPrice = (data['currentPrice'] as num).toDouble();

      // Get current price from API
      final currentPrice = await ApiService.getAssetPrice(symbol);

      // Check if alert should be triggered
      bool shouldAlert = false;
      bool isAbove = false;

      if (alertPrice > lastPrice && currentPrice >= alertPrice) {
        // Price crossed above alert price
        shouldAlert = true;
        isAbove = true;
      } else if (alertPrice < lastPrice && currentPrice <= alertPrice) {
        // Price crossed below alert price
        shouldAlert = true;
        isAbove = false;
      }

      if (shouldAlert) {
        await notificationService.showPriceAlert(
          symbol: symbol,
          currentPrice: currentPrice,
          alertPrice: alertPrice,
          isAbove: isAbove,
        );

        // Update the price in Firestore
        await doc.reference.update({
          'currentPrice': currentPrice,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  } catch (e) {
    print('Error checking watchlist alerts: $e');
  }
}

Future<void> _checkPortfolioUpdates(NotificationService notificationService) async {
  try {
    // Get all portfolio items
    final portfolioSnapshot = await FirebaseFirestore.instance
        .collection('portfolios')
        .get();

    for (final doc in portfolioSnapshot.docs) {
      final data = doc.data();
      final symbol = data['symbol'] as String;
      final quantity = (data['quantity'] as num).toDouble();
      final lastPrice = (data['currentPrice'] as num).toDouble();

      // Get current price from API
      final currentPrice = await ApiService.getAssetPrice(symbol);

      // Calculate value change
      final previousValue = quantity * lastPrice;
      final currentValue = quantity * currentPrice;
      final changePercent = ((currentPrice - lastPrice) / lastPrice) * 100;

      // Only notify if change is significant (more than 5%)
      if (changePercent.abs() >= 5.0) {
        await notificationService.showPortfolioUpdate(
          symbol: symbol,
          currentValue: currentValue,
          previousValue: previousValue,
          changePercent: changePercent,
        );

        // Update the price in Firestore
        await doc.reference.update({
          'currentPrice': currentPrice,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  } catch (e) {
    print('Error checking portfolio updates: $e');
  }
}

Future<void> _performNewsUpdate() async {
  try {
    print('Performing background news update...');

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Get latest financial news
    final news = await ApiService.getFinancialNews();

    if (news.isNotEmpty) {
      // Get the most recent news item
      final latestNews = news.first;

      // Check if we've already notified about this news
      final prefs = await SharedPreferences.getInstance();
      final lastNewsId = prefs.getString('last_news_id');

      if (lastNewsId != latestNews.id) {
        await notificationService.showNewsUpdate(
          title: latestNews.title,
          summary: latestNews.description,
          url: latestNews.url,
        );

        // Save the news ID to avoid duplicate notifications
        await prefs.setString('last_news_id', latestNews.id);
      }
    }

    print('News update completed successfully');
  } catch (e) {
    print('Error in news update: $e');
  }
}

Future<void> _performPortfolioSummary() async {
  try {
    print('Performing daily portfolio summary...');

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Get all users' portfolio data and calculate daily summary
    final portfolioSnapshot = await FirebaseFirestore.instance
        .collection('portfolios')
        .get();

    // Group by user
    final Map<String, List<Map<String, dynamic>>> userPortfolios = {};

    for (final doc in portfolioSnapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String;

      if (!userPortfolios.containsKey(userId)) {
        userPortfolios[userId] = [];
      }
      userPortfolios[userId]!.add(data);
    }

    // Calculate summary for each user
    for (final entry in userPortfolios.entries) {
      double totalValue = 0;
      double totalInvested = 0;

      for (final portfolio in entry.value) {
        final quantity = (portfolio['quantity'] as num).toDouble();
        final currentPrice = (portfolio['currentPrice'] as num).toDouble();
        final totalInvestedAmount = (portfolio['totalInvested'] as num).toDouble();

        totalValue += quantity * currentPrice;
        totalInvested += totalInvestedAmount;
      }

      final dayChange = totalValue - totalInvested;
      final dayChangePercent = totalInvested > 0 ? (dayChange / totalInvested) * 100 : 0.0;

      // Only send summary if there's significant change or it's been a day
      await notificationService.showDailyPortfolioSummary(
        totalValue: totalValue,
        dayChange: dayChange,
        dayChangePercent: dayChangePercent,
      );
    }

    print('Portfolio summary completed successfully');
  } catch (e) {
    print('Error in portfolio summary: $e');
  }
}
