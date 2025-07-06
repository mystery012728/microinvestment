import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _channelKey = 'investment_alerts';
  static const String _portfolioChannelKey = 'portfolio_updates';
  static const String _newsChannelKey = 'news_updates';

  Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher_foreground',
      [
        // Price Alerts Channel
        NotificationChannel(
          channelKey: _channelKey,
          channelName: 'Investment Alerts',
          channelDescription: 'Notifications for price alerts and watchlist updates',
          defaultColor: const Color(0xFF2196F3),
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        // Portfolio Updates Channel
        NotificationChannel(
          channelKey: _portfolioChannelKey,
          channelName: 'Portfolio Updates',
          channelDescription: 'Notifications for portfolio value changes',
          defaultColor: const Color(0xFF4CAF50),
          ledColor: Colors.green,
          importance: NotificationImportance.Default,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        // News Updates Channel
        NotificationChannel(
          channelKey: _newsChannelKey,
          channelName: 'News Updates',
          channelDescription: 'Latest financial news notifications',
          defaultColor: const Color(0xFFFF9800),
          ledColor: Colors.orange,
          importance: NotificationImportance.Default,
          channelShowBadge: false,
          playSound: false,
          enableVibration: false,
        ),
      ],
    );

    // Request permissions
    await requestNotificationPermissions();
  }

  Future<bool> requestNotificationPermissions() async {
    return await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  Future<void> showPriceAlert({
    required String symbol,
    required double currentPrice,
    required double alertPrice,
    required bool isAbove,
    String? customMessage,
  }) async {
    final String title = '🚨 Price Alert: $symbol';

    String body;
    if (customMessage != null) {
      body = customMessage;
    } else {
      if (isAbove) {
        body = '$symbol has risen to \$${currentPrice.toStringAsFixed(2)}, crossing your alert price of \$${alertPrice.toStringAsFixed(2)} 📈';
      } else {
        body = '$symbol has dropped to \$${currentPrice.toStringAsFixed(2)}, crossing your alert price of \$${alertPrice.toStringAsFixed(2)} 📉';
      }
    }

    // Add price change information
    final priceChange = currentPrice - alertPrice;
    final priceChangePercent = (priceChange / alertPrice * 100);
    final changeText = priceChange >= 0 ? '+' : '';
    body += '\n\nChange: $changeText\$${priceChange.toStringAsFixed(2)} (${changeText}${priceChangePercent.toStringAsFixed(1)}%)';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: symbol.hashCode + DateTime.now().millisecondsSinceEpoch.remainder(1000),
        channelKey: _channelKey,
        title: title,
        body: body,
        bigPicture: 'resource://drawable/ic_launcher_foreground',
        notificationLayout: NotificationLayout.BigText,
        color: isAbove ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
        backgroundColor: isAbove ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
        category: NotificationCategory.Recommendation,
        wakeUpScreen: true,
        fullScreenIntent: true,
        criticalAlert: true,
        payload: {
          'symbol': symbol,
          'currentPrice': currentPrice.toString(),
          'alertPrice': alertPrice.toString(),
          'type': 'price_alert',
        },
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'VIEW_DETAILS',
          label: 'View Details',
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'SET_NEW_ALERT',
          label: 'Set New Alert',
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'DISMISS',
          label: 'Dismiss',
          actionType: ActionType.DismissAction,
        ),
      ],
    );
  }

  Future<void> showPortfolioUpdate({
    required String symbol,
    required double currentValue,
    required double previousValue,
    required double changePercent,
  }) async {
    final bool isPositive = currentValue > previousValue;
    final String changeText = isPositive ? 'increased' : 'decreased';
    final String emoji = isPositive ? '📈' : '📉';
    final String title = '$emoji Portfolio Update: $symbol';
    final String body = 'Your $symbol investment has $changeText by ${changePercent.abs().toStringAsFixed(2)}%.\n\nCurrent value: \$${currentValue.toStringAsFixed(2)}\nPrevious value: \$${previousValue.toStringAsFixed(2)}\nChange: ${isPositive ? '+' : ''}\$${(currentValue - previousValue).toStringAsFixed(2)}';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 'portfolio_${symbol}'.hashCode + DateTime.now().millisecondsSinceEpoch.remainder(1000),
        channelKey: _portfolioChannelKey,
        title: title,
        body: body,
        summary: '$emoji ${changePercent.toStringAsFixed(2)}%',
        notificationLayout: NotificationLayout.BigText,
        color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
        category: NotificationCategory.Status,
        wakeUpScreen: false,
        payload: {
          'symbol': symbol,
          'currentValue': currentValue.toString(),
          'changePercent': changePercent.toString(),
          'type': 'portfolio_update',
        },
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'VIEW_PORTFOLIO',
          label: 'View Portfolio',
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'DISMISS',
          label: 'Dismiss',
          actionType: ActionType.DismissAction,
        ),
      ],
    );
  }

  Future<void> showNewsUpdate({
    required String title,
    required String summary,
    required String url,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: _newsChannelKey,
        title: '📰 Financial News Update',
        body: title,
        summary: summary,
        bigPicture: 'resource://drawable/ic_launcher_foreground',
        notificationLayout: NotificationLayout.BigText,
        color: const Color(0xFFFF9800),
        category: NotificationCategory.Social,
        payload: {
          'url': url,
          'type': 'news_update',
        },
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'READ_MORE',
          label: 'Read More',
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'DISMISS_NEWS',
          label: 'Dismiss',
          actionType: ActionType.DismissAction,
        ),
      ],
    );
  }

  Future<void> showDailyPortfolioSummary({
    required double totalValue,
    required double dayChange,
    required double dayChangePercent,
  }) async {
    final bool isPositive = dayChange >= 0;
    final String changeText = isPositive ? 'gained' : 'lost';
    final String emoji = isPositive ? '📈' : '📉';
    final String title = '$emoji Daily Portfolio Summary';
    final String body = 'Your portfolio has $changeText \$${dayChange.abs().toStringAsFixed(2)} (${dayChangePercent.abs().toStringAsFixed(2)}%) today.\n\nTotal value: \$${totalValue.toStringAsFixed(2)}\nDaily change: ${isPositive ? '+' : ''}\$${dayChange.toStringAsFixed(2)}\nPercentage: ${isPositive ? '+' : ''}${dayChangePercent.toStringAsFixed(2)}%';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 'daily_summary'.hashCode + DateTime.now().day,
        channelKey: _portfolioChannelKey,
        title: title,
        body: body,
        summary: '$emoji ${dayChangePercent.toStringAsFixed(2)}%',
        bigPicture: 'resource://drawable/ic_launcher_foreground',
        notificationLayout: NotificationLayout.BigText,
        color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
        category: NotificationCategory.Status,
        wakeUpScreen: false,
        payload: {
          'totalValue': totalValue.toString(),
          'dayChange': dayChange.toString(),
          'type': 'daily_summary',
        },
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'VIEW_PORTFOLIO',
          label: 'View Portfolio',
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'DISMISS',
          label: 'Dismiss',
          actionType: ActionType.DismissAction,
        ),
      ],
    );
  }

  Future<void> schedulePeriodicPriceCheck() async {
    // This will be handled by WorkManager background tasks
    debugPrint('Periodic price check scheduled via WorkManager');
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  Future<void> cancelNotification(String symbol) async {
    await AwesomeNotifications().cancel(symbol.hashCode);
  }

  Future<void> cancelPortfolioNotifications() async {
    // Cancel all portfolio-related notifications
    await AwesomeNotifications().cancelNotificationsByChannelKey(_portfolioChannelKey);
  }

  Future<void> cancelNewsNotifications() async {
    // Cancel all news-related notifications
    await AwesomeNotifications().cancelNotificationsByChannelKey(_newsChannelKey);
  }

  // Handle notification actions
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    debugPrint('Notification action received: ${receivedAction.buttonKeyPressed}');

    switch (receivedAction.buttonKeyPressed) {
      case 'VIEW_DETAILS':
      case 'VIEW_PORTFOLIO':
      // Navigate to portfolio screen
      // This would typically be handled by the main app
        break;
      case 'SET_NEW_ALERT':
      // Open alert setting dialog
      // This would typically be handled by the main app
        break;
      case 'READ_MORE':
      // Open news URL
        final url = receivedAction.payload?['url'];
        if (url != null) {
          // Handle URL opening
          debugPrint('Opening URL: $url');
        }
        break;
      case 'DISMISS':
      case 'DISMISS_NEWS':
      // Just dismiss the notification
        break;
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }

  // Open notification settings
  Future<void> openNotificationSettings() async {
    await AwesomeNotifications().showNotificationConfigPage();
  }
}
