import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/news_article.dart';

class ApiService {
  // Multiple Finnhub API keys for rotation
  static const List<String> _finnhubApiKeys = [
    'd1inos1r01qhbuvr5ue0d1inos1r01qhbuvr5ueg',
    'd1lag6pr01qt4thevlugd1lag6pr01qt4thevlugd1lag6pr01qt4thevlv0',
    'd1lag6pr01qt4thevlugd1lag6pr01qt4thevlv0',
  ];

  static int _currentKeyIndex = 0;
  static const String _finnhubBaseUrl = 'https://finnhub.io/api/v1';

  // News API key (optional - for real news)
  static const String _newsApiKey = '86cf54b70f4341219a3ee9a7779ae2dd';
  static const String _newsBaseUrl = 'https://newsapi.org/v2';

  // Mock data for demonstration (fallback when API is not available)
  static final Map<String, double> _mockPrices = {
    'AAPL': 175.43,
    'GOOGL': 2847.63,
    'MSFT': 338.11,
    'TSLA': 248.50,
    'AMZN': 3342.88,
    'BTC': 43250.00,
    'ETH': 2650.00,
    'ADA': 0.48,
    'DOT': 7.25,
    'SOL': 98.50,
  };

  // Get current API key and rotate if needed
  static String _getCurrentApiKey() {
    return _finnhubApiKeys[_currentKeyIndex];
  }

  // Rotate to next API key
  static void _rotateApiKey() {
    _currentKeyIndex = (_currentKeyIndex + 1) % _finnhubApiKeys.length;
    print('Rotated to API key index: $_currentKeyIndex');
  }

  // Make API request with key rotation on rate limit
  static Future<http.Response> _makeApiRequest(String endpoint) async {
    int attempts = 0;
    const maxAttempts = 3; // Try all keys once

    while (attempts < maxAttempts) {
      try {
        final apiKey = _getCurrentApiKey();
        final response = await http.get(
          Uri.parse('$_finnhubBaseUrl$endpoint&token=$apiKey'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        // If rate limited (429) or unauthorized (401), try next key
        if (response.statusCode == 429 || response.statusCode == 401) {
          print('API key rate limited or unauthorized, rotating...');
          _rotateApiKey();
          attempts++;
          continue;
        }

        return response;
      } catch (e) {
        print('API request error: $e');
        attempts++;
        if (attempts < maxAttempts) {
          _rotateApiKey();
        }
      }
    }

    throw Exception('All API keys exhausted or network error');
  }

  static Future<double> getAssetPrice(String symbol) async {
    try {
      final response = await _makeApiRequest('/quote?symbol=$symbol');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currentPrice = data['c']?.toDouble();
        if (currentPrice != null && currentPrice > 0) {
          return currentPrice;
        }
      }

      // Fallback to mock data with variation
      await Future.delayed(const Duration(milliseconds: 500));
      final basePrice = _mockPrices[symbol] ?? 100.0;
      final variation = (Random().nextDouble() - 0.5) * 0.1; // ±5% variation
      return basePrice * (1 + variation);
    } catch (e) {
      print('Error fetching price for $symbol: $e');
      // Return mock price as fallback
      final basePrice = _mockPrices[symbol] ?? 100.0;
      final variation = (Random().nextDouble() - 0.5) * 0.1;
      return basePrice * (1 + variation);
    }
  }

  static Future<Map<String, double>> getMultipleAssetPrices(List<String> symbols) async {
    try {
      final Map<String, double> prices = {};

      for (String symbol in symbols) {
        try {
          final response = await _makeApiRequest('/quote?symbol=$symbol');

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final currentPrice = data['c']?.toDouble();
            if (currentPrice != null && currentPrice > 0) {
              prices[symbol] = currentPrice;
              continue;
            }
          }
        } catch (e) {
          print('Error fetching price for $symbol: $e');
        }

        // Fallback to mock price for this symbol
        final basePrice = _mockPrices[symbol] ?? 100.0;
        final variation = (Random().nextDouble() - 0.5) * 0.1;
        prices[symbol] = basePrice * (1 + variation);
      }

      return prices;
    } catch (e) {
      throw Exception('Failed to fetch multiple prices: $e');
    }
  }

  static Future<List<NewsArticle>> getFinancialNews() async {
    try {
      // Try to get real news from News API
      if (_newsApiKey != 'your_news_api_key_here') {
        final response = await http.get(
          Uri.parse('$_newsBaseUrl/everything?q=finance OR stock OR crypto OR investment&apiKey=$_newsApiKey&pageSize=10&sortBy=publishedAt'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final articles = (data['articles'] as List)
              .map((article) => NewsArticle.fromJson(article))
              .toList();
          return articles;
        }
      }

      // Try Finnhub market news as fallback
      try {
        final response = await _makeApiRequest('/news?category=general');
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          return data.map((article) => NewsArticle(
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
    } catch (e) {
      print('Error fetching news: $e');
      return _getMockNews();
    }
  }

  static List<NewsArticle> _getMockNews() {
    final random = Random();
    final baseNews = [
      {
        'title': 'Stock Market Reaches New Heights Amid Economic Recovery',
        'description': 'Major indices continue their upward trajectory as investors remain optimistic about economic growth prospects.',
        'source': 'Financial Times',
      },
      {
        'title': 'Bitcoin Surges Past \$45,000 as Institutional Adoption Grows',
        'description': 'Cryptocurrency markets see renewed interest from institutional investors, driving Bitcoin to new monthly highs.',
        'source': 'CoinDesk',
      },
      {
        'title': 'Tech Stocks Lead Market Rally on AI Innovation News',
        'description': 'Technology companies see significant gains following announcements of breakthrough AI developments.',
        'source': 'TechCrunch',
      },
      {
        'title': 'Federal Reserve Signals Potential Interest Rate Changes',
        'description': 'Central bank officials hint at policy adjustments in response to current economic indicators.',
        'source': 'Reuters',
      },
      {
        'title': 'Green Energy Stocks Soar on New Climate Initiatives',
        'description': 'Renewable energy companies experience significant growth following new government climate policies.',
        'source': 'Bloomberg',
      },
    ];

    return baseNews.asMap().entries.map((entry) {
      final index = entry.key;
      final news = entry.value;

      return NewsArticle(
        id: '${DateTime.now().millisecondsSinceEpoch}_$index',
        title: news['title']!,
        description: news['description']!,
        url: 'https://example.com/news/$index',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: news['source']!,
        publishedAt: DateTime.now().subtract(Duration(hours: random.nextInt(24))),
      );
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> searchAssets(String query) async {
    try {
      final response = await _makeApiRequest('/search?q=$query');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['result'] as List?;

        if (results != null) {
          return results.map((result) => {
            'symbol': result['symbol'] as String,
            'name': result['description'] as String,
            'type': result['type'] == 'Common Stock' ? 'stock' : 'other',
          }).toList();
        }
      }

      // Fallback to mock search results
      final allAssets = [
        {'symbol': 'AAPL', 'name': 'Apple Inc.', 'type': 'stock'},
        {'symbol': 'GOOGL', 'name': 'Alphabet Inc.', 'type': 'stock'},
        {'symbol': 'MSFT', 'name': 'Microsoft Corporation', 'type': 'stock'},
        {'symbol': 'TSLA', 'name': 'Tesla, Inc.', 'type': 'stock'},
        {'symbol': 'AMZN', 'name': 'Amazon.com, Inc.', 'type': 'stock'},
        {'symbol': 'BTC', 'name': 'Bitcoin', 'type': 'crypto'},
        {'symbol': 'ETH', 'name': 'Ethereum', 'type': 'crypto'},
        {'symbol': 'ADA', 'name': 'Cardano', 'type': 'crypto'},
        {'symbol': 'DOT', 'name': 'Polkadot', 'type': 'crypto'},
        {'symbol': 'SOL', 'name': 'Solana', 'type': 'crypto'},
      ];

      return allAssets
          .where((asset) =>
      asset['symbol']!.toLowerCase().contains(query.toLowerCase()) ||
          asset['name']!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      throw Exception('Failed to search assets: $e');
    }
  }

  // Get company profile (additional Finnhub feature)
  static Future<Map<String, dynamic>?> getCompanyProfile(String symbol) async {
    try {
      final response = await _makeApiRequest('/stock/profile2?symbol=$symbol');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching company profile for $symbol: $e');
      return null;
    }
  }

  // Get market news (Finnhub market news)
  static Future<List<Map<String, dynamic>>> getMarketNews() async {
    try {
      final response = await _makeApiRequest('/news?category=general');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching market news: $e');
      return [];
    }
  }
}
