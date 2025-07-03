class WatchlistItem {
  final String id;
  final String symbol;
  final String name;
  final String type;
  final double currentPrice;
  final double priceChange;
  final double priceChangePercent;
  final String market;
  final DateTime addedAt;
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
    required this.market,
    DateTime? addedAt,
    this.alertPrice,
    this.alertEnabled = false,
  }) : addedAt = addedAt ?? DateTime.now();

  // Create a copy with updated values
  WatchlistItem copyWith({
    String? id,
    String? symbol,
    String? name,
    String? type,
    double? currentPrice,
    double? priceChange,
    double? priceChangePercent,
    String? market,
    DateTime? addedAt,
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
      market: market ?? this.market,
      addedAt: addedAt ?? this.addedAt,
      alertPrice: alertPrice ?? this.alertPrice,
      alertEnabled: alertEnabled ?? this.alertEnabled,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'name': name,
      'type': type,
      'currentPrice': currentPrice,
      'priceChange': priceChange,
      'priceChangePercent': priceChangePercent,
      'market': market,
      'addedAt': addedAt.toIso8601String(),
      'alertPrice': alertPrice,
      'alertEnabled': alertEnabled,
    };
  }

  // Create from JSON
  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: json['id'] ?? '',
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'stock',
      currentPrice: (json['currentPrice'] ?? 0.0).toDouble(),
      priceChange: (json['priceChange'] ?? 0.0).toDouble(),
      priceChangePercent: (json['priceChangePercent'] ?? 0.0).toDouble(),
      market: json['market'] ?? 'NASDAQ',
      addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
      alertPrice: json['alertPrice']?.toDouble(),
      alertEnabled: json['alertEnabled'] ?? false,
    );
  }

  // Formatted price string
  String get formattedPrice {
    if (type == 'crypto' && currentPrice < 1) {
      return '\$${currentPrice.toStringAsFixed(4)}';
    }
    return '\$${currentPrice.toStringAsFixed(2)}';
  }

  // Formatted price change string
  String get formattedPriceChange {
    final sign = priceChange >= 0 ? '+' : '';
    if (type == 'crypto' && priceChange.abs() < 1) {
      return '$sign${priceChange.toStringAsFixed(4)}';
    }
    return '$sign${priceChange.toStringAsFixed(2)}';
  }

  // Formatted percentage change string
  String get formattedPercentageChange {
    final sign = priceChangePercent >= 0 ? '+' : '';
    return '$sign${priceChangePercent.toStringAsFixed(2)}%';
  }

  // Performance indicator
  String get performanceIndicator {
    if (priceChangePercent > 5) return 'Strong Gain';
    if (priceChangePercent > 2) return 'Moderate Gain';
    if (priceChangePercent > 0) return 'Small Gain';
    if (priceChangePercent == 0) return 'No Change';
    if (priceChangePercent > -2) return 'Small Loss';
    if (priceChangePercent > -5) return 'Moderate Loss';
    return 'Strong Loss';
  }

  // Risk level based on volatility (simplified)
  String get riskLevel {
    final absChange = priceChangePercent.abs();
    if (type == 'crypto') {
      if (absChange > 10) return 'Very High';
      if (absChange > 5) return 'High';
      if (absChange > 2) return 'Medium';
      return 'Low';
    } else {
      if (absChange > 5) return 'High';
      if (absChange > 2) return 'Medium';
      return 'Low';
    }
  }

  // Market cap category (simplified based on price - this is not accurate in real world)
  String get marketCapCategory {
    if (type == 'crypto') {
      if (currentPrice > 50000) return 'Large Cap';
      if (currentPrice > 1000) return 'Mid Cap';
      return 'Small Cap';
    } else {
      if (currentPrice > 500) return 'Large Cap';
      if (currentPrice > 100) return 'Mid Cap';
      return 'Small Cap';
    }
  }

  // Time since added
  String get timeSinceAdded {
    final now = DateTime.now();
    final difference = now.difference(addedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  String toString() {
    return 'WatchlistItem(symbol: $symbol, name: $name, price: $currentPrice, change: $priceChangePercent%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WatchlistItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
