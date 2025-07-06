import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/news_article.dart';

class RealTimeApiService {
  // API Keys - Replace with your actual API keys
  static const String _alphaVantageApiKey = 'SH48TNN10C7SZ182';
  static const List<String> _finnhubApiKeys = [
    'd1inos1r01qhbuvr5ue0d1inos1r01qhbuvr5ueg',
    'd1lag6pr01qt4thevlugd1lag6pr01qt4thevlugd1lag6pr01qt4thevlv0',
    'd1lag6pr01qt4thevlugd1lag6pr01qt4thevlv0',
  ];
  static int _currentFinnhubKeyIndex = 0;
  static const String _itickApiKey = '18849dcb33c54c9bbbcf6fa9db4bf1e78393f321459242298c61398542d2eb38';
  static const String _coinGeckoApiKey = 'YOUR_COINGECKO_API_KEY';

  // API Endpoints
  static const String _alphaVantageBaseUrl = 'https://www.alphavantage.co/query';
  static const String _finnhubBaseUrl = 'https://finnhub.io/api/v1';
  static const String _coinGeckoBaseUrl = 'https://api.coingecko.com/api/v3';
  static const String _itickBaseUrl = 'https://api.itick.com/api';

  static final Map<String, StreamController<double>> _priceStreams = {};
  static Timer? _priceUpdateTimer;
  static final Map<String, double> _lastPrices = {};
  static final Map<String, DateTime> _lastApiCall = {};
  static final Map<String, int> _failureCount = {};
  static const Duration _apiCooldown = Duration(seconds: 30); // Reduced cooldown for real-time
  static const int _maxFailures = 3;

  // Get current Finnhub API key and rotate if needed
  static String _getCurrentFinnhubApiKey() {
    return _finnhubApiKeys[_currentFinnhubKeyIndex];
  }

  // Rotate to next Finnhub API key
  static void _rotateFinnhubApiKey() {
    _currentFinnhubKeyIndex = (_currentFinnhubKeyIndex + 1) % _finnhubApiKeys.length;
    print('Rotated to Finnhub API key index: $_currentFinnhubKeyIndex');
  }

  // Make Finnhub API request with key rotation
  static Future<http.Response> _makeFinnhubRequest(String endpoint) async {
    int attempts = 0;
    const maxAttempts = 3; // Try all keys once

    while (attempts < maxAttempts) {
      try {
        final apiKey = _getCurrentFinnhubApiKey();
        final response = await http.get(
          Uri.parse('$_finnhubBaseUrl$endpoint&token=$apiKey'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 8));

        // If rate limited (429) or unauthorized (401), try next key
        if (response.statusCode == 429 || response.statusCode == 401) {
          print('Finnhub API key rate limited, rotating...');
          _rotateFinnhubApiKey();
          attempts++;
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        if (response.statusCode == 200) {
          return response;
        }

        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      } catch (e) {
        print('Finnhub API request error: $e');
        attempts++;
        if (attempts < maxAttempts) {
          _rotateFinnhubApiKey();
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    throw Exception('All Finnhub API keys exhausted');
  }

  // Make iTick API request for Indian stocks
  static Future<http.Response> _makeItickRequest(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$_itickBaseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_itickApiKey',
        },
      ).timeout(const Duration(seconds: 8));

      return response;
    } catch (e) {
      throw Exception('iTick API request error: $e');
    }
  }

  // Initialize real-time connection with shorter intervals for better real-time experience
  static void initializeRealTimeConnection() {
    _priceUpdateTimer?.cancel();
    _priceUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_priceStreams.isNotEmpty) {
        _updateAllPrices();
      }
    });
  }

  // Subscribe to symbol price updates
  static void subscribeToSymbol(String symbol, Function(double) onPriceUpdate) {
    if (!_priceStreams.containsKey(symbol)) {
      _priceStreams[symbol] = StreamController<double>.broadcast();
      _failureCount[symbol] = 0;
    }

    _priceStreams[symbol]!.stream.listen(onPriceUpdate);

    // Immediately provide a price to avoid waiting
    _fetchAndUpdatePrice(symbol);
  }

  // Unsubscribe from symbol
  static void unsubscribeFromSymbol(String symbol) {
    _priceStreams[symbol]?.close();
    _priceStreams.remove(symbol);
    _lastPrices.remove(symbol);
    _lastApiCall.remove(symbol);
    _failureCount.remove(symbol);
  }

  // Fetch and update single price immediately
  static Future<void> _fetchAndUpdatePrice(String symbol) async {
    try {
      double? price;

      if (_isCrypto(symbol)) {
        price = await _getCryptoPriceWithFallback(symbol);
      } else if (_isIndianStock(symbol)) {
        price = await _getIndianStockPriceWithFallback(symbol);
      } else {
        price = await _getUSStockPriceWithFallback(symbol);
      }

      if (price != null) {
        _lastPrices[symbol] = price;
        _priceStreams[symbol]?.add(price);
        _failureCount[symbol] = 0;
      } else {
        _handlePriceFailure(symbol);
      }
    } catch (e) {
      print('Price fetch failed for $symbol: $e');
      _handlePriceFailure(symbol);
    }
  }

  // Update all subscribed prices with better error handling
  static Future<void> _updateAllPrices() async {
    final symbols = _priceStreams.keys.toList();

    for (final symbol in symbols) {
      // Skip if too many recent failures
      if (_failureCount[symbol]! >= _maxFailures) {
        _updateWithMockPrice(symbol);
        continue;
      }

      // Check API cooldown
      final lastCall = _lastApiCall[symbol];
      if (lastCall != null && DateTime.now().difference(lastCall) < _apiCooldown) {
        continue;
      }

      await _fetchAndUpdatePrice(symbol);

      // Add small delay between API calls
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  static void _handlePriceFailure(String symbol) {
    _failureCount[symbol] = (_failureCount[symbol] ?? 0) + 1;
    _updateWithMockPrice(symbol);
  }

  static void _updateWithMockPrice(String symbol) {
    try {
      final mockPrice = _getMockPrice(symbol);
      _lastPrices[symbol] = mockPrice;
      _priceStreams[symbol]?.add(mockPrice);
    } catch (e) {
      print('Mock price generation failed for $symbol: $e');
    }
  }

  // US stock price fetching with Finnhub API rotation
  static Future<double?> _getUSStockPriceWithFallback(String symbol) async {
    try {
      final response = await _makeFinnhubRequest('/quote?symbol=$symbol');
      final data = json.decode(response.body);

      if (data['c'] != null && data['c'] != 0) {
        final price = data['c'].toDouble();
        if (price > 0) {
          _lastApiCall[symbol] = DateTime.now();
          return price;
        }
      }
    } catch (e) {
      print('Finnhub failed for $symbol: $e');
    }
    return null;
  }

  // Indian stock price fetching with iTick API
  static Future<double?> _getIndianStockPriceWithFallback(String symbol) async {
    try {
      // Convert symbol to iTick format (e.g., RELIANCE -> RELIANCE.NSE)
      final itickSymbol = _convertToItickSymbol(symbol);
      final response = await _makeItickRequest('/quote/$itickSymbol');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // iTick API response structure may vary, adjust based on actual response
        final price = data['last_price']?.toDouble() ??
            data['ltp']?.toDouble() ??
            data['price']?.toDouble();

        if (price != null && price > 0) {
          _lastApiCall[symbol] = DateTime.now();
          return price;
        }
      }
    } catch (e) {
      print('iTick API failed for $symbol: $e');
    }
    return null;
  }

  // Convert symbol to iTick format
  static String _convertToItickSymbol(String symbol) {
    // Most Indian stocks are on NSE, some might be on BSE
    final nseStocks = [
      'RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK', 'HINDUNILVR',
      'ITC', 'SBIN', 'BHARTIARTL', 'KOTAKBANK', 'LT', 'HCLTECH',
      'WIPRO', 'MARUTI', 'ASIANPAINT', 'NESTLEIND', 'BAJFINANCE', 'TITAN'
    ];

    if (nseStocks.contains(symbol)) {
      return '$symbol.NSE';
    }

    // Default to NSE for unknown symbols
    return '$symbol.NSE';
  }

  static Future<double?> _getCryptoPriceWithFallback(String symbol) async {
    try {
      final coinId = _getCoinGeckoId(symbol);
      final url = '$_coinGeckoBaseUrl/simple/price?ids=$coinId&vs_currencies=usd';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[coinId] != null && data[coinId]['usd'] != null) {
          return data[coinId]['usd'].toDouble();
        }
      }
    } catch (e) {
      print('CoinGecko failed for $symbol: $e');
    }
    return null;
  }

  // Public methods with improved error handling
  static Future<double> getUSStockPrice(String symbol) async {
    final price = await _getUSStockPriceWithFallback(symbol);
    return price ?? _getMockPrice(symbol);
  }

  static Future<double> getIndianStockPrice(String symbol) async {
    final price = await _getIndianStockPriceWithFallback(symbol);
    return price ?? _getMockPrice(symbol);
  }

  static Future<double> getCryptoPrice(String symbol) async {
    final price = await _getCryptoPriceWithFallback(symbol);
    return price ?? _getMockPrice(symbol);
  }

  // Get multiple asset prices with better batching and API rotation
  static Future<Map<String, double>> getMultipleAssetPrices(List<String> symbols) async {
    final prices = <String, double>{};

    // Process in smaller batches to avoid overwhelming APIs
    const batchSize = 3; // Reduced batch size for better reliability
    for (int i = 0; i < symbols.length; i += batchSize) {
      final batch = symbols.skip(i).take(batchSize).toList();

      for (final symbol in batch) {
        try {
          if (_isCrypto(symbol)) {
            prices[symbol] = await getCryptoPrice(symbol);
          } else if (_isIndianStock(symbol)) {
            prices[symbol] = await getIndianStockPrice(symbol);
          } else {
            prices[symbol] = await getUSStockPrice(symbol);
          }
        } catch (e) {
          print('Failed to get price for $symbol: $e');
          prices[symbol] = _getMockPrice(symbol);
        }

        // Add delay between requests
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Longer delay between batches
      if (i + batchSize < symbols.length) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    return prices;
  }

  // Search for assets with improved error handling
  static Future<List<Map<String, dynamic>>> searchAssets(String query) async {
    try {
      final results = <Map<String, dynamic>>[];

      // Always include mock results as base
      final mockResults = _getMockSearchResults(query);
      results.addAll(mockResults);

      // Try to enhance with real API data
      try {
        final response = await _makeFinnhubRequest('/search?q=$query');
        final data = json.decode(response.body);
        final apiResults = data['result'] as List<dynamic>? ?? [];

        // Merge with mock results, avoiding duplicates
        for (final result in apiResults) {
          final symbol = result['symbol'] as String;
          if (!results.any((r) => r['symbol'] == symbol)) {
            results.add({
              'symbol': symbol,
              'name': result['description'] as String,
              'type': result['type'] == 'Common Stock' ? 'stock' : 'other',
              'market': 'US',
            });
          }
        }
      } catch (e) {
        print('US stock search failed: $e');
      }

      return results.take(20).toList();
    } catch (e) {
      print('Search failed, returning mock data: $e');
      return _getMockSearchResults(query);
    }
  }

  // Helper methods
  static bool _isCrypto(String symbol) {
    return ['BTC', 'ETH', 'ADA', 'DOT', 'SOL', 'MATIC', 'AVAX', 'LINK', 'UNI', 'LTC'].contains(symbol);
  }

  static bool _isIndianStock(String symbol) {
    return [
      'RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK', 'HINDUNILVR',
      'ITC', 'SBIN', 'BHARTIARTL', 'KOTAKBANK', 'LT', 'HCLTECH',
      'WIPRO', 'MARUTI', 'ASIANPAINT', 'NESTLEIND', 'BAJFINANCE', 'TITAN'
    ].contains(symbol);
  }

  static String _getCoinGeckoId(String symbol) {
    final mapping = {
      'BTC': 'bitcoin',
      'ETH': 'ethereum',
      'ADA': 'cardano',
      'DOT': 'polkadot',
      'SOL': 'solana',
      'MATIC': 'matic-network',
      'AVAX': 'avalanche-2',
      'LINK': 'chainlink',
      'UNI': 'uniswap',
      'LTC': 'litecoin',
    };
    return mapping[symbol] ?? symbol.toLowerCase();
  }

  // Enhanced mock data with more realistic price movements
  static double _getMockPrice(String symbol) {
    final random = Random();
    final now = DateTime.now();
    final seed = symbol.hashCode + now.hour + now.minute ~/ 5; // Update every 5 minutes
    final seededRandom = Random(seed);

    double basePrice;

    if (_isCrypto(symbol)) {
      basePrice = _getBasePriceForCrypto(symbol);
      final variation = (seededRandom.nextDouble() - 0.5) * 0.08; // ±4% variation
      return double.parse((basePrice * (1 + variation)).toStringAsFixed(4));
    } else if (_isIndianStock(symbol)) {
      basePrice = _getBasePriceForIndianStock(symbol);
      final variation = (seededRandom.nextDouble() - 0.5) * 0.06; // ±3% variation
      return double.parse((basePrice * (1 + variation)).toStringAsFixed(2));
    } else {
      basePrice = _getBasePriceForSymbol(symbol);
      final variation = (seededRandom.nextDouble() - 0.5) * 0.05; // ±2.5% variation
      return double.parse((basePrice * (1 + variation)).toStringAsFixed(2));
    }
  }

  static List<Map<String, dynamic>> _getMockSearchResults(String query) {
    final allAssets = [
      {'symbol': 'AAPL', 'name': 'Apple Inc.', 'type': 'stock', 'market': 'NASDAQ'},
      {'symbol': 'GOOGL', 'name': 'Alphabet Inc.', 'type': 'stock', 'market': 'NASDAQ'},
      {'symbol': 'MSFT', 'name': 'Microsoft Corporation', 'type': 'stock', 'market': 'NASDAQ'},
      {'symbol': 'AMZN', 'name': 'Amazon.com Inc.', 'type': 'stock', 'market': 'NASDAQ'},
      {'symbol': 'TSLA', 'name': 'Tesla Inc.', 'type': 'stock', 'market': 'NASDAQ'},
      {'symbol': 'NVDA', 'name': 'NVIDIA Corporation', 'type': 'stock', 'market': 'NASDAQ'},
      {'symbol': 'META', 'name': 'Meta Platforms Inc.', 'type': 'stock', 'market': 'NASDAQ'},
      {'symbol': 'BTC', 'name': 'Bitcoin', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'ETH', 'name': 'Ethereum', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'SOL', 'name': 'Solana', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'RELIANCE', 'name': 'Reliance Industries Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'TCS', 'name': 'Tata Consultancy Services Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'HDFCBANK', 'name': 'HDFC Bank Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'INFY', 'name': 'Infosys Ltd.', 'type': 'stock', 'market': 'NSE'},
    ];

    final queryLower = query.toLowerCase();
    return allAssets.where((asset) =>
    asset['symbol']!.toLowerCase().contains(queryLower) ||
        asset['name']!.toLowerCase().contains(queryLower)
    ).toList();
  }

  static double _getBasePriceForSymbol(String symbol) {
    final prices = {
      'AAPL': 185.0, 'GOOGL': 145.0, 'MSFT': 385.0, 'AMZN': 155.0, 'TSLA': 255.0,
      'NVDA': 850.0, 'META': 325.0, 'NFLX': 455.0, 'JPM': 155.0, 'V': 255.0,
      'SPY': 455.0, 'QQQ': 385.0, 'VTI': 225.0, 'IWM': 205.0,
    };
    return prices[symbol] ?? 100.0;
  }

  static double _getBasePriceForIndianStock(String symbol) {
    final prices = {
      'RELIANCE': 2550.0, 'TCS': 3850.0, 'HDFCBANK': 1675.0, 'INFY': 1475.0,
      'ICICIBANK': 1225.0, 'HINDUNILVR': 2425.0, 'ITC': 465.0, 'SBIN': 765.0,
      'BHARTIARTL': 1225.0, 'KOTAKBANK': 1825.0, 'LT': 3225.0, 'HCLTECH': 1525.0,
      'WIPRO': 465.0, 'MARUTI': 10750.0, 'ASIANPAINT': 3225.0, 'NESTLEIND': 2225.0,
      'BAJFINANCE': 7650.0, 'TITAN': 3425.0,
    };
    return prices[symbol] ?? 1000.0;
  }

  static double _getBasePriceForCrypto(String symbol) {
    final prices = {
      'BTC': 67500.0, 'ETH': 3650.0, 'ADA': 0.48, 'DOT': 7.8, 'SOL': 185.0,
      'MATIC': 0.88, 'AVAX': 38.0, 'LINK': 16.5, 'UNI': 9.2, 'LTC': 98.0,
    };
    return prices[symbol] ?? 1.0;
  }

  // Dispose resources
  static void dispose() {
    _priceUpdateTimer?.cancel();
    for (final controller in _priceStreams.values) {
      controller.close();
    }
    _priceStreams.clear();
    _lastPrices.clear();
    _lastApiCall.clear();
    _failureCount.clear();
  }

  // Get market status
  static Map<String, dynamic> getMarketStatus() {
    final now = DateTime.now();
    final hour = now.hour;

    return {
      'isOpen': hour >= 9 && hour < 16,
      'nextOpen': hour >= 16 ? 'Tomorrow 9:00 AM' : 'Market is open',
      'timezone': 'EST',
    };
  }

  // Get trending assets with real API data
  static Future<List<Map<String, dynamic>>> getTrendingAssets() async {
    try {
      // Try to get real trending data from Finnhub
      final response = await _makeFinnhubRequest('/stock/market-movers?type=active');
      final data = json.decode(response.body);

      if (data['result'] != null) {
        final trending = (data['result'] as List).take(5).map((item) => {
          'symbol': item['symbol'],
          'name': item['description'] ?? item['symbol'],
          'change': '${item['change'] >= 0 ? '+' : ''}${item['change'].toStringAsFixed(2)}%',
        }).toList();

        if (trending.isNotEmpty) {
          return trending;
        }
      }
    } catch (e) {
      print('Failed to get trending assets: $e');
    }

    // Fallback to mock trending data
    return [
      {'symbol': 'NVDA', 'name': 'NVIDIA Corporation', 'change': '+5.2%'},
      {'symbol': 'BTC', 'name': 'Bitcoin', 'change': '+3.8%'},
      {'symbol': 'TSLA', 'name': 'Tesla Inc.', 'change': '+2.1%'},
      {'symbol': 'RELIANCE', 'name': 'Reliance Industries', 'change': '+1.9%'},
      {'symbol': 'ETH', 'name': 'Ethereum', 'change': '+4.3%'},
    ];
  }
}
