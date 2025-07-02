enum AssetType {
  stock('📈', 'Stock'),
  crypto('₿', 'Crypto'),
  etf('📊', 'ETF');

  const AssetType(this.icon, this.displayName);
  final String icon;
  final String displayName;
}

class Asset {
  final String id;
  final String symbol;
  final String name;
  final AssetType type;
  final double quantity;
  final double buyPrice;
  final double currentPrice;
  final DateTime purchaseDate;

  Asset({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    required this.quantity,
    required this.buyPrice,
    required this.currentPrice,
    required this.purchaseDate,
  });

  double get totalInvested => quantity * buyPrice;
  double get totalValue => quantity * currentPrice;
  double get totalGainLoss => totalValue - totalInvested;
  double get totalGainLossPercent => 
      totalInvested > 0 ? (totalGainLoss / totalInvested) * 100 : 0;

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'name': name,
      'type': type.name,
      'quantity': quantity,
      'buyPrice': buyPrice,
      'currentPrice': currentPrice,
      'purchaseDate': purchaseDate.toIso8601String(),
    };
  }

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'],
      symbol: json['symbol'],
      name: json['name'],
      type: AssetType.values.firstWhere((e) => e.name == json['type']),
      quantity: json['quantity'].toDouble(),
      buyPrice: json['buyPrice'].toDouble(),
      currentPrice: json['currentPrice'].toDouble(),
      purchaseDate: DateTime.parse(json['purchaseDate']),
    );
  }
}
