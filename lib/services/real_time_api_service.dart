import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/news_article.dart';

class RealTimeApiService {
  // Multiple Finnhub API keys for rotation (same as api_service.dart)
  static const List<String> _finnhubApiKeys = [
    'd1inos1r01qhbuvr5ue0d1inos1r01qhbuvr5ueg',
    'd1lag6pr01qt4thevlugd1lag6pr01qt4thevlugd1lag6pr01qt4thevlugd1lag6pr01qt4thevlv0',
    'd1lag6pr01qt4thevlugd1lag6pr01qt4thevlv0',
  ];

  static int _currentFinnhubKeyIndex = 0;
  static const String _finnhubBaseUrl = 'https://finnhub.io/api/v1';

  // iTick API for Indian stocks
  static const String _itickApiKey = '18849dcb33c54c9bbbcf6fa9db4bf1e78393f321459242298c61398542d2eb38';
  static const String _itickBaseUrl = 'https://api.itick.com/api';

  // Alpha Vantage API key
  static const String _alphaVantageApiKey = 'SH48TNN10C7SZ182';
  static const String _alphaVantageBaseUrl = 'https://www.alphavantage.co/query';

  // CoinGecko for crypto
  static const String _coinGeckoBaseUrl = 'https://api.coingecko.com/api/v3';

  static final Map<String, StreamController<double>> _priceStreams = {};
  static Timer? _priceUpdateTimer;
  static final Map<String, double> _lastPrices = {};
  static final Map<String, DateTime> _lastApiCall = {};
  static final Map<String, int> _failureCount = {};
  static const Duration _apiCooldown = Duration(seconds: 30);
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

  // Make Finnhub API request with key rotation on rate limit
  static Future<http.Response> _makeFinnhubApiRequest(String endpoint) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        final apiKey = _getCurrentFinnhubApiKey();
        final response = await http.get(
          Uri.parse('$_finnhubBaseUrl$endpoint&token=$apiKey'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        // If rate limited (429) or unauthorized (401), try next key
        if (response.statusCode == 429 || response.statusCode == 401) {
          print('Finnhub API key rate limited or unauthorized, rotating...');
          _rotateFinnhubApiKey();
          attempts++;
          continue;
        }

        return response;
      } catch (e) {
        print('Finnhub API request error: $e');
        attempts++;
        if (attempts < maxAttempts) {
          _rotateFinnhubApiKey();
        }
      }
    }

    throw Exception('All Finnhub API keys exhausted or network error');
  }

  // Initialize real-time connection with shorter intervals for real-time updates
  static void initializeRealTimeConnection() {
    _priceUpdateTimer?.cancel();
    _priceUpdateTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
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

    // Get initial price immediately
    _getInitialPrice(symbol);
  }

  // Get initial price for a symbol
  static Future<void> _getInitialPrice(String symbol) async {
    try {
      double price;
      if (_isCrypto(symbol)) {
        price = await getCryptoPrice(symbol);
      } else if (_isIndianStock(symbol)) {
        price = await getIndianStockPrice(symbol);
      } else {
        price = await getUSStockPrice(symbol);
      }

      _lastPrices[symbol] = price;
      _priceStreams[symbol]?.add(price);
    } catch (e) {
      print('Error getting initial price for $symbol: $e');
      final mockPrice = _getMockPrice(symbol);
      _lastPrices[symbol] = mockPrice;
      _priceStreams[symbol]?.add(mockPrice);
    }
  }

  // Unsubscribe from symbol
  static void unsubscribeFromSymbol(String symbol) {
    _priceStreams[symbol]?.close();
    _priceStreams.remove(symbol);
    _lastPrices.remove(symbol);
    _lastApiCall.remove(symbol);
    _failureCount.remove(symbol);
  }

  // Update all subscribed prices with real-time data
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
          _failureCount[symbol] = 0;

          // Only emit if price changed significantly (0.1% threshold for real-time)
          final lastPrice = _lastPrices[symbol];
          if (lastPrice == null || (price - lastPrice).abs() > lastPrice * 0.001) {
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

      // Shorter delay between API calls for real-time updates
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

  // US stock price with Finnhub API key rotation
  static Future<double?> _getUSStockPriceWithFallback(String symbol) async {
    // Try Finnhub with key rotation
    try {
      final response = await _makeFinnhubApiRequest('/quote?symbol=$symbol');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['c'] != null && data['c'] != 0) {
          final price = data['c'].toDouble();
          if (price > 0) {
            return price;
          }
        }
      }
    } catch (e) {
      print('Finnhub failed for $symbol: $e');
    }

    // Try Alpha Vantage as fallback
    if (_isValidApiKey(_alphaVantageApiKey)) {
      try {
        return await _getAlphaVantagePrice(symbol);
      } catch (e) {
        print('Alpha Vantage failed for $symbol: $e');
      }
    }

    return null;
  }

  // Indian stock price with iTick API
  static Future<double?> _getIndianStockPriceWithFallback(String symbol) async {
    try {
      // iTick API endpoint for Indian stocks
      final url = '$_itickBaseUrl/quote?symbol=$symbol&apikey=$_itickApiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // iTick API response structure (adjust based on actual API response)
        if (data['data'] != null && data['data']['price'] != null) {
          final price = data['data']['price'].toDouble();
          if (price > 0) {
            return price;
          }
        }

        // Alternative response structure
        if (data['price'] != null) {
          final price = data['price'].toDouble();
          if (price > 0) {
            return price;
          }
        }

        // Another possible structure
        if (data['ltp'] != null) {
          final price = data['ltp'].toDouble();
          if (price > 0) {
            return price;
          }
        }
      }
    } catch (e) {
      print('iTick API failed for $symbol: $e');
    }

    // Fallback to NSE/BSE API if iTick fails
    try {
      final nseUrl = 'https://www.nseindia.com/api/quote-equity?symbol=$symbol';
      final response = await http.get(
        Uri.parse(nseUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['priceInfo'] != null && data['priceInfo']['lastPrice'] != null) {
          final price = data['priceInfo']['lastPrice'].toDouble();
          if (price > 0) {
            return price;
          }
        }
      }
    } catch (e) {
      print('NSE API fallback failed for $symbol: $e');
    }

    return null;
  }

  // Crypto price with CoinGecko
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

  // Public methods with real-time data
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

  // Get multiple asset prices with better batching and real-time data
  static Future<Map<String, double>> getMultipleAssetPrices(List<String> symbols) async {
    final prices = <String, double>{};

    // Process in smaller batches to avoid overwhelming APIs
    const batchSize = 3;
    for (int i = 0; i < symbols.length; i += batchSize) {
      final batch = symbols.skip(i).take(batchSize).toList();

      // Process batch in parallel for better performance
      final futures = batch.map((symbol) async {
        try {
          if (_isCrypto(symbol)) {
            return MapEntry(symbol, await getCryptoPrice(symbol));
          } else if (_isIndianStock(symbol)) {
            return MapEntry(symbol, await getIndianStockPrice(symbol));
          } else {
            return MapEntry(symbol, await getUSStockPrice(symbol));
          }
        } catch (e) {
          print('Failed to get price for $symbol: $e');
          return MapEntry(symbol, _getMockPrice(symbol));
        }
      });

      final results = await Future.wait(futures);
      for (final result in results) {
        prices[result.key] = result.value;
      }

      // Shorter delay between batches for real-time updates
      if (i + batchSize < symbols.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return prices;
  }

  // Search for assets with improved error handling and real API integration
  static Future<List<Map<String, dynamic>>> searchAssets(String query) async {
    try {
      final results = <Map<String, dynamic>>[];

      // Search US stocks with Finnhub
      try {
        final response = await _makeFinnhubApiRequest('/search?q=$query');
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final searchResults = data['result'] as List?;

          if (searchResults != null) {
            final usStocks = searchResults.take(10).map((result) => {
              'symbol': result['symbol'] as String,
              'name': result['description'] as String,
              'type': result['type'] == 'Common Stock' ? 'stock' : 'other',
              'market': 'US',
            }).toList();
            results.addAll(usStocks);
          }
        }
      } catch (e) {
        print('Finnhub search failed: $e');
      }

      // Search Indian stocks with iTick
      try {
        final url = '$_itickBaseUrl/search?q=$query&apikey=$_itickApiKey';
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['data'] != null) {
            final indianStocks = (data['data'] as List).take(5).map((result) => {
              'symbol': result['symbol'] ?? result['tradingsymbol'] ?? '',
              'name': result['name'] ?? result['company_name'] ?? '',
              'type': 'stock',
              'market': 'NSE/BSE',
            }).toList();
            results.addAll(indianStocks);
          }
        }
      } catch (e) {
        print('iTick search failed: $e');
      }

      // Add crypto results
      final cryptoResults = _getMockCryptoResults(query);
      results.addAll(cryptoResults);

      // If no real results, add mock results
      if (results.isEmpty) {
        results.addAll(_getMockSearchResults(query));
      }

      return results.take(20).toList();
    } catch (e) {
      print('Search failed, returning mock data: $e');
      return _getMockSearchResults(query);
    }
  }

  // Get financial news with real-time updates
  static Future<List<NewsArticle>> getFinancialNews() async {
    try {
      // Try Finnhub market news
      final response = await _makeFinnhubApiRequest('/news?category=general');
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.take(10).map((article) => NewsArticle(
          id: article['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: article['headline'] ?? 'No title',
          description: article['summary'] ?? 'No description',
          url: article['url'] ?? '',
          imageUrl: article['image'] ?? '/placeholder.svg?height=200&width=300',
          source: article['source'] ?? 'Finnhub',
          publishedAt: DateTime.fromMillisecondsSinceEpoch((article['datetime'] ?? 0) * 1000),
        )).toList();
      }
    } catch (e) {
      print('Error fetching Finnhub news: $e');
    }

    // Fallback to mock news data
    return _getMockNews();
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
    final seed = symbol.hashCode + now.hour + now.minute ~/ 5;
    final seededRandom = Random(seed);

    double basePrice;

    if (_isCrypto(symbol)) {
      basePrice = _getBasePriceForCrypto(symbol);
      final variation = (seededRandom.nextDouble() - 0.5) * 0.06;
      return double.parse((basePrice * (1 + variation)).toStringAsFixed(4));
    } else if (_isIndianStock(symbol)) {
      basePrice = _getBasePriceForIndianStock(symbol);
      final variation = (seededRandom.nextDouble() - 0.5) * 0.04;
      return double.parse((basePrice * (1 + variation)).toStringAsFixed(2));
    } else {
      basePrice = _getBasePriceForSymbol(symbol);
      final variation = (seededRandom.nextDouble() - 0.5) * 0.03;
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

  static List<Map<String, dynamic>> _getMockCryptoResults(String query) {
    final cryptoAssets = [
      {'symbol': 'BTC', 'name': 'Bitcoin', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'ETH', 'name': 'Ethereum', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'SOL', 'name': 'Solana', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'ADA', 'name': 'Cardano', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'DOT', 'name': 'Polkadot', 'type': 'crypto', 'market': 'Crypto'},
    ];

    final queryLower = query.toLowerCase();
    return cryptoAssets.where((asset) =>
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

  // Get trending assets with real-time data
  static Future<List<Map<String, dynamic>>> getTrendingAssets() async {
    try {
      // Try to get real trending data from Finnhub
      final response = await _makeFinnhubApiRequest('/stock/market-movers?type=active');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          return data.take(5).map((item) => {
            'symbol': item['symbol'] ?? '',
            'name': item['description'] ?? item['symbol'] ?? '',
            'change': '${item['change'] ?? 0 > 0 ? '+' : ''}${(item['change'] ?? 0).toStringAsFixed(2)}%',
          }).toList();
        }
      }
    } catch (e) {
      print('Error fetching trending assets: $e');
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
