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
      isInDebugMode: false, // Disabled debug mode to prevent unwanted notifications
    );
  }

  static Future<void> registerPeriodicTasks() async {
    // Register price check task (every 5 minutes for better alert responsiveness)
    await Workmanager().registerPeriodicTask(
      _priceCheckTask,
      _priceCheckTask,
      frequency: const Duration(minutes: 5),
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

    // Register daily portfolio summary (once per day)
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
      // Silent execution - no debug prints or notifications
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
      // Silent error handling - no debug prints
      return Future.value(false);
    }
  });
}

Future<void> _performPriceCheck() async {
  try {
    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Get all users' watchlist and portfolio data from Firestore
    await _checkWatchlistAlerts(notificationService);
    await _checkPortfolioUpdates(notificationService);

    // Silent completion - no debug prints
  } catch (e) {
    // Silent error handling
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
      final lastKnownPrice = (data['currentPrice'] as num).toDouble();
      final lastAlertTriggered = data['lastAlertTriggered'] as bool? ?? false;

      // Get current price from API
      final currentPrice = await ApiService.getAssetPrice(symbol);

      // Determine alert direction and check if threshold is crossed
      bool shouldTriggerAlert = false;
      String alertType = '';
      String alertMessage = '';

      // Case 1: Alert price is BELOW current price (waiting for price to DROP)
      // Example: Current price = 213, Alert price = 180
      // Trigger when price drops from 213 to 175 (crosses 180 going down)
      if (alertPrice < lastKnownPrice) {
        if (currentPrice <= alertPrice && lastKnownPrice > alertPrice) {
          shouldTriggerAlert = true;
          alertType = 'DROP';
          alertMessage = '$symbol has dropped to \$${currentPrice.toStringAsFixed(2)}, crossing your alert price of \$${alertPrice.toStringAsFixed(2)}';
        }
      }
      // Case 2: Alert price is ABOVE current price (waiting for price to RISE)
      // Example: Current price = 213, Alert price = 300
      // Trigger when price rises from 213 to 301 (crosses 300 going up)
      else if (alertPrice > lastKnownPrice) {
        if (currentPrice >= alertPrice && lastKnownPrice < alertPrice) {
          shouldTriggerAlert = true;
          alertType = 'RISE';
          alertMessage = '$symbol has risen to \$${currentPrice.toStringAsFixed(2)}, crossing your alert price of \$${alertPrice.toStringAsFixed(2)}';
        }
      }
      // Case 3: Alert price equals current price (trigger on any significant movement)
      else if (alertPrice == lastKnownPrice) {
        final priceChangePercent = ((currentPrice - lastKnownPrice) / lastKnownPrice * 100).abs();
        if (priceChangePercent >= 2.0) { // 2% threshold
          shouldTriggerAlert = true;
          alertType = currentPrice > lastKnownPrice ? 'RISE' : 'DROP';
          alertMessage = '$symbol has ${currentPrice > lastKnownPrice ? 'risen' : 'dropped'} to \$${currentPrice.toStringAsFixed(2)} (${priceChangePercent.toStringAsFixed(1)}% change)';
        }
      }

      // Trigger alert if conditions are met and not recently triggered
      if (shouldTriggerAlert && !lastAlertTriggered) {
        await notificationService.showPriceAlert(
          symbol: symbol,
          currentPrice: currentPrice,
          alertPrice: alertPrice,
          isAbove: alertType == 'RISE',
          customMessage: alertMessage,
        );

        // Update the document with new price and alert status
        await doc.reference.update({
          'currentPrice': currentPrice,
          'lastAlertTriggered': true,
          'lastAlertTime': FieldValue.serverTimestamp(),
          'alertTriggeredAt': currentPrice,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // Reset alert if price moves significantly away from alert price
      else if (lastAlertTriggered) {
        final distanceFromAlert = (currentPrice - alertPrice).abs();
        final resetThreshold = alertPrice * 0.02; // 2% of alert price

        if (distanceFromAlert > resetThreshold) {
          // Reset alert so it can trigger again
          await doc.reference.update({
            'currentPrice': currentPrice,
            'lastAlertTriggered': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Just update current price
          await doc.reference.update({
            'currentPrice': currentPrice,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      // Just update current price if no alert conditions met
      else {
        await doc.reference.update({
          'currentPrice': currentPrice,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  } catch (e) {
    // Silent error handling
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
    // Silent error handling
  }
}

Future<void> _performNewsUpdate() async {
  try {
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

    // Silent completion
  } catch (e) {
    // Silent error handling
  }
}

Future<void> _performPortfolioSummary() async {
  try {
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

      // Only send summary if there's significant change
      if (dayChangePercent.abs() >= 1.0) {
        await notificationService.showDailyPortfolioSummary(
          totalValue: totalValue,
          dayChange: dayChange,
          dayChangePercent: dayChangePercent,
        );
      }
    }

    // Silent completion
  } catch (e) {
    // Silent error handling
  }
}
