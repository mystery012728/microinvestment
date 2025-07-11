import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/news_article.dart';

class RealTimeApiService {
  // Multiple Finnhub API keys for rotation (same as api_service.dart)
  static const List<String> _finnhubApiKeys = [
    'd1lag6pr01qt4thevlugd1lag6pr01qt4thevlv0',
    'd1j0r5pr01qhbuvspkpgd1j0r5pr01qhbuvspkq0',
    'd1lah59r01qt4thevrh0d1lah59r01qt4thevrhg',
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

  // NEW: Specific search methods required by AddAssetDialog
  static Future<List<Map<String, dynamic>>> searchCrypto(String query) async {
    try {
      final cryptoResults = _getMockCryptoResults(query);
      return cryptoResults;
    } catch (e) {
      print('Crypto search failed: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchUSStocks(String query) async {
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

      // If no real results, add mock results
      if (results.isEmpty) {
        final mockResults = _getMockSearchResults(query);
        results.addAll(mockResults.where((asset) => asset['market'] == 'NASDAQ' || asset['market'] == 'NYSE'));
      }

      return results;
    } catch (e) {
      print('US stock search failed: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchIndianStocks(String query) async {
    try {
      final results = <Map<String, dynamic>>[];

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
              'market': 'NSE',
            }).toList();
            results.addAll(indianStocks);
          }
        }
      } catch (e) {
        print('iTick search failed: $e');
      }

      // If no real results, add mock results
      if (results.isEmpty) {
        final mockResults = _getMockSearchResults(query);
        results.addAll(mockResults.where((asset) => asset['market'] == 'NSE'));
      }

      return results;
    } catch (e) {
      print('Indian stock search failed: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchETFs(String query) async {
    try {
      final results = <Map<String, dynamic>>[];

      // Search ETFs with Finnhub
      try {
        final response = await _makeFinnhubApiRequest('/search?q=$query');
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final searchResults = data['result'] as List?;

          if (searchResults != null) {
            final etfs = searchResults.where((result) =>
            result['type'] == 'ETF' ||
                result['description'].toString().toUpperCase().contains('ETF')
            ).take(10).map((result) => {
              'symbol': result['symbol'] as String,
              'name': result['description'] as String,
              'type': 'etf',
              'market': 'US',
            }).toList();
            results.addAll(etfs);
          }
        }
      } catch (e) {
        print('Finnhub ETF search failed: $e');
      }

      // If no real results, add mock ETF results
      if (results.isEmpty) {
        final mockETFs = _getMockETFResults(query);
        results.addAll(mockETFs);
      }

      return results;
    } catch (e) {
      print('ETF search failed: $e');
      return [];
    }
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
      {'symbol': 'MATIC', 'name': 'Polygon', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'AVAX', 'name': 'Avalanche', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'LINK', 'name': 'Chainlink', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'UNI', 'name': 'Uniswap', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'LTC', 'name': 'Litecoin', 'type': 'crypto', 'market': 'Crypto'},
    ];

    final queryLower = query.toLowerCase();
    return cryptoAssets.where((asset) =>
    asset['symbol']!.toLowerCase().contains(queryLower) ||
        asset['name']!.toLowerCase().contains(queryLower)
    ).toList();
  }

  static List<Map<String, dynamic>> _getMockETFResults(String query) {
    final etfAssets = [
      {'symbol': 'SPY', 'name': 'SPDR S&P 500 ETF Trust', 'type': 'etf', 'market': 'US'},
      {'symbol': 'QQQ', 'name': 'Invesco QQQ Trust', 'type': 'etf', 'market': 'US'},
      {'symbol': 'VTI', 'name': 'Vanguard Total Stock Market ETF', 'type': 'etf', 'market': 'US'},
      {'symbol': 'IWM', 'name': 'iShares Russell 2000 ETF', 'type': 'etf', 'market': 'US'},
      {'symbol': 'EFA', 'name': 'iShares MSCI EAFE ETF', 'type': 'etf', 'market': 'US'},
      {'symbol': 'GLD', 'name': 'SPDR Gold Trust', 'type': 'etf', 'market': 'US'},
      {'symbol': 'TLT', 'name': 'iShares 20+ Year Treasury Bond ETF', 'type': 'etf', 'market': 'US'},
      {'symbol': 'VEA', 'name': 'Vanguard FTSE Developed Markets ETF', 'type': 'etf', 'market': 'US'},
      {'symbol': 'BND', 'name': 'Vanguard Total Bond Market ETF', 'type': 'etf', 'market': 'US'},
      {'symbol': 'ARKK', 'name': 'ARK Innovation ETF', 'type': 'etf', 'market': 'US'},
    ];

    final queryLower = query.toLowerCase();
    return etfAssets.where((asset) =>
    asset['symbol']!.toLowerCase().contains(queryLower) ||
        asset['name']!.toLowerCase().contains(queryLower)
    ).toList();
  }

  static double _getBasePriceForCrypto(String symbol) {
    switch (symbol) {
      case 'BTC':
        return 45000.0;
      case 'ETH':
        return 3200.0;
      case 'ADA':
        return 0.85;
      case 'DOT':
        return 28.0;
      case 'SOL':
        return 180.0;
      case 'MATIC':
        return 1.45;
      case 'AVAX':
        return 95.0;
      case 'LINK':
        return 18.5;
      case 'UNI':
        return 12.0;
      case 'LTC':
        return 180.0;
      default:
        return 100.0;
    }
  }

  static double _getBasePriceForIndianStock(String symbol) {
    switch (symbol) {
      case 'RELIANCE':
        return 2450.0;
      case 'TCS':
        return 3850.0;
      case 'HDFCBANK':
        return 1680.0;
      case 'INFY':
        return 1420.0;
      case 'ICICIBANK':
        return 950.0;
      case 'HINDUNILVR':
        return 2580.0;
      case 'ITC':
        return 420.0;
      case 'SBIN':
        return 580.0;
      case 'BHARTIARTL':
        return 850.0;
      case 'KOTAKBANK':
        return 1850.0;
      case 'LT':
        return 2850.0;
      case 'HCLTECH':
        return 1250.0;
      case 'WIPRO':
        return 480.0;
      case 'MARUTI':
        return 9800.0;
      case 'ASIANPAINT':
        return 3250.0;
      case 'NESTLEIND':
        return 21500.0;
      case 'BAJFINANCE':
        return 7200.0;
      case 'TITAN':
        return 2950.0;
      default:
        return 1000.0;
    }
  }

  static double _getBasePriceForSymbol(String symbol) {
    switch (symbol) {
      case 'AAPL':
        return 175.0;
      case 'GOOGL':
        return 140.0;
      case 'MSFT':
        return 380.0;
      case 'AMZN':
        return 155.0;
      case 'TSLA':
        return 250.0;
      case 'NVDA':
        return 480.0;
      case 'META':
        return 320.0;
      case 'NFLX':
        return 420.0;
      case 'ADBE':
        return 580.0;
      case 'CRM':
        return 280.0;
      case 'SPY':
        return 450.0;
      case 'QQQ':
        return 380.0;
      case 'VTI':
        return 240.0;
      case 'IWM':
        return 195.0;
      case 'EFA':
        return 78.0;
      case 'GLD':
        return 185.0;
      case 'TLT':
        return 95.0;
      case 'VEA':
        return 52.0;
      case 'BND':
        return 78.0;
      case 'ARKK':
        return 48.0;
      default:
        return 100.0;
    }
  }

  static List<NewsArticle> _getMockNews() {
    return [
      NewsArticle(
        id: '1',
        title: 'Stock Market Reaches New Heights Amid Economic Recovery',
        description: 'Major indices continue their upward trajectory as investors show confidence in the economic recovery.',
        url: 'https://example.com/news/1',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Financial Times',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NewsArticle(
        id: '2',
        title: 'Tech Giants Report Strong Quarterly Earnings',
        description: 'Technology companies exceed expectations with robust revenue growth and positive outlook.',
        url: 'https://example.com/news/2',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Reuters',
        publishedAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      NewsArticle(
        id: '3',
        title: 'Cryptocurrency Market Shows Signs of Stabilization',
        description: 'Bitcoin and other major cryptocurrencies maintain steady prices after recent volatility.',
        url: 'https://example.com/news/3',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'CoinDesk',
        publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      NewsArticle(
        id: '4',
        title: 'Federal Reserve Maintains Current Interest Rates',
        description: 'Central bank keeps rates unchanged while monitoring inflation and employment data.',
        url: 'https://example.com/news/4',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Bloomberg',
        publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      NewsArticle(
        id: '5',
        title: 'Renewable Energy Stocks Surge on New Policy Announcements',
        description: 'Clean energy companies see significant gains following government climate initiatives.',
        url: 'https://example.com/news/5',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Wall Street Journal',
        publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      NewsArticle(
        id: '6',
        title: 'Global Supply Chain Improvements Boost Manufacturing Stocks',
        description: 'Manufacturing sector shows resilience with improved supply chain efficiency.',
        url: 'https://example.com/news/6',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'MarketWatch',
        publishedAt: DateTime.now().subtract(const Duration(hours: 16)),
      ),
      NewsArticle(
        id: '7',
        title: 'Real Estate Market Shows Mixed Signals Across Regions',
        description: 'Housing markets vary significantly by geography with some areas showing strength.',
        url: 'https://example.com/news/7',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'CNBC',
        publishedAt: DateTime.now().subtract(const Duration(hours: 20)),
      ),
      NewsArticle(
        id: '8',
        title: 'Healthcare Innovations Drive Pharmaceutical Stock Performance',
        description: 'Medical breakthroughs and new drug approvals support healthcare sector growth.',
        url: 'https://example.com/news/8',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Financial News',
        publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      NewsArticle(
        id: '9',
        title: 'Emerging Markets Attract Increased Investment Interest',
        description: 'International investors show growing confidence in developing economies.',
        url: 'https://example.com/news/9',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Economic Times',
        publishedAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      ),
      NewsArticle(
        id: '10',
        title: 'Consumer Spending Patterns Shift Toward Digital Services',
        description: 'E-commerce and digital service providers benefit from changing consumer behavior.',
        url: 'https://example.com/news/10',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Forbes',
        publishedAt: DateTime.now().subtract(const Duration(days: 1, hours: 12)),
      ),
    ];
  }

  // Clean up resources
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
  static bool isMarketOpen() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday;
    final hour = now.hour;

    // Simple market hours check (9 AM to 4 PM, Monday to Friday)
    return dayOfWeek >= 1 && dayOfWeek <= 5 && hour >= 9 && hour < 16;
  }

  // Get price change percentage
  static double getPriceChangePercentage(double currentPrice, double previousPrice) {
    if (previousPrice == 0) return 0;
    return ((currentPrice - previousPrice) / previousPrice) * 100;
  }

  // Batch price updates for multiple symbols
  static Future<void> batchUpdatePrices(List<String> symbols) async {
    final futures = symbols.map((symbol) async {
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
        print('Batch update failed for $symbol: $e');
      }
    });

    await Future.wait(futures);
  }

  // Get cached price if available
  static double? getCachedPrice(String symbol) {
    return _lastPrices[symbol];
  }

  // Check if symbol is subscribed
  static bool isSubscribed(String symbol) {
    return _priceStreams.containsKey(symbol);
  }

  // Get subscription count
  static int getSubscriptionCount() {
    return _priceStreams.length;
  }
}