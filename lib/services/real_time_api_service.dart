import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/news_article.dart';

class RealTimeApiService {
  // API Keys - Replace with your actual API keys
  static const String _alphaVantageApiKey = 'SH48TNN10C7SZ182';
  static const String _finnhubApiKey = 'd1inos1r01qhbuvr5ue0d1inos1r01qhbuvr5ueg';
  static const String _newsApiKey = '86cf54b70f4341219a3ee9a7779ae2dd';
  static const String _coinGeckoApiKey = 'YOUR_COINGECKO_API_KEY';

  // API Endpoints
  static const String _alphaVantageBaseUrl = 'https://www.alphavantage.co/query';
  static const String _finnhubBaseUrl = 'https://finnhub.io/api/v1';
  static const String _coinGeckoBaseUrl = 'https://api.coingecko.com/api/v3';
  static const String _newsApiBaseUrl = 'https://newsapi.org/v2';

  static final Map<String, StreamController<double>> _priceStreams = {};
  static Timer? _priceUpdateTimer;
  static final Map<String, double> _lastPrices = {};
  static final Map<String, DateTime> _lastApiCall = {};
  static final Map<String, int> _failureCount = {};
  static const Duration _apiCooldown = Duration(minutes: 1); // Increased cooldown
  static const int _maxFailures = 3;

  // Initialize real-time connection with longer intervals to avoid rate limits
  static void initializeRealTimeConnection() {
    _priceUpdateTimer?.cancel();
    _priceUpdateTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
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

    // Immediately provide a mock price to avoid waiting
    final mockPrice = _getMockPrice(symbol);
    _lastPrices[symbol] = mockPrice;
    _priceStreams[symbol]?.add(mockPrice);
  }

  // Unsubscribe from symbol
  static void unsubscribeFromSymbol(String symbol) {
    _priceStreams[symbol]?.close();
    _priceStreams.remove(symbol);
    _lastPrices.remove(symbol);
    _lastApiCall.remove(symbol);
    _failureCount.remove(symbol);
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
          _lastApiCall[symbol] = DateTime.now();
          _failureCount[symbol] = 0; // Reset failure count on success

          // Only emit if price changed significantly
          final lastPrice = _lastPrices[symbol];
          if (lastPrice == null || (price - lastPrice).abs() > lastPrice * 0.005) {
            _lastPrices[symbol] = price;
            _priceStreams[symbol]?.add(price);
          }
        } else {
          _handlePriceFailure(symbol);
        }
      } catch (e) {
        print('Price update failed for $symbol: $e');
        _handlePriceFailure(symbol);
      }

      // Add delay between API calls to respect rate limits
      await Future.delayed(const Duration(milliseconds: 500));
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

  // Improved US stock price fetching with better fallback
  static Future<double?> _getUSStockPriceWithFallback(String symbol) async {
    // Try Alpha Vantage first (with validation)
    if (_isValidApiKey(_alphaVantageApiKey)) {
      try {
        return await _getAlphaVantagePrice(symbol);
      } catch (e) {
        print('Alpha Vantage failed for $symbol (will try fallback): $e');
      }
    }

    // Try Finnhub as fallback (with validation)
    if (_isValidApiKey(_finnhubApiKey)) {
      try {
        return await _getFinnhubPrice(symbol);
      } catch (e) {
        print('Finnhub failed for $symbol (using mock data): $e');
      }
    }

    return null; // Will trigger mock data usage
  }

  static Future<double?> _getCryptoPriceWithFallback(String symbol) async {
    try {
      final coinId = _getCoinGeckoId(symbol);
      final url = '$_coinGeckoBaseUrl/simple/price?ids=$coinId&vs_currencies=usd';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

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

  static Future<double?> _getIndianStockPriceWithFallback(String symbol) async {
    // Indian stock APIs require special handling, using mock for now
    await Future.delayed(const Duration(milliseconds: 200));
    return null; // Will use mock data
  }

  static bool _isValidApiKey(String apiKey) {
    return apiKey.isNotEmpty &&
        !apiKey.startsWith('YOUR_') &&
        apiKey.length > 10;
  }

  // Get price from Alpha Vantage with better error handling
  static Future<double> _getAlphaVantagePrice(String symbol) async {
    final url = '$_alphaVantageBaseUrl?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$_alphaVantageApiKey';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Check for API limit error
      if (data.containsKey('Note') || data.containsKey('Information')) {
        throw Exception('API rate limit exceeded');
      }

      final quote = data['Global Quote'];
      if (quote != null && quote['05. price'] != null) {
        final price = double.tryParse(quote['05. price']);
        if (price != null && price > 0) {
          return price;
        }
      }
    }

    throw Exception('Invalid response from Alpha Vantage for $symbol');
  }

  // Get price from Finnhub with better error handling
  static Future<double> _getFinnhubPrice(String symbol) async {
    final url = '$_finnhubBaseUrl/quote?symbol=$symbol&token=$_finnhubApiKey';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['c'] != null && data['c'] != 0) {
        final price = data['c'].toDouble();
        if (price > 0) {
          return price;
        }
      }
    }

    throw Exception('Invalid response from Finnhub for $symbol');
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

  // Get multiple asset prices with better batching
  static Future<Map<String, double>> getMultipleAssetPrices(List<String> symbols) async {
    final prices = <String, double>{};

    // Process in smaller batches to avoid overwhelming APIs
    const batchSize = 5;
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

      // Try to enhance with real API data if available
      if (_isValidApiKey(_alphaVantageApiKey)) {
        try {
          final usStocks = await _searchUSStocks(query);
          // Merge with mock results, avoiding duplicates
          for (final stock in usStocks) {
            if (!results.any((r) => r['symbol'] == stock['symbol'])) {
              results.add(stock);
            }
          }
        } catch (e) {
          print('US stock search failed: $e');
        }
      }

      return results.take(20).toList();
    } catch (e) {
      print('Search failed, returning mock data: $e');
      return _getMockSearchResults(query);
    }
  }

  // Search US stocks with timeout and error handling
  static Future<List<Map<String, dynamic>>> _searchUSStocks(String query) async {
    try {
      final url = '$_alphaVantageBaseUrl?function=SYMBOL_SEARCH&keywords=$query&apikey=$_alphaVantageApiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check for API errors
        if (data.containsKey('Note') || data.containsKey('Information')) {
          throw Exception('API rate limit exceeded');
        }

        final matches = data['bestMatches'] as List<dynamic>? ?? [];

        return matches.take(10).map((match) => {
          'symbol': match['1. symbol'] ?? '',
          'name': match['2. name'] ?? '',
          'type': 'stock',
          'market': match['4. region'] == 'United States' ? 'NASDAQ' : 'NYSE',
        }).toList();
      }
    } catch (e) {
      print('Alpha Vantage search error: $e');
    }

    return [];
  }

  // Get financial news with better error handling
  static Future<List<NewsArticle>> getFinancialNews() async {
    if (!_isValidApiKey(_newsApiKey)) {
      return _getMockNews();
    }

    try {
      final url = '$_newsApiBaseUrl/everything?q=finance OR stock OR investment&sortBy=publishedAt&pageSize=15&apiKey=$_newsApiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = data['articles'] as List<dynamic>? ?? [];

        return articles.map((article) => NewsArticle(
          id: article['url']?.hashCode.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: article['title'] ?? 'No Title',
          description: article['description'] ?? 'No Description',
          url: article['url'] ?? '',
          imageUrl: article['urlToImage'] ?? '/placeholder.svg?height=200&width=300',
          source: article['source']?['name'] ?? 'Unknown',
          publishedAt: DateTime.tryParse(article['publishedAt'] ?? '') ?? DateTime.now(),
        )).toList();
      }
    } catch (e) {
      print('News API failed: $e');
    }

    return _getMockNews();
  }

  // Helper methods (unchanged)
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
    final seed = symbol.hashCode + now.hour + now.minute ~/ 10;
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

  static List<NewsArticle> _getMockNews() {
    final now = DateTime.now();
    return [
      NewsArticle(
        id: '1',
        title: 'Global Markets Show Resilience Amid Economic Uncertainty',
        description: 'Major indices maintain stability as investors adapt to changing economic conditions.',
        url: 'https://example.com/news/1',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Financial Times',
        publishedAt: now.subtract(const Duration(hours: 1)),
      ),
      NewsArticle(
        id: '2',
        title: 'Cryptocurrency Market Sees Renewed Interest from Institutions',
        description: 'Digital assets gain traction as more institutional investors enter the space.',
        url: 'https://example.com/news/2',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'CoinDesk',
        publishedAt: now.subtract(const Duration(hours: 3)),
      ),
      NewsArticle(
        id: '3',
        title: 'Tech Sector Innovation Drives Market Optimism',
        description: 'Technology companies continue to lead market growth with breakthrough innovations.',
        url: 'https://example.com/news/3',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'TechCrunch',
        publishedAt: now.subtract(const Duration(hours: 5)),
      ),
    ];
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

  // Get trending assets
  static Future<List<Map<String, dynamic>>> getTrendingAssets() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      {'symbol': 'NVDA', 'name': 'NVIDIA Corporation', 'change': '+5.2%'},
      {'symbol': 'BTC', 'name': 'Bitcoin', 'change': '+3.8%'},
      {'symbol': 'TSLA', 'name': 'Tesla Inc.', 'change': '+2.1%'},
      {'symbol': 'RELIANCE', 'name': 'Reliance Industries', 'change': '+1.9%'},
      {'symbol': 'ETH', 'name': 'Ethereum', 'change': '+4.3%'},
    ];
  }
}
