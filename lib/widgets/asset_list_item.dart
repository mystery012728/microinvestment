import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../utils/theme.dart';

class AssetListItem extends StatelessWidget {
  final Asset asset;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AssetListItem({
    super.key,
    required this.asset,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = asset.totalGainLoss >= 0;
    final gainLossColor = isPositive ? AppTheme.primaryGreen : AppTheme.primaryRed;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            asset.type.icon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          asset.symbol,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(asset.name),
            const SizedBox(height: 4),
            Text(
              '${asset.quantity} shares @ \$${asset.buyPrice.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\$${asset.totalValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${isPositive ? '+' : ''}\$${asset.totalGainLoss.toStringAsFixed(2)}',
              style: TextStyle(
                color: gainLossColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            Text(
              '${isPositive ? '+' : ''}${asset.totalGainLossPercent.toStringAsFixed(2)}%',
              style: TextStyle(
                color: gainLossColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
