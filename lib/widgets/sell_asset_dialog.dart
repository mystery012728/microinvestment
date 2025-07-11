import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/asset.dart';
import '../providers/portfolio_provider.dart';
import '../providers/auth_provider.dart';
import '../services/real_time_api_service.dart';

class SellAssetDialog extends StatefulWidget {
  final Asset asset;
  const SellAssetDialog({super.key, required this.asset});

  @override
  State<SellAssetDialog> createState() => _SellAssetDialogState();
}

class _SellAssetDialogState extends State<SellAssetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  bool _isLoading = false;
  double? _currentPrice;
  bool _sellAll = false;
  double _walletBalance = 0.0; // Added wallet balance variable

  @override
  void initState() {
    super.initState();
    _getCurrentPrice();
    _loadWalletBalance(); // Added wallet balance loading
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // Added wallet balance loading method
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
        });
      } else if (mounted) {
        // Create wallet document if it doesn't exist
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(authProvider.userUid)
            .set({'balance': 0.0, 'createdAt': FieldValue.serverTimestamp()});
        setState(() {
          _walletBalance = 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _walletBalance = 0.0;
        });
      }
    }
  }

  Future<void> _getCurrentPrice() async {
    setState(() => _isLoading = true);
    try {
      // Re-added crypto-specific price fetching
      final price = widget.asset.type == AssetType.crypto
          ? await RealTimeApiService.getCryptoPrice(widget.asset.symbol)
          : await RealTimeApiService.getUSStockPrice(widget.asset.symbol);
      setState(() {
        _currentPrice = price;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _currentPrice = widget.asset.currentPrice;
        _isLoading = false;
      });
    }
  }

  double get _saleAmount {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    return quantity * (_currentPrice ?? 0);
  }

  double get _profitLoss {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    return _saleAmount - (quantity * widget.asset.buyPrice);
  }

  // Added wallet balance display widget
  Widget _buildWalletBalance() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wallet Balance',
                  style: Theme.of(context).textTheme.bodyMedium),
              Text('\$${_walletBalance.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _storeSellDetails(double quantity, double saleAmount, double profitLoss) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userUid == null) return;

    await FirebaseFirestore.instance.collection('sell_details').add({
      'userId': authProvider.userUid,
      'assetId': widget.asset.id,
      'symbol': widget.asset.symbol,
      'name': widget.asset.name,
      'type': widget.asset.type.toString(),
      'quantitySold': quantity,
      'sellPrice': _currentPrice,
      'buyPrice': widget.asset.buyPrice,
      'saleAmount': saleAmount,
      'profitLoss': profitLoss,
      'sellDate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateWalletBalance(double amount) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userUid == null) return;

    try {
      // Update wallet balance in Firestore
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(authProvider.userUid)
          .update({
        'balance': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update local state immediately for UI responsiveness
      if (mounted) {
        setState(() {
          _walletBalance += amount;
        });
      }
    } catch (e) {
      // If wallet document doesn't exist, create it
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(authProvider.userUid)
          .set({
        'balance': amount,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _walletBalance = amount;
        });
      }
    }
  }

  Future<void> _sellAsset() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.userUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to sell assets'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final quantityToSell = double.parse(_quantityController.text);
      final saleAmount = _saleAmount;
      final profitLoss = _profitLoss;

      // Store sell details in Firebase
      await _storeSellDetails(quantityToSell, saleAmount, profitLoss);

      // Update wallet balance with sale amount in Firestore
      await _updateWalletBalance(saleAmount);

      if (mounted) {
        await context.read<PortfolioProvider>().sellAsset(
          widget.asset.id,
          quantityToSell,
          _currentPrice!,
        );
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sold ${quantityToSell} shares of ${widget.asset.symbol} for \$${saleAmount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View Wallet',
              onPressed: () {
                // Navigate to wallet screen
                Navigator.of(context).pushNamed('/wallet');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sell asset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700), // Increased height
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.trending_down, color: Colors.red, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sell ${widget.asset.symbol}',
                              style: Theme.of(context).textTheme.headlineSmall),
                          Text(widget.asset.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Added Wallet Balance Display
                _buildWalletBalance(),
                const SizedBox(height: 16),
                // Current Holdings
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Current Holdings:',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('${widget.asset.quantity} shares',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Current Price:',
                              style: Theme.of(context).textTheme.bodyMedium),
                          Text(_currentPrice != null
                              ? '\$${_currentPrice!.toStringAsFixed(2)}'
                              : 'Loading...',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Sell All Toggle
                CheckboxListTile(
                  title: const Text('Sell All Holdings'),
                  value: _sellAll,
                  onChanged: (value) {
                    setState(() {
                      _sellAll = value ?? false;
                      _quantityController.text = _sellAll
                          ? widget.asset.quantity.toString()
                          : '';
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                // Quantity to Sell
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity to Sell',
                    hintText: 'Enter number of shares to sell',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.remove_circle_outline),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  enabled: !_sellAll,
                  onChanged: (value) => setState(() {}), // Added to trigger rebuild
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity to sell';
                    }
                    final quantity = double.tryParse(value);
                    if (quantity == null || quantity <= 0) {
                      return 'Please enter a valid quantity';
                    }
                    if (quantity > widget.asset.quantity) {
                      return 'Cannot sell more than you own (${widget.asset.quantity})';
                    }
                    return null;
                  },
                ),
                // Sale Summary
                if (_currentPrice != null && _quantityController.text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Sale Amount:',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('\$${_saleAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Profit/Loss:',
                                style: Theme.of(context).textTheme.bodyMedium),
                            Text(
                              '${_profitLoss >= 0 ? '+' : ''}\$${_profitLoss.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: _profitLoss >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('New Wallet Balance:',
                                style: Theme.of(context).textTheme.bodyMedium),
                            Text(
                              '\$${(_walletBalance + _saleAmount).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading || _currentPrice == null ? null : _sellAsset,
                      icon: _isLoading
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.sell),
                      label: const Text('Sell Asset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
