import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/portfolio_provider.dart';
import '../providers/auth_provider.dart';
import '../models/asset.dart';
import '../utils/theme.dart';
import '../widgets/portfolio_summary_card.dart';
import '../widgets/asset_list_item.dart';
import '../widgets/add_asset_dialog.dart';
import '../widgets/portfolio_chart.dart';
import '../widgets/sell_asset_dialog.dart';
import 'wallet_screen.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  double _walletBalance = 0.0;
  bool _isLoadingWallet = true;
  StreamSubscription<DocumentSnapshot>? _walletSubscription; // Added for real-time updates

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
    _setupWalletListener(); // Added real-time listener
  }

  @override
  void dispose() {
    _walletSubscription?.cancel(); // Clean up subscription
    super.dispose();
  }

  // Added real-time wallet balance listener
  void _setupWalletListener() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userUid == null) return;

    _walletSubscription = FirebaseFirestore.instance
        .collection('wallets')
        .doc(authProvider.userUid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _walletBalance = (snapshot.data()?['balance'] ?? 0.0).toDouble();
          _isLoadingWallet = false;
        });
      } else if (mounted) {
        setState(() {
          _walletBalance = 0.0;
          _isLoadingWallet = false;
        });
      }
    });
  }

  Future<void> _loadWalletBalance() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userUid == null) return;

    try {
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(authProvider.userUid)
          .get();

      if (walletDoc.exists && mounted) {
        setState(() {
          _walletBalance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();
          _isLoadingWallet = false;
        });
      } else if (mounted) {
        setState(() {
          _walletBalance = 0.0;
          _isLoadingWallet = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _walletBalance = 0.0;
          _isLoadingWallet = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    } else {
      return '\$${amount.toStringAsFixed(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Portfolio', style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: Theme.of(context).colorScheme.surface,
            leading: _buildWalletBalance(),
            leadingWidth: 140,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => context.read<PortfolioProvider>().refreshPortfolio(),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add_rounded),
                  color: Theme.of(context).colorScheme.onPrimary,
                  onPressed: () => _showAddAssetDialog(context),
                ),
              ),
            ],
          ),
          Consumer<PortfolioProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.assets.isEmpty) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              return provider.assets.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState(context))
                  : _buildPortfolioContent(provider);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWalletBalance() => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
    child: Container(
      margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: _isLoadingWallet
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            )
                : Text(
              _formatCurrency(_walletBalance),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildPortfolioContent(PortfolioProvider provider) => SliverPadding(
    padding: const EdgeInsets.all(20),
    sliver: SliverList(
      delegate: SliverChildListDelegate([
        PortfolioSummaryCard(
          totalValue: provider.totalValue,
          totalInvested: provider.totalInvested,
          totalGainLoss: provider.totalGainLoss,
          totalGainLossPercent: provider.totalGainLossPercent,
        ),
        const SizedBox(height: 24),
        if (provider.assets.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asset Allocation', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                PortfolioChart(assetAllocation: provider.assetAllocation),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
        Text('Your Assets', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ...provider.assets.map((asset) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: AssetListItem(
            asset: asset,
            onTap: () => _showAssetDetails(context, asset),
            onDelete: () => _deleteAsset(context, asset),
          ),
        )),
      ]),
    ),
  );

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.pie_chart_outline_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text('No Assets Yet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            'Add your first investment to start tracking your portfolio',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _showAddAssetDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Asset'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    ),
  );

  void _showAddAssetDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const AddAssetDialog());
  }

  void _showAssetDetails(BuildContext context, Asset asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssetDetailsSheet(asset: asset),
    );
  }

  void _deleteAsset(BuildContext context, Asset asset) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Asset'),
        content: Text('Remove ${asset.name} from your portfolio?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<PortfolioProvider>().removeAsset(asset.id);
              Navigator.pop(context);
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

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    } else {
      return '\$${amount.toStringAsFixed(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildHeader(context),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  _buildDetailCard(context, 'Current Value', _formatCurrency(asset.totalValue),
                      asset.totalGainLoss >= 0 ? AppTheme.primaryGreen : AppTheme.primaryRed),
                  const SizedBox(height: 16),
                  _buildDetailCard(context, 'Total Invested', _formatCurrency(asset.totalInvested),
                      Theme.of(context).colorScheme.onSurface),
                  const SizedBox(height: 16),
                  _buildDetailCard(context, 'Gain/Loss',
                      '${asset.totalGainLoss >= 0 ? '+' : ''}${_formatCurrency(asset.totalGainLoss)} (${asset.totalGainLossPercent.toStringAsFixed(2)}%)',
                      asset.totalGainLoss >= 0 ? AppTheme.primaryGreen : AppTheme.primaryRed),
                  const SizedBox(height: 24),
                  _buildHoldingsCard(context),
                  const SizedBox(height: 24),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(asset.type.icon, style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(asset.symbol, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(asset.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              )),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildHoldingsCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Holdings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        ...([
          ('Quantity', '${asset.quantity}'),
          ('Buy Price', _formatCurrency(asset.buyPrice)),
          ('Current Price', _formatCurrency(asset.currentPrice)),
          ('Purchase Date', _formatDate(asset.purchaseDate)),
        ].map((item) => _buildInfoRow(context, item.$1, item.$2))),
      ],
    ),
  );

  Widget _buildActionButtons(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            showDialog(context: context, builder: (_) => SellAssetDialog(asset: asset));
          },
          icon: const Icon(Icons.trending_down_rounded),
          label: const Text('Sell'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            showDialog(context: context, builder: (_) => const AddAssetDialog());
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Buy More'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ],
  );

  Widget _buildDetailCard(BuildContext context, String title, String value, Color color) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        )),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        )),
      ],
    ),
  );

  Widget _buildInfoRow(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        )),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}