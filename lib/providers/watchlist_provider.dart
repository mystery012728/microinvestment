import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/watchlist_item.dart';
import '../services/real_time_api_service.dart';
import '../services/notification_service.dart';

class WatchlistProvider with ChangeNotifier {
  List<WatchlistItem> _items = [];
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  bool _isInitialized = false;

  List<WatchlistItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  WatchlistProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadWatchlist();
    _startAutoRefresh();
    _isInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_items.isNotEmpty) {
        refreshWatchlist();
      }
    });
  }

  Future<void> _loadWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final watchlistJson = prefs.getString('watchlist_items');

      if (watchlistJson != null) {
        final List<dynamic> itemsList = json.decode(watchlistJson);
        _items = itemsList.map((json) => WatchlistItem.fromJson(json)).toList();
        notifyListeners();

        // Subscribe to real-time updates for loaded items
        for (final item in _items) {
          RealTimeApiService.subscribeToSymbol(item.symbol, (newPrice) {
            _updateItemPrice(item.symbol, newPrice);
          });
        }

        // Refresh prices after loading
        if (_items.isNotEmpty) {
          refreshWatchlist();
        }
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

  Future<void> addToWatchlist(
      String symbol,
      String name,
      String type,
      double currentPrice,
      String market,
      ) async {
    try {
      // Check if already exists
      if (_items.any((item) => item.symbol == symbol)) {
        throw Exception('Asset already in watchlist');
      }

      final item = WatchlistItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        symbol: symbol,
        name: name,
        type: type,
        currentPrice: currentPrice,
        priceChange: 0.0,
        priceChangePercent: 0.0,
        market: market,
      );

      _items.add(item);
      await _saveWatchlist();
      notifyListeners();

      // Subscribe to real-time updates for this symbol
      RealTimeApiService.subscribeToSymbol(symbol, (newPrice) {
        _updateItemPrice(symbol, newPrice);
      });

    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeFromWatchlist(String itemId) async {
    try {
      final item = _items.firstWhere((item) => item.id == itemId);

      // Unsubscribe from real-time updates
      RealTimeApiService.unsubscribeFromSymbol(item.symbol);

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
      final prices = await RealTimeApiService.getMultipleAssetPrices(symbols);

      final updatedItems = <WatchlistItem>[];

      for (final item in _items) {
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

        updatedItems.add(item.copyWith(
          currentPrice: newPrice,
          priceChange: priceChange,
          priceChangePercent: priceChangePercent,
        ));
      }

      _items = updatedItems;
      await _saveWatchlist();
    } catch (e) {
      _error = 'Failed to refresh watchlist: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateItemPrice(String symbol, double newPrice) {
    final index = _items.indexWhere((item) => item.symbol == symbol);
    if (index != -1) {
      final item = _items[index];
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

      _items[index] = item.copyWith(
        currentPrice: newPrice,
        priceChange: priceChange,
        priceChangePercent: priceChangePercent,
      );

      notifyListeners();
      _saveWatchlist();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get watchlist summary
  Map<String, dynamic> getWatchlistSummary() {
    if (_items.isEmpty) {
      return {
        'totalAssets': 0,
        'gainers': 0,
        'losers': 0,
        'neutral': 0,
        'totalValue': 0.0,
        'totalChange': 0.0,
        'totalChangePercent': 0.0,
      };
    }

    final gainers = _items.where((item) => item.priceChange > 0).length;
    final losers = _items.where((item) => item.priceChange < 0).length;
    final neutral = _items.where((item) => item.priceChange == 0).length;
    final totalValue = _items.fold(0.0, (sum, item) => sum + item.currentPrice);
    final totalChange = _items.fold(0.0, (sum, item) => sum + item.priceChange);
    final totalChangePercent = _items.isNotEmpty
        ? _items.fold(0.0, (sum, item) => sum + item.priceChangePercent) / _items.length
        : 0.0;

    return {
      'totalAssets': _items.length,
      'gainers': gainers,
      'losers': losers,
      'neutral': neutral,
      'totalValue': totalValue,
      'totalChange': totalChange,
      'totalChangePercent': totalChangePercent,
    };
  }

  // Sort watchlist
  void sortWatchlist(String sortBy) {
    switch (sortBy) {
      case 'name':
        _items.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'symbol':
        _items.sort((a, b) => a.symbol.compareTo(b.symbol));
        break;
      case 'price':
        _items.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        break;
      case 'change':
        _items.sort((a, b) => b.priceChangePercent.compareTo(a.priceChangePercent));
        break;
      case 'market':
        _items.sort((a, b) => a.market.compareTo(b.market));
        break;
      case 'type':
        _items.sort((a, b) => a.type.compareTo(b.type));
        break;
      case 'added':
        _items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
    }
    notifyListeners();
    _saveWatchlist();
  }

  // Filter watchlist
  List<WatchlistItem> getFilteredItems({
    String? type,
    String? market,
    bool? gainersOnly,
    bool? losersOnly,
  }) {
    var filtered = _items.where((item) => true);

    if (type != null && type != 'all') {
      filtered = filtered.where((item) => item.type == type);
    }

    if (market != null && market != 'all') {
      filtered = filtered.where((item) => item.market == market);
    }

    if (gainersOnly == true) {
      filtered = filtered.where((item) => item.priceChange > 0);
    }

    if (losersOnly == true) {
      filtered = filtered.where((item) => item.priceChange < 0);
    }

    return filtered.toList();
  }

  // Get top performers
  List<WatchlistItem> getTopPerformers({int limit = 5}) {
    final sorted = List<WatchlistItem>.from(_items);
    sorted.sort((a, b) => b.priceChangePercent.compareTo(a.priceChangePercent));
    return sorted.take(limit).toList();
  }

  // Get worst performers
  List<WatchlistItem> getWorstPerformers({int limit = 5}) {
    final sorted = List<WatchlistItem>.from(_items);
    sorted.sort((a, b) => a.priceChangePercent.compareTo(b.priceChangePercent));
    return sorted.take(limit).toList();
  }

  // Search within watchlist
  List<WatchlistItem> searchWatchlist(String query) {
    if (query.isEmpty) return _items;

    final lowercaseQuery = query.toLowerCase();
    return _items.where((item) =>
    item.symbol.toLowerCase().contains(lowercaseQuery) ||
        item.name.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }
}
