import 'package:flutter/material.dart';
import '../models/watchlist_item.dart';
import '../utils/theme.dart';

class WatchlistItemCard extends StatefulWidget {
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
  State<WatchlistItemCard> createState() => _WatchlistItemCardState();
}

class _WatchlistItemCardState extends State<WatchlistItemCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late TextEditingController _alertController;
  late bool _alertEnabled;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _alertController = TextEditingController(
      text: widget.item.alertPrice?.toStringAsFixed(2) ?? '',
    );
    _alertEnabled = widget.item.alertEnabled;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _alertController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.item.priceChange >= 0;
    final changeColor = isPositive ? AppTheme.primaryGreen : AppTheme.primaryRed;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_getTypeIcon(widget.item.type),
                  style: const TextStyle(fontSize: 20)),
            ),
            title: Text(widget.item.symbol,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item.name),
                if (widget.item.alertEnabled && widget.item.alertPrice != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.notifications_active, size: 14,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text('Alert: \$${widget.item.alertPrice!.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ],
              ],
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('\$${widget.item.currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text('${isPositive ? '+' : ''}\$${widget.item.priceChange.toStringAsFixed(2)}',
                    style: TextStyle(color: changeColor, fontWeight: FontWeight.w500, fontSize: 12)),
                Text('${isPositive ? '+' : ''}${widget.item.priceChangePercent.toStringAsFixed(2)}%',
                    style: TextStyle(color: changeColor, fontWeight: FontWeight.w500, fontSize: 12)),
              ],
            ),
            onTap: _toggleExpansion,
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Price Alert'),
                      value: _alertEnabled,
                      onChanged: (value) => setState(() => _alertEnabled = value),
                    ),
                    if (_alertEnabled) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _alertController,
                        decoration: const InputDecoration(
                          labelText: 'Alert Price (\$)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onRemove,
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Remove'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final alertPrice = _alertEnabled ?
                              double.tryParse(_alertController.text) ?? 0.0 : 0.0;
                              widget.onSetAlert(alertPrice, _alertEnabled);
                              _toggleExpansion();
                            },
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'crypto': return '₿';
      case 'stock': return '📈';
      case 'etf': return '📊';
      default: return '💰';
    }
  }
}