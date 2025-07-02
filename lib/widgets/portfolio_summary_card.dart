import 'package:flutter/material.dart';
import '../utils/theme.dart';

class PortfolioSummaryCard extends StatelessWidget {
  final double totalValue;
  final double totalInvested;
  final double totalGainLoss;
  final double totalGainLossPercent;

  const PortfolioSummaryCard({
    super.key,
    required this.totalValue,
    required this.totalInvested,
    required this.totalGainLoss,
    required this.totalGainLossPercent,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = totalGainLoss >= 0;
    final gainLossColor = isPositive ? AppTheme.primaryGreen : AppTheme.primaryRed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Portfolio Value',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${totalValue.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    context,
                    'Invested',
                    '\$${totalInvested.toStringAsFixed(2)}',
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetric(
                    context,
                    'Gain/Loss',
                    '${isPositive ? '+' : ''}\$${totalGainLoss.toStringAsFixed(2)} (${totalGainLossPercent.toStringAsFixed(2)}%)',
                    gainLossColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
