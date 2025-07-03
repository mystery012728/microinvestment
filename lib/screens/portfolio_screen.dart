import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../models/asset.dart';
import '../utils/theme.dart';
import '../widgets/portfolio_summary_card.dart';
import '../widgets/asset_list_item.dart';
import '../widgets/add_asset_dialog.dart';
import '../widgets/portfolio_chart.dart';
import '../widgets/sell_asset_dialog.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PortfolioProvider>().refreshPortfolio();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddAssetDialog(context);
            },
          ),
        ],
      ),
      body: Consumer<PortfolioProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.assets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.assets.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: provider.refreshPortfolio,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Portfolio Summary
                  PortfolioSummaryCard(
                    totalValue: provider.totalValue,
                    totalInvested: provider.totalInvested,
                    totalGainLoss: provider.totalGainLoss,
                    totalGainLossPercent: provider.totalGainLossPercent,
                  ),
                  const SizedBox(height: 24),

                  // Portfolio Chart
                  if (provider.assets.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asset Allocation',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            PortfolioChart(
                              assetAllocation: provider.assetAllocation,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Assets List
                  Text(
                    'Your Assets',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Assets List with proper spacing
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.assets.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final asset = provider.assets[index];
                      return AssetListItem(
                        asset: asset,
                        onTap: () => _showAssetDetails(context, asset),
                        onDelete: () => _deleteAsset(context, asset),
                      );
                    },
                  ),

                  // Bottom padding to prevent overflow
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Assets Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first investment to start tracking your portfolio',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddAssetDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Asset'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAssetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddAssetDialog(),
    );
  }

  void _showAssetDetails(BuildContext context, Asset asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AssetDetailsSheet(asset: asset),
    );
  }

  void _deleteAsset(BuildContext context, Asset asset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Asset'),
        content: Text('Are you sure you want to remove ${asset.name} from your portfolio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<PortfolioProvider>().removeAsset(asset.id);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AssetDetailsSheet extends StatelessWidget {
  final Asset asset;

  const _AssetDetailsSheet({required this.asset});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        asset.type.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.symbol,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            asset.name,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Details
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildDetailCard(
                      context,
                      'Current Value',
                      '\$${asset.totalValue.toStringAsFixed(2)}',
                      asset.totalGainLoss >= 0 ? AppTheme.primaryGreen : AppTheme.primaryRed,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailCard(
                      context,
                      'Total Invested',
                      '\$${asset.totalInvested.toStringAsFixed(2)}',
                      Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailCard(
                      context,
                      'Gain/Loss',
                      '${asset.totalGainLoss >= 0 ? '+' : ''}\$${asset.totalGainLoss.toStringAsFixed(2)} (${asset.totalGainLossPercent.toStringAsFixed(2)}%)',
                      asset.totalGainLoss >= 0 ? AppTheme.primaryGreen : AppTheme.primaryRed,
                    ),
                    const SizedBox(height: 24),

                    // Holdings Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Holdings',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(context, 'Quantity', '${asset.quantity}'),
                            _buildInfoRow(context, 'Buy Price', '\$${asset.buyPrice.toStringAsFixed(2)}'),
                            _buildInfoRow(context, 'Current Price', '\$${asset.currentPrice.toStringAsFixed(2)}'),
                            _buildInfoRow(context, 'Purchase Date', _formatDate(asset.purchaseDate)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showSellDialog(context, asset);
                            },
                            icon: const Icon(Icons.trending_down),
                            label: const Text('Sell'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showAddMoreDialog(context, asset);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Buy More'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(BuildContext context, String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showSellDialog(BuildContext context, Asset asset) {
    showDialog(
      context: context,
      builder: (context) => SellAssetDialog(asset: asset),
    );
  }

  void _showAddMoreDialog(BuildContext context, Asset asset) {
    showDialog(
      context: context,
      builder: (context) => const AddAssetDialog(),
    );
  }
}
