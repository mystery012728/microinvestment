import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../services/real_time_api_service.dart';

class AddWatchlistDialog extends StatefulWidget {
  const AddWatchlistDialog({super.key});

  @override
  State<AddWatchlistDialog> createState() => _AddWatchlistDialogState();
}

class _AddWatchlistDialogState extends State<AddWatchlistDialog> {
  final _searchController = TextEditingController();

  bool _isSearching = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _selectedType = 'all';
  String? _error;
  final Map<String, double> _cachedPrices = {};

  final List<Map<String, String>> _assetTypes = [
    {'value': 'all', 'label': 'All Assets'},
    {'value': 'stock', 'label': 'Stocks'},
    {'value': 'crypto', 'label': 'Crypto'},
    {'value': 'etf', 'label': 'ETFs'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAssets(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await RealTimeApiService.searchAssets(query);

      // Filter by selected type
      final filteredResults = _selectedType == 'all'
          ? results
          : results.where((asset) => asset['type'] == _selectedType).toList();

      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });

      // Fetch prices for search results
      _fetchPricesForResults(filteredResults);
    } catch (e) {
      setState(() {
        _error = 'Search failed: ${e.toString()}';
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _fetchPricesForResults(List<Map<String, dynamic>> results) async {
    final symbols = results.map((asset) => asset['symbol'] as String).toList();

    try {
      final prices = await RealTimeApiService.getMultipleAssetPrices(symbols);
      setState(() {
        _cachedPrices.addAll(prices);
      });
    } catch (e) {
      print('Failed to fetch prices: $e');
    }
  }

  Future<void> _addToWatchlist(Map<String, dynamic> asset) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);

      // Get current price
      double currentPrice = _cachedPrices[asset['symbol']] ?? 0.0;

      if (currentPrice == 0.0) {
        // Fetch price if not cached
        final symbol = asset['symbol'] as String;
        if (asset['type'] == 'crypto') {
          currentPrice = await RealTimeApiService.getCryptoPrice(symbol);
        } else if (asset['market'] == 'NSE') {
          currentPrice = await RealTimeApiService.getIndianStockPrice(symbol);
        } else {
          currentPrice = await RealTimeApiService.getUSStockPrice(symbol);
        }
      }

      await watchlistProvider.addToWatchlist(
        asset['symbol'] as String,
        asset['name'] as String,
        asset['type'] as String,
        currentPrice,
        asset['market'] as String,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${asset['symbol']} added to watchlist'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to watchlist screen
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildSearchSuggestions() {
    final suggestions = [
      {'symbol': 'AAPL', 'name': 'Apple Inc.', 'type': 'stock'},
      {'symbol': 'BTC', 'name': 'Bitcoin', 'type': 'crypto'},
      {'symbol': 'GOOGL', 'name': 'Alphabet Inc.', 'type': 'stock'},
      {'symbol': 'ETH', 'name': 'Ethereum', 'type': 'crypto'},
      {'symbol': 'RELIANCE', 'name': 'Reliance Industries', 'type': 'stock'},
      {'symbol': 'SPY', 'name': 'S&P 500 ETF', 'type': 'etf'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Assets',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((suggestion) {
            return ActionChip(
              label: Text(suggestion['symbol']!),
              onPressed: () {
                _searchController.text = suggestion['symbol']!;
                _searchAssets(suggestion['symbol']!);
              },
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAssetTile(Map<String, dynamic> asset) {
    final symbol = asset['symbol'] as String;
    final price = _cachedPrices[symbol];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getAssetColor(asset['type']).withOpacity(0.2),
          child: Text(
            symbol.substring(0, 2),
            style: TextStyle(
              color: _getAssetColor(asset['type']),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                symbol,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (price != null)
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              asset['name'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getAssetColor(asset['type']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (asset['type'] as String).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getAssetColor(asset['type']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  asset['market'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => _addToWatchlist(asset),
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Color _getAssetColor(String? type) {
    switch (type) {
      case 'crypto':
        return Colors.orange;
      case 'etf':
        return Colors.purple;
      case 'stock':
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight - 100;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: availableHeight * 0.85, // Use 85% of available height
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            // Fixed Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.visibility,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add to Watchlist',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Track your favorite assets',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search assets (e.g., AAPL, Bitcoin, SPY)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onChanged: (value) {
                      if (value.length >= 2) {
                        _searchAssets(value);
                      } else {
                        setState(() {
                          _searchResults = [];
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  // Asset Type Filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _assetTypes.map((type) {
                        final isSelected = _selectedType == type['value'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(type['label']!),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedType = type['value'];
                              });
                              if (_searchController.text.isNotEmpty) {
                                _searchAssets(_searchController.text);
                              }
                            },
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Error Message
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Search Results or Suggestions
                    Expanded(
                      child: _searchResults.isNotEmpty
                          ? ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          return _buildAssetTile(_searchResults[index]);
                        },
                      )
                          : _searchController.text.isEmpty
                          ? SingleChildScrollView(
                        child: _buildSearchSuggestions(),
                      )
                          : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No assets found',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try searching with different keywords',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
