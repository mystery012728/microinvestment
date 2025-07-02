import 'package:flutter/material.dart';
import '../models/watchlist_item.dart';
import '../utils/theme.dart';

class WatchlistItemCard extends StatelessWidget {
  final WatchlistItem item;
  final Function(double, bool) onSetAlert;
  final VoidCallback onRemove;

  const WatchlistItemCard({
    super.key,
    required this.item,
    required this.onSetAlert,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = item.priceChange >= 0;
    final changeColor = isPositive ? AppTheme.primaryGreen : AppTheme.primaryRed;

    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getTypeIcon(item.type),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          item.symbol,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name),
            if (item.alertEnabled && item.alertPrice != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.notifications_active,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Alert: \$${item.alertPrice!.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\$${item.currentPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${isPositive ? '+' : ''}\$${item.priceChange.toStringAsFixed(2)}',
              style: TextStyle(
                color: changeColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            Text(
              '${isPositive ? '+' : ''}${item.priceChangePercent.toStringAsFixed(2)}%',
              style: TextStyle(
                color: changeColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () => _showOptionsBottomSheet(context),
      ),
    );
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

  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Set Price Alert'),
              onTap: () {
                Navigator.of(context).pop();
                _showPriceAlertDialog(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Remove from Watchlist',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onRemove();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceAlertDialog(BuildContext context) {
    final alertController = TextEditingController(
      text: item.alertPrice?.toStringAsFixed(2) ?? '',
    );
    bool alertEnabled = item.alertEnabled;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Price Alert for ${item.symbol}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Enable Alert'),
                value: alertEnabled,
                onChanged: (value) {
                  setState(() {
                    alertEnabled = value;
                  });
                },
              ),
              if (alertEnabled) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: alertController,
                  decoration: const InputDecoration(
                    labelText: 'Alert Price (\$)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final alertPrice = alertEnabled 
                    ? double.tryParse(alertController.text) ?? 0.0
                    : 0.0;
                onSetAlert(alertPrice, alertEnabled);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
