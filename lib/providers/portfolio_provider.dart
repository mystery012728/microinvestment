import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/asset.dart';
import '../services/real_time_api_service.dart';

class PortfolioProvider with ChangeNotifier {
  List<Asset> _assets = [];
  bool _isLoading = false;
  String? _userUid;
  String? _error;

  List<Asset> get assets => _assets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalValue => _assets.fold(0, (sum, asset) => sum + asset.totalValue);
  double get totalInvested => _assets.fold(0, (sum, asset) => sum + asset.totalInvested);
  double get totalGainLoss => totalValue - totalInvested;
  double get totalGainLossPercent => totalInvested > 0 ? (totalGainLoss / totalInvested) * 100 : 0;

  Map<String, double> get assetAllocation {
    if (_assets.isEmpty) return {};

    final Map<String, double> allocation = {};
    for (final asset in _assets) {
      final key = asset.type.displayName;
      allocation[key] = (allocation[key] ?? 0) + asset.totalValue;
    }

    return allocation;
  }

  PortfolioProvider() {
    // No initialization needed here as we are using Firestore
  }

  void setUserUid(String? uid) {
    _userUid = uid;
    if (uid != null) {
      loadPortfolio();
    } else {
      _assets.clear();
      notifyListeners();
    }
  }

  Future<void> loadPortfolio() async {
    if (_userUid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('portfolios')
          .where('userId', isEqualTo: _userUid)
          .get();

      _assets = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Asset(
          id: doc.id,
          symbol: data['symbol'] ?? '',
          name: data['name'] ?? '',
          type: AssetType.values.firstWhere(
                (type) => type.name == data['type'],
            orElse: () => AssetType.stock,
          ),
          quantity: (data['quantity'] ?? 0).toDouble(),
          buyPrice: (data['buyPrice'] ?? 0).toDouble(),
          currentPrice: (data['currentPrice'] ?? 0).toDouble(),
          purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      await refreshPrices();
    } catch (e) {
      _error = 'Error loading portfolio: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAsset(Asset asset) async {
    if (_userUid == null) return;

    try {
      // Check if asset already exists for this user
      final existingQuery = await FirebaseFirestore.instance
          .collection('portfolios')
          .where('userId', isEqualTo: _userUid)
          .where('symbol', isEqualTo: asset.symbol)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Update existing asset
        final existingDoc = existingQuery.docs.first;
        final existingData = existingDoc.data();
        final existingQuantity = (existingData['quantity'] ?? 0).toDouble();
        final existingInvested = (existingData['totalInvested'] ?? 0).toDouble();

        final newQuantity = existingQuantity + asset.quantity;
        final newInvested = existingInvested + asset.totalInvested;
        final newAvgPrice = newInvested / newQuantity;

        await existingDoc.reference.update({
          'quantity': newQuantity,
          'buyPrice': newAvgPrice,
          'totalInvested': newInvested,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new asset
        await FirebaseFirestore.instance.collection('portfolios').add({
          'userId': _userUid,
          'symbol': asset.symbol,
          'name': asset.name,
          'type': asset.type.name,
          'quantity': asset.quantity,
          'buyPrice': asset.buyPrice,
          'currentPrice': asset.currentPrice,
          'totalInvested': asset.totalInvested,
          'purchaseDate': Timestamp.fromDate(asset.purchaseDate),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await loadPortfolio();
    } catch (e) {
      _error = 'Error adding asset: $e';
      notifyListeners();
      throw e;
    }
  }

  Future<void> sellAsset(String assetId, double quantity, double sellPrice) async {
    if (_userUid == null) return;

    try {
      final assetDoc = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(assetId)
          .get();

      if (!assetDoc.exists) return;

      final data = assetDoc.data()!;
      final currentQuantity = (data['quantity'] ?? 0).toDouble();
      final totalInvested = (data['totalInvested'] ?? 0).toDouble();

      if (quantity >= currentQuantity) {
        // Sell all - delete the document
        await assetDoc.reference.delete();
      } else {
        // Partial sell - update quantities
        final remainingQuantity = currentQuantity - quantity;
        final soldInvestment = (quantity / currentQuantity) * totalInvested;
        final remainingInvestment = totalInvested - soldInvestment;

        await assetDoc.reference.update({
          'quantity': remainingQuantity,
          'totalInvested': remainingInvestment,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await loadPortfolio();
    } catch (e) {
      _error = 'Error selling asset: $e';
      notifyListeners();
      throw e;
    }
  }

  Future<void> removeAsset(String assetId) async {
    if (_userUid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(assetId)
          .delete();

      await loadPortfolio();
    } catch (e) {
      _error = 'Error removing asset: $e';
      notifyListeners();
      throw e;
    }
  }

  Future<void> refreshPortfolio() async {
    await loadPortfolio();
  }

  Future<void> refreshPrices() async {
    if (_assets.isEmpty) return;

    try {
      final symbols = _assets.map((asset) => asset.symbol).toList();
      final prices = await RealTimeApiService.getMultipleAssetPrices(symbols);

      for (int i = 0; i < _assets.length; i++) {
        final symbol = _assets[i].symbol;
        if (prices.containsKey(symbol)) {
          _assets[i] = _assets[i].copyWith(currentPrice: prices[symbol]!);

          // Update current price in Firestore
          await FirebaseFirestore.instance
              .collection('portfolios')
              .doc(_assets[i].id)
              .update({
            'currentPrice': prices[symbol],
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Check for significant portfolio changes and notify
          final oldValue = _assets[i].quantity * (_assets[i].currentPrice);
          final newValue = _assets[i].quantity * prices[symbol]!;
          final changePercent = oldValue > 0 ? ((newValue - oldValue) / oldValue) * 100 : 0.0;
        }
      }

      notifyListeners();
    } catch (e) {
      _error = 'Error refreshing prices: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // No need to unsubscribe from Firestore as it handles it automatically
    super.dispose();
  }
}

// Extension to add copyWith method to Asset
extension AssetExtension on Asset {
  Asset copyWith({
    String? id,
    String? symbol,
    String? name,
    AssetType? type,
    double? quantity,
    double? buyPrice,
    double? currentPrice,
    DateTime? purchaseDate,
  }) {
    return Asset(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      buyPrice: buyPrice ?? this.buyPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
    );
  }
}
