import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with TickerProviderStateMixin {
  double walletBalance = 0.0;
  final TextEditingController _amountController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<WalletTransaction> _transactions = [];
  bool _isProcessing = false;
  bool _showAddDrawer = false;
  bool _showWithdrawDrawer = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _loadWalletData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    await Future.wait([_loadBalance(), _loadTransactions()]);
    _fadeController.forward();
  }

  Future<void> _loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => walletBalance = prefs.getDouble('wallet_balance') ?? 0.0);
  }

  Future<void> _saveBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('wallet_balance', walletBalance);
  }

  static Future<double> getCurrentBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('wallet_balance') ?? 0.0;
  }

  static Future<void> updateBalance(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final currentBalance = prefs.getDouble('wallet_balance') ?? 0.0;
    await prefs.setDouble('wallet_balance', currentBalance + amount);
  }

  Future<void> _loadTransactions() async {
    try {
      final futures = await Future.wait([
        _firestore.collection('add_money').orderBy('timestamp', descending: true).limit(10).get(),
        _firestore.collection('withdraw_details').orderBy('timestamp', descending: true).limit(10).get(),
        _firestore.collection('buy_details').orderBy('timestamp', descending: true).limit(10).get(),
        _firestore.collection('sell_details').orderBy('sellDate', descending: true).limit(10).get(),
      ]);

      final transactions = <WalletTransaction>[];

      for (var doc in futures[0].docs) {
        final data = doc.data() as Map<String, dynamic>;
        transactions.add(WalletTransaction(
          id: doc.id,
          type: TransactionType.deposit,
          amount: data['amount']?.toDouble() ?? 0.0,
          description: 'Money added to wallet',
          date: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }

      for (var doc in futures[1].docs) {
        final data = doc.data() as Map<String, dynamic>;
        transactions.add(WalletTransaction(
          id: doc.id,
          type: TransactionType.withdrawal,
          amount: data['amount']?.toDouble() ?? 0.0,
          description: 'Money withdrawn',
          date: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }

      for (var doc in futures[2].docs) {
        final data = doc.data() as Map<String, dynamic>;
        transactions.add(WalletTransaction(
          id: doc.id,
          type: TransactionType.withdrawal,
          amount: data['total_investment']?.toDouble() ?? 0.0,
          description: 'Bought ${data['symbol'] ?? 'Stock'}',
          date: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }

      for (var doc in futures[3].docs) {
        final data = doc.data() as Map<String, dynamic>;
        transactions.add(WalletTransaction(
          id: doc.id,
          type: TransactionType.deposit,
          amount: data['saleAmount']?.toDouble() ?? 0.0,
          description: 'Sold ${data['symbol'] ?? 'Stock'}',
          date: (data['sellDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }

      transactions.sort((a, b) => b.date.compareTo(a.date));
      setState(() => _transactions = transactions.take(20).toList());
    } catch (e) {
      _showMessage('Error loading transactions: $e', isError: true);
    }
  }

  Future<void> _processTransaction(bool isAdd) async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showMessage('Please enter a valid amount', isError: true);
      return;
    }

    if (!isAdd && amount > walletBalance) {
      _showMessage('Insufficient balance', isError: true);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await _firestore.collection(isAdd ? 'add_money' : 'withdraw_details').add({
        'amount': amount,
        'description': isAdd ? 'Money added to wallet' : 'Money withdrawn from wallet',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() => walletBalance += isAdd ? amount : -amount);
      await _saveBalance();
      await _loadTransactions();
      _closeDrawers();
      _showMessage('${isAdd ? 'Money added' : 'Money withdrawn'} successfully!');
    } catch (e) {
      _showMessage('Failed to ${isAdd ? 'add' : 'withdraw'} money: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _closeDrawers() {
    setState(() {
      _showAddDrawer = false;
      _showWithdrawDrawer = false;
    });
    _amountController.clear();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  Widget _buildDrawer(bool isAdd) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '\$',
              border: const OutlineInputBorder(),
              helperText: isAdd ? null : 'Available: \$${walletBalance.toStringAsFixed(2)}',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _closeDrawers,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _processTransaction(isAdd),
                  child: _isProcessing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isAdd ? 'Add' : 'Withdraw'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(WalletTransaction transaction) {
    final isDeposit = transaction.type == TransactionType.deposit;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDeposit ? Colors.green : Colors.red).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
            color: isDeposit ? Colors.green : Colors.red,
          ),
        ),
        title: Text(transaction.description),
        subtitle: Text('${transaction.date.day}/${transaction.date.month}/${transaction.date.year} ${transaction.date.hour}:${transaction.date.minute.toString().padLeft(2, '0')}'),
        trailing: Text(
          '${isDeposit ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(color: isDeposit ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showTransactionHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
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
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Transaction History', style: Theme.of(context).textTheme.titleLarge),
                ),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(child: Text('No transactions yet'))
                      : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) => _buildTransactionTile(_transactions[index]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: _showTransactionHistory),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadWalletData),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 48, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Available Balance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white.withOpacity(0.9)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${walletBalance.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAddDrawer = !_showAddDrawer;
                              _showWithdrawDrawer = false;
                            });
                            if (_showAddDrawer) _amountController.clear();
                          },
                          icon: Icon(_showAddDrawer ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                          label: const Text('Add Money'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: walletBalance > 0 ? () {
                            setState(() {
                              _showWithdrawDrawer = !_showWithdrawDrawer;
                              _showAddDrawer = false;
                            });
                            if (_showWithdrawDrawer) _amountController.clear();
                          } : null,
                          icon: Icon(_showWithdrawDrawer ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                          label: const Text('Withdraw'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showAddDrawer) _buildDrawer(true),
                  if (_showWithdrawDrawer) _buildDrawer(false),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
                          TextButton(onPressed: _showTransactionHistory, child: const Text('View All')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _transactions.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text('No transactions yet', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                          ],
                        ),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _transactions.length > 5 ? 5 : _transactions.length,
                        itemBuilder: (context, index) => _buildTransactionTile(_transactions[index]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WalletTransaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime date;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
  });
}

enum TransactionType { deposit, withdrawal }