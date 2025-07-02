import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/watchlist_item.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class WatchlistProvider with ChangeNotifier {
  List<WatchlistItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<WatchlistItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  WatchlistProvider() {
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final watchlistJson = prefs.getString('watchlist_items');

      if (watchlistJson != null) {
        final List<dynamic> itemsList = json.decode(watchlistJson);
        _items = itemsList.map((json) => WatchlistItem.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to load watchlist: $e';
      notifyListeners();
    }
  }

  Future<void> _saveWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final watchlistJson = json.encode(_items.map((item) => item.toJson()).toList());
      await prefs.setString('watchlist_items', watchlistJson);
    } catch (e) {
      _error = 'Failed to save watchlist: $e';
      notifyListeners();
    }
  }

  Future<void> addToWatchlist(String symbol, String name, String type) async {
    try {
      // Check if already exists
      if (_items.any((item) => item.symbol == symbol)) {
        _error = 'Asset already in watchlist';
        notifyListeners();
        return;
      }

      final price = await ApiService.getAssetPrice(symbol);
      final item = WatchlistItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        symbol: symbol,
        name: name,
        type: type,
        currentPrice: price.toDouble(),
        priceChange: 0.0,
        priceChangePercent: 0.0,
      );

      _items.add(item);
      await _saveWatchlist();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add to watchlist: $e';
      notifyListeners();
    }
  }

  Future<void> removeFromWatchlist(String itemId) async {
    try {
      _items.removeWhere((item) => item.id == itemId);
      await _saveWatchlist();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove from watchlist: $e';
      notifyListeners();
    }
  }

  Future<void> setPriceAlert(String itemId, double alertPrice, bool enabled) async {
    try {
      final index = _items.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        _items[index] = _items[index].copyWith(
          alertPrice: alertPrice,
          alertEnabled: enabled,
        );
        await _saveWatchlist();
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to set price alert: $e';
      notifyListeners();
    }
  }

  Future<void> refreshWatchlist() async {
    if (_items.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final symbols = _items.map((item) => item.symbol).toList();
      final prices = await ApiService.getMultipleAssetPrices(symbols);

      _items = _items.map((item) {
        final newPrice = prices[item.symbol]?.toDouble() ?? item.currentPrice;
        final priceChange = newPrice - item.currentPrice;
        final priceChangePercent = item.currentPrice > 0
            ? (priceChange / item.currentPrice) * 100
            : 0.0;

        // Check for price alerts
        if (item.alertEnabled && item.alertPrice != null) {
          final alertPrice = item.alertPrice!;
          if ((newPrice >= alertPrice && item.currentPrice < alertPrice) ||
              (newPrice <= alertPrice && item.currentPrice > alertPrice)) {
            NotificationService().showPriceAlert(
              symbol: item.symbol,
              currentPrice: newPrice,
              alertPrice: alertPrice,
              isAbove: newPrice >= alertPrice,
            );
          }
        }

        return item.copyWith(
          currentPrice: newPrice,
          priceChange: priceChange,
          priceChangePercent: priceChangePercent,
        );
      }).toList();

      await _saveWatchlist();
    } catch (e) {
      _error = 'Failed to refresh watchlist: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}