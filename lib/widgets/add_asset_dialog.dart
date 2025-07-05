import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset.dart';
import '../providers/portfolio_provider.dart';
import '../providers/auth_provider.dart';
import '../services/real_time_api_service.dart';

class AddAssetDialog extends StatefulWidget {
  const AddAssetDialog({super.key});

  @override
  State<AddAssetDialog> createState() => _AddAssetDialogState();
}

class _AddAssetDialogState extends State<AddAssetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _quantityController = TextEditingController();

  AssetType _selectedType = AssetType.stock;
  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _selectedAssetName;
  double? _currentPrice;
  String? _selectedMarket;
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletBalance() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userUid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userWalletKey = 'wallet_balance_${authProvider.userUid}';
    setState(() {
      _walletBalance = prefs.getDouble(userWalletKey) ?? 0.0;
    });
  }

  Future<void> _updateWalletBalance(double amount) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userUid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userWalletKey = 'wallet_balance_${authProvider.userUid}';
    setState(() {
      _walletBalance -= amount;
    });
    await prefs.setDouble(userWalletKey, _walletBalance);
  }

  double get _totalInvestment {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    return quantity * (_currentPrice ?? 0);
  }

  bool get _hasInsufficientBalance => _totalInvestment > _walletBalance;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWalletBalance(),
                      const SizedBox(height: 24),
                      _buildAssetTypeSelection(),
                      const SizedBox(height: 24),
                      _buildSymbolSearch(),
                      if (_searchResults.isNotEmpty) _buildSearchResults(),
                      if (_currentPrice != null) _buildPriceDisplay(),
                      const SizedBox(height: 24),
                      _buildQuantityInput(),
                      if (_currentPrice != null && _quantityController.text.isNotEmpty)
                        _buildTotalInvestment(),
                      const SizedBox(height: 32),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Icon(Icons.add_shopping_cart, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text('Add Asset', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletBalance() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wallet Balance', style: Theme.of(context).textTheme.bodyMedium),
              Text('\$${_walletBalance.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Asset Type', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SegmentedButton<AssetType>(
          segments: AssetType.values.map((type) => ButtonSegment<AssetType>(
            value: type,
            label: Text(type.displayName),
            icon: Text(type.icon),
          )).toList(),
          selected: {_selectedType},
          onSelectionChanged: (Set<AssetType> selection) {
            setState(() {
              _selectedType = selection.first;
              _resetSearch();
            });
          },
        ),
      ],
    );
  }

  Widget _buildSymbolSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Search Asset', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _symbolController,
          decoration: InputDecoration(
            labelText: 'Symbol or Company Name',
            hintText: _getHintText(),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : null,
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: _searchAssets,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter a symbol';
            if (_currentPrice == null) return 'Please select a valid asset';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) => ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(_getTypeIcon(_searchResults[index]['type']))),
          ),
          title: Text(_searchResults[index]['symbol']),
          subtitle: Text(_searchResults[index]['name']),
          onTap: () => _selectAsset(_searchResults[index]),
        ),
      ),
    );
  }

  Widget _buildPriceDisplay() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Price', style: Theme.of(context).textTheme.bodyMedium),
                    Text('\$${_currentPrice!.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _quantityController,
          decoration: const InputDecoration(
            labelText: 'Number of shares/units',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.numbers),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          onChanged: (value) => setState(() {}),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter quantity';
            final quantity = double.tryParse(value);
            if (quantity == null || quantity <= 0) return 'Please enter a valid quantity';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTotalInvestment() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _hasInsufficientBalance ? Colors.red.withOpacity(0.1) : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasInsufficientBalance ? Colors.red : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Investment:', style: Theme.of(context).textTheme.bodyMedium),
              Text('\$${_totalInvestment.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          if (_hasInsufficientBalance) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Insufficient balance to buy this asset',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isLoading || _currentPrice == null || _hasInsufficientBalance ? null : _addAsset,
            icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator()) : const Icon(Icons.shopping_cart),
            label: Text(_isLoading ? 'Processing...' : 'Buy Asset'),
          ),
        ),
      ],
    );
  }

  String _getHintText() {
    switch (_selectedType) {
      case AssetType.stock: return 'e.g., AAPL, RELIANCE';
      case AssetType.crypto: return 'e.g., BTC, ETH';
      case AssetType.etf: return 'e.g., SPY, QQQ';
    }
  }

  String _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'crypto': return '₿';
      case 'stock': return '📈';
      case 'etf': return '📊';
      default: return '💰';
    }
  }

  void _resetSearch() {
    setState(() {
      _searchResults.clear();
      _selectedAssetName = null;
      _currentPrice = null;
      _selectedMarket = null;
      _symbolController.clear();
    });
  }

  Future<void> _searchAssets(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults.clear();
        _currentPrice = null;
        _selectedAssetName = null;
        _selectedMarket = null;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await RealTimeApiService.searchAssets(query);
      setState(() {
        _searchResults = results.where((result) => _isValidAssetType(result['type'])).take(10).toList();
      });
    } catch (e) {
      setState(() => _searchResults.clear());
      _showSnackBar('Search failed: $e', isError: true);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  bool _isValidAssetType(String type) {
    return type == _selectedType.name || (_selectedType == AssetType.stock && type == 'etf');
  }

  Future<void> _selectAsset(Map<String, dynamic> asset) async {
    setState(() {
      _symbolController.text = asset['symbol'];
      _selectedAssetName = asset['name'];
      _selectedMarket = asset['market'];
      _searchResults.clear();
      _isLoading = true;
    });

    try {
      final price = await _fetchAssetPrice(asset);
      setState(() => _currentPrice = price);
    } catch (e) {
      setState(() => _currentPrice = null);
      _showSnackBar('Failed to fetch price: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<double> _fetchAssetPrice(Map<String, dynamic> asset) async {
    final symbol = asset['symbol'];
    final market = asset['market'];
    final type = asset['type'];

    if (market == 'NSE' || market == 'BSE') {
      return await RealTimeApiService.getIndianStockPrice(symbol);
    } else if (type == 'crypto') {
      return await RealTimeApiService.getCryptoPrice(symbol);
    } else {
      return await RealTimeApiService.getUSStockPrice(symbol);
    }
  }

  Future<void> _addAsset() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.userUid == null) {
      _showSnackBar('Please log in to add assets', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final asset = Asset(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        symbol: _symbolController.text.toUpperCase(),
        name: _selectedAssetName ?? _symbolController.text.toUpperCase(),
        type: _selectedType,
        quantity: double.parse(_quantityController.text),
        buyPrice: _currentPrice!,
        currentPrice: _currentPrice!,
        purchaseDate: DateTime.now(),
      );

      // Store in Firebase with user UID
      await FirebaseFirestore.instance.collection('buy_details').add({
        'userId': authProvider.userUid,
        'asset_id': asset.id,
        'symbol': asset.symbol,
        'name': asset.name,
        'type': asset.type.name,
        'quantity': asset.quantity,
        'buy_price': asset.buyPrice,
        'total_investment': _totalInvestment,
        'market': _selectedMarket,
        'purchase_date': asset.purchaseDate,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update wallet balance
      await _updateWalletBalance(_totalInvestment);

      // Add to portfolio
      if (mounted) {
        await context.read<PortfolioProvider>().addAsset(asset);
        Navigator.of(context).pop();
        _showSnackBar('${asset.symbol} purchased successfully!', isError: false);
      }
    } catch (e) {
      _showSnackBar('Failed to purchase asset: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
