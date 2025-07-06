import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/watchlist_item.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

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

      // Show confirmation notification
      if (enabled && alertPrice > 0) {
        await NotificationService().showPriceAlert(
          symbol: _items[index].symbol,
          currentPrice: _items[index].currentPrice,
          alertPrice: alertPrice,
          isAbove: alertPrice > _items[index].currentPrice,
        );
      }
    } catch (e) {
      print('Error setting price alert: $e');
      throw e;
    }
  }

  Future<void> refreshWatchlist() async {
    await loadWatchlist();
  }

  Future<void> refreshPrices() async {
    if (_items.isEmpty) return;

    try {
      final symbols = _items.map((item) => item.symbol).toList();
      final prices = await ApiService.getMultipleAssetPrices(symbols);

      for (int i = 0; i < _items.length; i++) {
        final symbol = _items[i].symbol;
        if (prices.containsKey(symbol)) {
          final newPrice = prices[symbol]!.toDouble(); // Convert to double
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

          // Check for significant price changes and notify
          if ((priceChangePercent.abs() >= 5.0) && oldPrice > 0) {
            await NotificationService().showPortfolioUpdate(
              symbol: symbol,
              currentValue: newPrice,
              previousValue: oldPrice,
              changePercent: priceChangePercent,
            );
          }
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
