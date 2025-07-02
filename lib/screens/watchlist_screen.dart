import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/watchlist_provider.dart';
import '../models/watchlist_item.dart';
import '../widgets/watchlist_item_card.dart';
import '../widgets/add_watchlist_dialog.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<WatchlistProvider>().refreshWatchlist();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddWatchlistDialog(context);
            },
          ),
        ],
      ),
      body: Consumer<WatchlistProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.items.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: provider.refreshWatchlist,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: provider.items.length,
              itemBuilder: (context, index) {
                final item = provider.items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: WatchlistItemCard(
                    item: item,
                    onSetAlert: (alertPrice, enabled) {
                      provider.setPriceAlert(item.id, alertPrice, enabled);
                    },
                    onRemove: () {
                      _showRemoveDialog(context, item, provider);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Assets in Watchlist',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add assets to track their prices and set alerts',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddWatchlistDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add to Watchlist'),
          ),
        ],
      ),
    );
  }

  void _showAddWatchlistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddWatchlistDialog(),
    );
  }

  void _showRemoveDialog(BuildContext context, WatchlistItem item, WatchlistProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Watchlist'),
        content: Text('Remove ${item.name} from your watchlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.removeFromWatchlist(item.id);
              Navigator.of(context).pop();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
