import 'dart:math';

import '../models/news_article.dart';

class ApiService {
// Replace with actual key

  // Mock data for demonstration
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

  static Future<double> getAssetPrice(String symbol) async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Return mock price with some random variation
      final basePrice = _mockPrices[symbol] ?? 100.0;
      final variation = (Random().nextDouble() - 0.5) * 0.1; // ±5% variation
      return basePrice * (1 + variation);
    } catch (e) {
      throw Exception('Failed to fetch price for $symbol: $e');
    }
  }

  static Future<Map<String, double>> getMultipleAssetPrices(List<String> symbols) async {
    try {
      final Map<String, double> prices = {};
      
      for (String symbol in symbols) {
        prices[symbol] = await getAssetPrice(symbol);
      }
      
      return prices;
    } catch (e) {
      throw Exception('Failed to fetch multiple prices: $e');
    }
  }

  static Future<List<NewsArticle>> getFinancialNews() async {
    try {
      // Mock news data for demonstration
      return _getMockNews();
      
      // Uncomment below for real API integration
      /*
      final response = await http.get(
        Uri.parse('$_newsBaseUrl/everything?q=finance OR stock OR crypto&apiKey=$_newsApiKey&pageSize=20'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = (data['articles'] as List)
            .map((article) => NewsArticle.fromJson(article))
            .toList();
        return articles;
      } else {
        throw Exception('Failed to load news');
      }
      */
    } catch (e) {
      throw Exception('Failed to fetch news: $e');
    }
  }

  static List<NewsArticle> _getMockNews() {
    return [
      NewsArticle(
        id: '1',
        title: 'Stock Market Reaches New Heights Amid Economic Recovery',
        description: 'Major indices continue their upward trajectory as investors remain optimistic about economic growth prospects.',
        url: 'https://example.com/news/1',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Financial Times',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NewsArticle(
        id: '2',
        title: 'Bitcoin Surges Past \$45,000 as Institutional Adoption Grows',
        description: 'Cryptocurrency markets see renewed interest from institutional investors, driving Bitcoin to new monthly highs.',
        url: 'https://example.com/news/2',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'CoinDesk',
        publishedAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      NewsArticle(
        id: '3',
        title: 'Tech Stocks Lead Market Rally on AI Innovation News',
        description: 'Technology companies see significant gains following announcements of breakthrough AI developments.',
        url: 'https://example.com/news/3',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'TechCrunch',
        publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      NewsArticle(
        id: '4',
        title: 'Federal Reserve Signals Potential Interest Rate Changes',
        description: 'Central bank officials hint at policy adjustments in response to current economic indicators.',
        url: 'https://example.com/news/4',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Reuters',
        publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      NewsArticle(
        id: '5',
        title: 'Green Energy Stocks Soar on New Climate Initiatives',
        description: 'Renewable energy companies experience significant growth following new government climate policies.',
        url: 'https://example.com/news/5',
        imageUrl: '/placeholder.svg?height=200&width=300',
        source: 'Bloomberg',
        publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ];
  }

  static Future<List<Map<String, dynamic>>> searchAssets(String query) async {
    try {
      // Mock search results
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
}
