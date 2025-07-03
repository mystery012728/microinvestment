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
  static const String _coinGeckoApiKey = 'YOUR_COINGECKO_API_KEY'; // Optional, CoinGecko has free tier

  // API Endpoints
  static const String _alphaVantageBaseUrl = 'https://www.alphavantage.co/query';
  static const String _finnhubBaseUrl = 'https://finnhub.io/api/v1';
  static const String _coinGeckoBaseUrl = 'https://api.coingecko.com/api/v3';
  static const String _newsApiBaseUrl = 'https://newsapi.org/v2';
  static const String _nseApiBaseUrl = 'https://www.nseindia.com/api';

  static final Map<String, StreamController<double>> _priceStreams = {};
  static Timer? _priceUpdateTimer;
  static final Map<String, double> _lastPrices = {};
  static final Map<String, DateTime> _lastApiCall = {};
  static const Duration _apiCooldown = Duration(seconds: 12); // Respect API rate limits

  // Initialize real-time connection
  static void initializeRealTimeConnection() {
    _priceUpdateTimer?.cancel();
    _priceUpdateTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (_priceStreams.isNotEmpty) {
        _updateAllPrices();
      }
    });
  }

  // Subscribe to symbol price updates
  static void subscribeToSymbol(String symbol, Function(double) onPriceUpdate) {
    if (!_priceStreams.containsKey(symbol)) {
      _priceStreams[symbol] = StreamController<double>.broadcast();
    }

    _priceStreams[symbol]!.stream.listen(onPriceUpdate);
  }

  // Unsubscribe from symbol
  static void unsubscribeFromSymbol(String symbol) {
    _priceStreams[symbol]?.close();
    _priceStreams.remove(symbol);
    _lastPrices.remove(symbol);
    _lastApiCall.remove(symbol);
  }

  // Update all subscribed prices
  static Future<void> _updateAllPrices() async {
    for (final symbol in _priceStreams.keys) {
      // Check API cooldown
      final lastCall = _lastApiCall[symbol];
      if (lastCall != null && DateTime.now().difference(lastCall) < _apiCooldown) {
        continue;
      }

      try {
        double price;
        if (_isCrypto(symbol)) {
          price = await getCryptoPrice(symbol);
        } else if (_isIndianStock(symbol)) {
          price = await getIndianStockPrice(symbol);
        } else {
          price = await getUSStockPrice(symbol);
        }

        _lastApiCall[symbol] = DateTime.now();

        // Only emit if price changed significantly
        final lastPrice = _lastPrices[symbol];
        if (lastPrice == null || (price - lastPrice).abs() > lastPrice * 0.001) {
          _lastPrices[symbol] = price;
          _priceStreams[symbol]?.add(price);
        }
      } catch (e) {
        print('Failed to update price for $symbol: $e');
        // Fallback to mock data if API fails
        try {
          final mockPrice = _getMockPrice(symbol);
          _priceStreams[symbol]?.add(mockPrice);
        } catch (mockError) {
          print('Mock price fallback failed for $symbol: $mockError');
        }
      }
    }
  }

  // Search for assets using multiple APIs
  static Future<List<Map<String, dynamic>>> searchAssets(String query) async {
    try {
      final results = <Map<String, dynamic>>[];

      // Search US stocks using Alpha Vantage
      if (_alphaVantageApiKey != 'YOUR_ALPHA_VANTAGE_API_KEY') {
        try {
          final usStocks = await _searchUSStocks(query);
          results.addAll(usStocks);
        } catch (e) {
          print('US stock search failed: $e');
        }
      }

      // Search cryptocurrencies using CoinGecko
      try {
        final cryptos = await _searchCryptos(query);
        results.addAll(cryptos);
      } catch (e) {
        print('Crypto search failed: $e');
      }

      // Add Indian stocks (using predefined list as NSE API requires special handling)
      final indianStocks = _searchIndianStocks(query);
      results.addAll(indianStocks);

      // Add ETFs
      final etfs = _searchETFs(query);
      results.addAll(etfs);

      // If no results from APIs, return mock data
      if (results.isEmpty) {
        return _getMockSearchResults(query);
      }

      return results.take(25).toList();
    } catch (e) {
      print('Search failed, returning mock data: $e');
      return _getMockSearchResults(query);
    }
  }

  // Search US stocks using Alpha Vantage
  static Future<List<Map<String, dynamic>>> _searchUSStocks(String query) async {
    if (_alphaVantageApiKey == 'YOUR_ALPHA_VANTAGE_API_KEY') {
      return [];
    }

    try {
      final url = '$_alphaVantageBaseUrl?function=SYMBOL_SEARCH&keywords=$query&apikey=$_alphaVantageApiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final matches = data['bestMatches'] as List<dynamic>? ?? [];

        return matches.map((match) => {
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

  // Search cryptocurrencies using CoinGecko
  static Future<List<Map<String, dynamic>>> _searchCryptos(String query) async {
    try {
      final url = '$_coinGeckoBaseUrl/search?query=$query';
      final headers = _coinGeckoApiKey != 'YOUR_COINGECKO_API_KEY'
          ? {'x-cg-demo-api-key': _coinGeckoApiKey}
          : <String, String>{};

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coins = data['coins'] as List<dynamic>? ?? [];

        return coins.take(10).map((coin) => {
          'symbol': (coin['symbol'] as String).toUpperCase(),
          'name': coin['name'] ?? '',
          'type': 'crypto',
          'market': 'Crypto',
        }).toList();
      }
    } catch (e) {
      print('CoinGecko search error: $e');
    }

    return [];
  }

  // Search Indian stocks (predefined list)
  static List<Map<String, dynamic>> _searchIndianStocks(String query) {
    final indianStocks = [
      {'symbol': 'RELIANCE', 'name': 'Reliance Industries Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'TCS', 'name': 'Tata Consultancy Services Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'HDFCBANK', 'name': 'HDFC Bank Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'INFY', 'name': 'Infosys Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'ICICIBANK', 'name': 'ICICI Bank Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'HINDUNILVR', 'name': 'Hindustan Unilever Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'ITC', 'name': 'ITC Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'SBIN', 'name': 'State Bank of India', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'BHARTIARTL', 'name': 'Bharti Airtel Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'KOTAKBANK', 'name': 'Kotak Mahindra Bank Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'LT', 'name': 'Larsen & Toubro Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'HCLTECH', 'name': 'HCL Technologies Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'WIPRO', 'name': 'Wipro Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'MARUTI', 'name': 'Maruti Suzuki India Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'ASIANPAINT', 'name': 'Asian Paints Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'NESTLEIND', 'name': 'Nestle India Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'BAJFINANCE', 'name': 'Bajaj Finance Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'TITAN', 'name': 'Titan Company Ltd.', 'type': 'stock', 'market': 'NSE'},
    ];

    final queryLower = query.toLowerCase();
    return indianStocks.where((stock) =>
    stock['symbol']!.toLowerCase().contains(queryLower) ||
        stock['name']!.toLowerCase().contains(queryLower)
    ).toList();
  }

  // Search ETFs (predefined list)
  static List<Map<String, dynamic>> _searchETFs(String query) {
    final etfs = [
      {'symbol': 'SPY', 'name': 'SPDR S&P 500 ETF Trust', 'type': 'etf', 'market': 'NYSE'},
      {'symbol': 'QQQ', 'name': 'Invesco QQQ Trust', 'type': 'etf', 'market': 'NASDAQ'},
      {'symbol': 'VTI', 'name': 'Vanguard Total Stock Market ETF', 'type': 'etf', 'market': 'NYSE'},
      {'symbol': 'IWM', 'name': 'iShares Russell 2000 ETF', 'type': 'etf', 'market': 'NYSE'},
      {'symbol': 'EFA', 'name': 'iShares MSCI EAFE ETF', 'type': 'etf', 'market': 'NYSE'},
      {'symbol': 'VEA', 'name': 'Vanguard FTSE Developed Markets ETF', 'type': 'etf', 'market': 'NYSE'},
    ];

    final queryLower = query.toLowerCase();
    return etfs.where((etf) =>
    etf['symbol']!.toLowerCase().contains(queryLower) ||
        etf['name']!.toLowerCase().contains(queryLower)
    ).toList();
  }

  // Get US stock price using Alpha Vantage or Finnhub
  static Future<double> getUSStockPrice(String symbol) async {
    // Try Alpha Vantage first
    if (_alphaVantageApiKey != 'YOUR_ALPHA_VANTAGE_API_KEY') {
      try {
        return await _getAlphaVantagePrice(symbol);
      } catch (e) {
        print('Alpha Vantage failed for $symbol: $e');
      }
    }

    // Try Finnhub as fallback
    if (_finnhubApiKey != 'YOUR_FINNHUB_API_KEY') {
      try {
        return await _getFinnhubPrice(symbol);
      } catch (e) {
        print('Finnhub failed for $symbol: $e');
      }
    }

    // Fallback to mock data
    return _getMockPrice(symbol);
  }

  // Get price from Alpha Vantage
  static Future<double> _getAlphaVantagePrice(String symbol) async {
    final url = '$_alphaVantageBaseUrl?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$_alphaVantageApiKey';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final quote = data['Global Quote'];

      if (quote != null && quote['05. price'] != null) {
        return double.parse(quote['05. price']);
      }
    }

    throw Exception('Failed to get Alpha Vantage price for $symbol');
  }

  // Get price from Finnhub
  static Future<double> _getFinnhubPrice(String symbol) async {
    final url = '$_finnhubBaseUrl/quote?symbol=$symbol&token=$_finnhubApiKey';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['c'] != null && data['c'] != 0) {
        return data['c'].toDouble();
      }
    }

    throw Exception('Failed to get Finnhub price for $symbol');
  }

  // Get Indian stock price (using mock data as NSE API requires special handling)
  static Future<double> getIndianStockPrice(String symbol) async {
    try {
      // NSE API requires special headers and session management
      // For now, using mock data with realistic simulation
      await Future.delayed(const Duration(milliseconds: 800));
      return _getMockPrice(symbol);
    } catch (e) {
      throw Exception('Failed to get Indian stock price: $e');
    }
  }

  // Get crypto price using CoinGecko
  static Future<double> getCryptoPrice(String symbol) async {
    try {
      final coinId = _getCoinGeckoId(symbol);
      final url = '$_coinGeckoBaseUrl/simple/price?ids=$coinId&vs_currencies=usd';
      final headers = _coinGeckoApiKey != 'YOUR_COINGECKO_API_KEY'
          ? {'x-cg-demo-api-key': _coinGeckoApiKey}
          : <String, String>{};

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data[coinId] != null && data[coinId]['usd'] != null) {
          return data[coinId]['usd'].toDouble();
        }
      }
    } catch (e) {
      print('CoinGecko API failed for $symbol: $e');
    }

    // Fallback to mock data
    return _getMockPrice(symbol);
  }

  // Get multiple asset prices efficiently
  static Future<Map<String, double>> getMultipleAssetPrices(List<String> symbols) async {
    final prices = <String, double>{};

    // Group symbols by type for batch processing
    final usStocks = symbols.where((s) => !_isCrypto(s) && !_isIndianStock(s)).toList();
    final cryptos = symbols.where((s) => _isCrypto(s)).toList();
    final indianStocks = symbols.where((s) => _isIndianStock(s)).toList();

    // Process each group
    final futures = <Future<void>>[];

    // US Stocks
    if (usStocks.isNotEmpty) {
      futures.add(_getMultipleUSStockPrices(usStocks).then((result) {
        prices.addAll(result);
      }));
    }

    // Cryptocurrencies
    if (cryptos.isNotEmpty) {
      futures.add(_getMultipleCryptoPrices(cryptos).then((result) {
        prices.addAll(result);
      }));
    }

    // Indian Stocks
    if (indianStocks.isNotEmpty) {
      futures.add(_getMultipleIndianStockPrices(indianStocks).then((result) {
        prices.addAll(result);
      }));
    }

    await Future.wait(futures);
    return prices;
  }

  // Get multiple US stock prices
  static Future<Map<String, double>> _getMultipleUSStockPrices(List<String> symbols) async {
    final prices = <String, double>{};

    for (final symbol in symbols) {
      try {
        prices[symbol] = await getUSStockPrice(symbol);
        // Add small delay to respect rate limits
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        print('Failed to get price for $symbol: $e');
        prices[symbol] = _getMockPrice(symbol);
      }
    }

    return prices;
  }

  // Get multiple crypto prices using batch API
  static Future<Map<String, double>> _getMultipleCryptoPrices(List<String> symbols) async {
    final prices = <String, double>{};

    try {
      final coinIds = symbols.map((s) => _getCoinGeckoId(s)).join(',');
      final url = '$_coinGeckoBaseUrl/simple/price?ids=$coinIds&vs_currencies=usd';
      final headers = _coinGeckoApiKey != 'YOUR_COINGECKO_API_KEY'
          ? {'x-cg-demo-api-key': _coinGeckoApiKey}
          : <String, String>{};

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        for (final symbol in symbols) {
          final coinId = _getCoinGeckoId(symbol);
          if (data[coinId] != null && data[coinId]['usd'] != null) {
            prices[symbol] = data[coinId]['usd'].toDouble();
          } else {
            prices[symbol] = _getMockPrice(symbol);
          }
        }
      }
    } catch (e) {
      print('Batch crypto price fetch failed: $e');
      // Fallback to individual calls
      for (final symbol in symbols) {
        prices[symbol] = _getMockPrice(symbol);
      }
    }

    return prices;
  }

  // Get multiple Indian stock prices
  static Future<Map<String, double>> _getMultipleIndianStockPrices(List<String> symbols) async {
    final prices = <String, double>{};

    for (final symbol in symbols) {
      try {
        prices[symbol] = await getIndianStockPrice(symbol);
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        prices[symbol] = _getMockPrice(symbol);
      }
    }

    return prices;
  }

  // Get financial news using News API
  static Future<List<NewsArticle>> getFinancialNews() async {
    if (_newsApiKey == 'YOUR_NEWS_API_KEY') {
      return _getMockNews();
    }

    try {
      final url = '$_newsApiBaseUrl/everything?q=finance OR stock OR crypto OR investment&sortBy=publishedAt&pageSize=20&apiKey=$_newsApiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

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

  // Mock data fallbacks
  static double _getMockPrice(String symbol) {
    final random = Random();
    double basePrice;

    if (_isCrypto(symbol)) {
      basePrice = _getBasePriceForCrypto(symbol);
      final variation = (random.nextDouble() - 0.5) * 0.15;
      return double.parse((basePrice * (1 + variation)).toStringAsFixed(2));
    } else if (_isIndianStock(symbol)) {
      basePrice = _getBasePriceForIndianStock(symbol);
      final variation = (random.nextDouble() - 0.5) * 0.1;
      return double.parse((basePrice * (1 + variation)).toStringAsFixed(2));
    } else {
      basePrice = _getBasePriceForSymbol(symbol);
      final variation = (random.nextDouble() - 0.5) * 0.08;
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
      {'symbol': 'BTC', 'name': 'Bitcoin', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'ETH', 'name': 'Ethereum', 'type': 'crypto', 'market': 'Crypto'},
      {'symbol': 'RELIANCE', 'name': 'Reliance Industries Ltd.', 'type': 'stock', 'market': 'NSE'},
      {'symbol': 'TCS', 'name': 'Tata Consultancy Services Ltd.', 'type': 'stock', 'market': 'NSE'},
    ];

    final queryLower = query.toLowerCase();
    return allAssets.where((asset) =>
    asset['symbol']!.toLowerCase().contains(queryLower) ||
        asset['name']!.toLowerCase().contains(queryLower)
    ).toList();
  }

  static double _getBasePriceForSymbol(String symbol) {
    final prices = {
      'AAPL': 180.0, 'GOOGL': 140.0, 'MSFT': 380.0, 'AMZN': 150.0, 'TSLA': 250.0,
      'NVDA': 800.0, 'META': 320.0, 'NFLX': 450.0, 'JPM': 150.0, 'V': 250.0,
      'SPY': 450.0, 'QQQ': 380.0, 'VTI': 220.0, 'IWM': 200.0,
    };
    return prices[symbol] ?? 100.0;
  }

  static double _getBasePriceForIndianStock(String symbol) {
    final prices = {
      'RELIANCE': 2500.0, 'TCS': 3800.0, 'HDFCBANK': 1650.0, 'INFY': 1450.0,
      'ICICIBANK': 1200.0, 'HINDUNILVR': 2400.0, 'ITC': 450.0, 'SBIN': 750.0,
      'BHARTIARTL': 1200.0, 'KOTAKBANK': 1800.0, 'LT': 3200.0, 'HCLTECH': 1500.0,
      'WIPRO': 450.0, 'MARUTI': 10500.0, 'ASIANPAINT': 3200.0, 'NESTLEIND': 2200.0,
      'BAJFINANCE': 7500.0, 'TITAN': 3400.0,
    };
    return prices[symbol] ?? 1000.0;
  }

  static double _getBasePriceForCrypto(String symbol) {
    final prices = {
      'BTC': 65000.0, 'ETH': 3500.0, 'ADA': 0.45, 'DOT': 7.5, 'SOL': 180.0,
      'MATIC': 0.85, 'AVAX': 35.0, 'LINK': 15.0, 'UNI': 8.5, 'LTC': 95.0,
    };
    return prices[symbol] ?? 1.0;
  }

  static List<NewsArticle> _getMockNews() {
    final now = DateTime.now();
    return [
      NewsArticle(
        id: '1',
        title: 'Indian Stock Market Hits New Highs Amid Economic Recovery',
        description: 'Sensex and Nifty reach record levels as investors show confidence in India\'s economic growth prospects.',
        url: 'https://example.com/news/1',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Economic Times',
        publishedAt: now.subtract(const Duration(hours: 1)),
      ),
      NewsArticle(
        id: '2',
        title: 'Bitcoin Surges Past \$65,000 as Institutional Adoption Grows',
        description: 'Cryptocurrency markets see renewed interest from institutional investors.',
        url: 'https://example.com/news/2',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'CoinDesk',
        publishedAt: now.subtract(const Duration(hours: 2)),
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
