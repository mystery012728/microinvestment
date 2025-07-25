import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import '../models/watchlist_item.dart';
import '../services/real_time_api_service.dart' show RealTimeApiService;

class WatchlistProvider with ChangeNotifier {
  List<WatchlistItem> _items = [];
  bool _isLoading = false;
  String? _userUid;

  List<WatchlistItem> get items => _items;
  bool get isLoading => _isLoading;

  void setUserUid(String? uid) {
    _userUid = uid;
    if (uid != null) {
      loadWatchlist();
    } else {
      _items.clear();
      notifyListeners();
    }
  }

  Future<void> loadWatchlist() async {
    if (_userUid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('watchlist')
          .where('userId', isEqualTo: _userUid)
          .orderBy('createdAt', descending: true)
          .get();

      _items = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return WatchlistItem(
          id: doc.id,
          symbol: data['symbol'] ?? '',
          name: data['name'] ?? '',
          type: data['type'] ?? 'stock',
          currentPrice: (data['currentPrice'] as num? ?? 0).toDouble(),
          priceChange: (data['priceChange'] as num? ?? 0).toDouble(),
          priceChangePercent: (data['priceChangePercent'] as num? ?? 0).toDouble(),
          alertPrice: (data['alertPrice'] as num? ?? 0).toDouble(),
          alertEnabled: data['alertEnabled'] ?? false,
          market: data['market'] ?? 'US',
        );
      }).toList();

      await refreshPrices();
    } catch (e) {
      print('Error loading watchlist: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addToWatchlist(
      String symbol,
      String name,
      String type,
      double currentPrice,
      String market,
      ) async {
    if (_userUid == null) return;

    try {
      // Check if item already exists for this user
      final existingQuery = await FirebaseFirestore.instance
          .collection('watchlist')
          .where('userId', isEqualTo: _userUid)
          .where('symbol', isEqualTo: symbol)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('$symbol is already in your watchlist');
      }

      await FirebaseFirestore.instance.collection('watchlist').add({
        'userId': _userUid,
        'symbol': symbol,
        'name': name,
        'type': type,
        'currentPrice': currentPrice,
        'priceChange': 0.0,
        'priceChangePercent': 0.0,
        'alertPrice': 0.0,
        'alertEnabled': false,
        'lastAlertTriggered': false,
        'lastAlertTime': null,
        'alertTriggeredAt': null,
        'market': market,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await loadWatchlist();
    } catch (e) {
      print('Error adding to watchlist: $e');
      throw e;
    }
  }

  Future<void> removeFromWatchlist(String itemId) async {
    if (_userUid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('watchlist')
          .doc(itemId)
          .delete();

      await loadWatchlist();
      await _manageAlertTask(); // Check if need to stop task
    } catch (e) {
      print('Error removing from watchlist: $e');
      throw e;
    }
  }

  Future<void> setPriceAlert(String itemId, double alertPrice, bool enabled) async {
    if (_userUid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('watchlist')
          .doc(itemId)
          .update({
        'alertPrice': alertPrice,
        'alertEnabled': enabled,
        'lastAlertTriggered': false,
        'lastAlertTime': null,
        'alertTriggeredAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local item
      final index = _items.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        _items[index] = _items[index].copyWith(
          alertPrice: alertPrice,
          alertEnabled: enabled,
        );
        notifyListeners();
      }

      // Manage WorkManager task
      await _manageAlertTask();

    } catch (e) {
      print('Error setting price alert: $e');
      throw e;
    }
  }

  // Simple method to start/stop price alert task
  Future<void> _manageAlertTask() async {
    try {
      bool hasActiveAlerts = _items.any((item) => item.alertEnabled);

      if (hasActiveAlerts) {
        // Start price alert task (15 minutes)
        await Workmanager().registerPeriodicTask(
          'priceAlertTask',
          'priceAlertTask',
          frequency: const Duration(minutes: 15),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
        print('Price alert task started');
      } else {
        // Stop price alert task
        await Workmanager().cancelByUniqueName('priceAlertTask');
        print('Price alert task stopped');
      }
    } catch (e) {
      print('Error managing alert task: $e');
    }
  }

  Future<void> refreshWatchlist() async {
    await loadWatchlist();
  }

  Future<void> refreshPrices() async {
    if (_items.isEmpty) return;

    try {
      final symbols = _items.map((item) => item.symbol).toList();
      final prices = await RealTimeApiService.getMultipleAssetPrices(symbols);

      for (int i = 0; i < _items.length; i++) {
        final symbol = _items[i].symbol;
        if (prices.containsKey(symbol)) {
          final newPrice = prices[symbol]!.toDouble();
          final oldPrice = _items[i].currentPrice;
          final priceChange = newPrice - oldPrice;
          final priceChangePercent = oldPrice > 0 ? (priceChange / oldPrice) * 100 : 0.0;

          _items[i] = _items[i].copyWith(
            currentPrice: newPrice,
            priceChange: priceChange,
            priceChangePercent: priceChangePercent,
          );

          // Update price in Firestore
          await FirebaseFirestore.instance
              .collection('watchlist')
              .doc(_items[i].id)
              .update({
            'currentPrice': newPrice,
            'priceChange': priceChange,
            'priceChangePercent': priceChangePercent,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error refreshing watchlist prices: $e');
    }
  }
}

// Extension to add copyWith method to WatchlistItem
extension WatchlistItemExtension on WatchlistItem {
  WatchlistItem copyWith({
    String? id,
    String? symbol,
    String? name,
    String? type,
    double? currentPrice,
    double? priceChange,
    double? priceChangePercent,
    double? alertPrice,
    bool? alertEnabled,
    String? market,
  }) {
    return WatchlistItem(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      type: type ?? this.type,
      currentPrice: currentPrice ?? this.currentPrice,
      priceChange: priceChange ?? this.priceChange,
      priceChangePercent: priceChangePercent ?? this.priceChangePercent,
      alertPrice: alertPrice ?? this.alertPrice,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      market: market ?? this.market,
    );
  }
}