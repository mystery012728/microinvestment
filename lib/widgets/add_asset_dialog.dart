import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/asset.dart';
import '../providers/portfolio_provider.dart';
import '../services/api_service.dart';

class AddAssetDialog extends StatefulWidget {
  const AddAssetDialog({super.key});

  @override
  State<AddAssetDialog> createState() => _AddAssetDialogState();
}

class _AddAssetDialogState extends State<AddAssetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  
  AssetType _selectedType = AssetType.stock;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _selectedAssetName;

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _buyPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Asset',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),

                // Asset Type Selection
                Text(
                  'Asset Type',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<AssetType>(
                  segments: AssetType.values.map((type) {
                    return ButtonSegment<AssetType>(
                      value: type,
                      label: Text(type.displayName),
                      icon: Text(type.icon),
                    );
                  }).toList(),
                  selected: {_selectedType},
                  onSelectionChanged: (Set<AssetType> selection) {
                    setState(() {
                      _selectedType = selection.first;
                      _searchResults.clear();
                      _selectedAssetName = null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Symbol Search
                TextFormField(
                  controller: _symbolController,
                  decoration: const InputDecoration(
                    labelText: 'Symbol',
                    hintText: 'e.g., AAPL, BTC',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: _searchAssets,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a symbol';
                    }
                    return null;
                  },
                ),

                // Search Results
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(result['symbol']),
                          subtitle: Text(result['name']),
                          onTap: () {
                            _symbolController.text = result['symbol'];
                            _selectedAssetName = result['name'];
                            setState(() {
                              _searchResults.clear();
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Quantity
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
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
                const SizedBox(height: 16),

                // Buy Price
                TextFormField(
                  controller: _buyPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Buy Price (\$)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter buy price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
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
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addAsset,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add Asset'),
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

  Future<void> _searchAssets(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    try {
      final results = await ApiService.searchAssets(query);
      setState(() {
        _searchResults = results.where((result) => 
          result['type'] == _selectedType.name ||
          (_selectedType == AssetType.crypto && result['type'] == 'crypto') ||
          (_selectedType == AssetType.stock && (result['type'] == 'stock' || result['type'] == 'etf'))
        ).take(5).toList();
      });
    } catch (e) {
      // Handle search error silently
      setState(() {
        _searchResults.clear();
      });
    }
  }

  Future<void> _addAsset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final symbol = _symbolController.text.toUpperCase();
      final quantity = double.parse(_quantityController.text);
      final buyPrice = double.parse(_buyPriceController.text);

      // Get current price
      final currentPrice = await ApiService.getAssetPrice(symbol);

      final asset = Asset(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        symbol: symbol,
        name: _selectedAssetName ?? symbol,
        type: _selectedType,
        quantity: quantity,
        buyPrice: buyPrice,
        currentPrice: currentPrice,
        purchaseDate: DateTime.now(),
      );

      if (mounted) {
        await context.read<PortfolioProvider>().addAsset(asset);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add asset: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
