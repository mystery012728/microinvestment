class WatchlistItem {
  final String id;
  final String symbol;
  final String name;
  final String type;
  final double currentPrice;
  final double priceChange;
  final double priceChangePercent;
  final double? alertPrice;
  final bool alertEnabled;

  WatchlistItem({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    required this.currentPrice,
    required this.priceChange,
    required this.priceChangePercent,
    this.alertPrice,
    this.alertEnabled = false,
  });

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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'name': name,
      'type': type,
      'currentPrice': currentPrice,
      'priceChange': priceChange,
      'priceChangePercent': priceChangePercent,
      'alertPrice': alertPrice,
      'alertEnabled': alertEnabled,
    };
  }

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: json['id'],
      symbol: json['symbol'],
      name: json['name'],
      type: json['type'],
      currentPrice: json['currentPrice'].toDouble(),
      priceChange: json['priceChange'].toDouble(),
      priceChangePercent: json['priceChangePercent'].toDouble(),
      alertPrice: json['alertPrice']?.toDouble(),
      alertEnabled: json['alertEnabled'] ?? false,
    );
  }
}

// Import AssetType from asset.dart
// import 'asset.dart';
