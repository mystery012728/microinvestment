import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../providers/portfolio_provider.dart';
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
  final _scrollController = ScrollController();

  AssetType _selectedType = AssetType.stock;
  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _selectedAssetName;
  double? _currentPrice;
  String? _selectedMarket;

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxHeight = screenHeight * 0.9;
    final maxWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.95;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: maxWidth,
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 16),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_shopping_cart,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Add Asset',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asset Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<AssetType>(
            segments: AssetType.values.map((type) => ButtonSegment<AssetType>(
              value: type,
              label: FittedBox(
                child: Text(type.displayName, style: const TextStyle(fontSize: 12)),
              ),
              icon: Text(type.icon, style: const TextStyle(fontSize: 16)),
            )).toList(),
            selected: {_selectedType},
            onSelectionChanged: (Set<AssetType> selection) {
              setState(() {
                _selectedType = selection.first;
                _resetSearch();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search Asset',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _symbolController,
          decoration: InputDecoration(
            labelText: 'Symbol or Company Name',
            hintText: _getHintText(),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching ? const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ) : null,
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: _searchAssets,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a symbol';
            }
            if (_currentPrice == null) {
              return 'Please select a valid asset from search results';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Search Results',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _searchResults.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) => _buildSearchResultItem(_searchResults[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> result) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            _getTypeIcon(result['type']),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      title: Text(
        result['symbol'],
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result['name'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result['market'],
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                result['type'].toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _selectAsset(result),
    );
  }

  Widget _buildPriceDisplay() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Market Price',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_currentPrice!.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Asset will be purchased at current market price',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _quantityController,
          decoration: const InputDecoration(
            labelText: 'Number of shares/units',
            hintText: 'Enter quantity to purchase',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.numbers),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: (value) => setState(() {}),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter quantity';
            }
            final quantity = double.tryParse(value);
            if (quantity == null || quantity <= 0) {
              return 'Please enter a valid quantity';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTotalInvestment() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              _buildInvestmentRow('Price per unit:', '\$${_currentPrice!.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildInvestmentRow('Quantity:', _quantityController.text),
              const Divider(height: 20),
              _buildInvestmentRow(
                'Total Investment:',
                '\$${_calculateTotalInvestment().toStringAsFixed(2)}',
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvestmentRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontWeight: isTotal ? FontWeight.bold : null,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isTotal ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isLoading || _currentPrice == null ? null : _addAsset,
            icon: _isLoading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.shopping_cart),
            label: Text(_isLoading ? 'Processing...' : 'Buy Asset'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _getHintText() {
    switch (_selectedType) {
      case AssetType.stock:
        return 'e.g., AAPL, RELIANCE, TCS';
      case AssetType.crypto:
        return 'e.g., BTC, ETH, ADA';
      case AssetType.etf:
        return 'e.g., SPY, QQQ, VTI';
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

  double _calculateTotalInvestment() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    return quantity * (_currentPrice ?? 0);
  }

  void _resetSearch() {
    _searchResults.clear();
    _selectedAssetName = null;
    _currentPrice = null;
    _selectedMarket = null;
    _symbolController.clear();
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
        _searchResults = results
            .where((result) => _isValidAssetType(result['type']))
            .take(10)
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      _showErrorSnackBar('Search failed: $e');
    }
  }

  bool _isValidAssetType(String type) {
    return type == _selectedType.name ||
        (_selectedType == AssetType.crypto && type == 'crypto') ||
        (_selectedType == AssetType.stock && (type == 'stock' || type == 'etf'));
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
      setState(() {
        _currentPrice = price;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _currentPrice = null;
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to fetch price: $e');
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

      if (mounted) {
        await context.read<PortfolioProvider>().addAsset(asset);
        Navigator.of(context).pop();
        _showSuccessSnackBar(asset.symbol);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to purchase asset: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String symbol) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('$symbol purchased successfully!')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View Portfolio',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to portfolio screen if needed
            },
          ),
        ),
      );
    }
  }
}