import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../services/api_service.dart';

class AddWatchlistDialog extends StatefulWidget {
  const AddWatchlistDialog({super.key});

  @override
  State<AddWatchlistDialog> createState() => _AddWatchlistDialogState();
}

class _AddWatchlistDialogState extends State<AddWatchlistDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to Watchlist',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),

              // Search Field
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Assets',
                  hintText: 'Enter symbol or name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _searchAssets,
              ),
              const SizedBox(height: 16),

              // Search Results
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return ListTile(
                        leading: Text(
                          _getTypeIcon(result['type']),
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(result['symbol']),
                        subtitle: Text(result['name']),
                        trailing: const Icon(Icons.add),
                        onTap: () => _addToWatchlist(result),
                      );
                    },
                  ),
                )
              else if (_searchController.text.isNotEmpty)
                const Expanded(
                  child: Center(
                    child: Text('No results found'),
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Text('Start typing to search for assets'),
                  ),
                ),

              // Close Button
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchAssets(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await ApiService.searchAssets(query);
      setState(() {
        _searchResults = results.take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults.clear();
        _isLoading = false;
      });
    }
  }

  String _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'crypto':
        return '₿';
      case 'stock':
        return '📈';
      case 'etf':
        return '📊';
      default:
        return '💰';
    }
  }

  Future<void> _addToWatchlist(Map<String, dynamic> asset) async {
    try {
      await context.read<WatchlistProvider>().addToWatchlist(
        asset['symbol'],
        asset['name'],
        asset['type'],
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${asset['symbol']} added to watchlist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to watchlist: $e')),
        );
      }
    }
  }
}
