import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset.dart';
import '../services/api_service.dart';

class PortfolioProvider with ChangeNotifier {
  List<Asset> _assets = [];
  bool _isLoading = false;
  String? _error;

  List<Asset> get assets => _assets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalValue => _assets.fold(0, (sum, asset) => sum + asset.totalValue);
  double get totalInvested => _assets.fold(0, (sum, asset) => sum + asset.totalInvested);
  double get totalGainLoss => totalValue - totalInvested;
  double get totalGainLossPercent => 
      totalInvested > 0 ? (totalGainLoss / totalInvested) * 100 : 0;

  Map<String, double> get assetAllocation {
    if (_assets.isEmpty) return {};
    
    final Map<String, double> allocation = {};
    for (final asset in _assets) {
      allocation[asset.symbol] = asset.totalValue;
    }
    return allocation;
  }

  PortfolioProvider() {
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assetsJson = prefs.getString('portfolio_assets');
      
      if (assetsJson != null) {
        final List<dynamic> assetsList = json.decode(assetsJson);
        _assets = assetsList.map((json) => Asset.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to load portfolio: $e';
      notifyListeners();
    }
  }

  Future<void> _saveAssets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assetsJson = json.encode(_assets.map((asset) => asset.toJson()).toList());
      await prefs.setString('portfolio_assets', assetsJson);
    } catch (e) {
      _error = 'Failed to save portfolio: $e';
      notifyListeners();
    }
  }

  Future<void> addAsset(Asset asset) async {
    try {
      _assets.add(asset);
      await _saveAssets();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add asset: $e';
      notifyListeners();
    }
  }

  Future<void> removeAsset(String assetId) async {
    try {
      _assets.removeWhere((asset) => asset.id == assetId);
      await _saveAssets();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove asset: $e';
      notifyListeners();
    }
  }

  Future<void> refreshPortfolio() async {
    if (_assets.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final symbols = _assets.map((asset) => asset.symbol).toList();
      final prices = await ApiService.getMultipleAssetPrices(symbols);

      _assets = _assets.map((asset) {
        final newPrice = prices[asset.symbol] ?? asset.currentPrice;
        return asset.copyWith(currentPrice: newPrice);
      }).toList();

      await _saveAssets();
    } catch (e) {
      _error = 'Failed to refresh portfolio: $e';
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
