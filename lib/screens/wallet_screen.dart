import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../providers/auth_provider.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with TickerProviderStateMixin {
  double walletBalance = 0.0;
  final TextEditingController _amountController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<WalletTransaction> _transactions = [];
  bool _isProcessing = false;
  bool _bonusClaimed = false;
  bool _showAddDrawer = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String? _currentUserUid;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _getCurrentUser();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _getCurrentUser() {
    _currentUserUid = context.read<AuthProvider>().userUid;
    if (_currentUserUid != null) {
      _loadWalletData();
    } else {
      _showMessage('Please log in to access your wallet', isError: true);
    }
  }

  Future<void> _loadWalletData() async {
    if (_currentUserUid == null) return;
    await Future.wait(
        [_loadBalance(), _loadTransactions(), _loadBonusStatus()]);
    _fadeController.forward();
  }

  Future<void> _loadBalance() async {
    if (_currentUserUid == null) return;
    try {
      final walletDoc =
      await _firestore.collection('wallets').doc(_currentUserUid).get();
      if (walletDoc.exists) {
        final data = walletDoc.data() as Map<String, dynamic>;
        setState(() {
          walletBalance = data['balance']?.toDouble() ?? 0.0;
        });
      } else {
        // If no Firestore document, initialize balance to 0.0 and create document
        await _saveBalance(0.0);
        setState(() {
          walletBalance = 0.0;
        });
      }
    } catch (e) {
      _showMessage('Error loading wallet balance: $e', isError: true);
      setState(() {
        walletBalance = 0.0; // Default to 0.0 on error
      });
    }
  }

  Future<void> _saveBalance([double? specificBalance]) async {
    if (_currentUserUid == null) return;
    final balanceToSave = specificBalance ?? walletBalance;
    try {
      await _firestore.collection('wallets').doc(_currentUserUid).set({
        'userId': _currentUserUid,
        'balance': balanceToSave,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _showMessage('Failed to save balance to cloud: $e', isError: true);
    }
  }

  Future<void> _loadBonusStatus() async {
    if (_currentUserUid == null) return;
    try {
      final bonusDoc = await _firestore
          .collection('bonus_claims')
          .doc(_currentUserUid)
          .get();
      setState(() => _bonusClaimed = bonusDoc.exists);
    } catch (e) {
      _showMessage('Error loading bonus status: $e', isError: true);
      setState(() => _bonusClaimed = false); // Default to false on error
    }
  }

  Future<void> _claimBonus() async {
    if (_currentUserUid == null || _bonusClaimed) return;
    setState(() => _isProcessing = true);
    try {
      const bonusAmount = 100000.0;
      // Create bonus claim record in Firestore
      await _firestore.collection('bonus_claims').doc(_currentUserUid).set({
        'userId': _currentUserUid,
        'claimedAt': FieldValue.serverTimestamp(),
        'amount': bonusAmount,
      });
      // Add transaction record
      await _firestore.collection('add_money').add({
        'userId': _currentUserUid,
        'amount': bonusAmount,
        'description': 'Welcome bonus claimed',
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() {
        walletBalance += bonusAmount;
        _bonusClaimed = true;
      });
      await _saveBalance(); // This will now save to Firestore
      await _loadTransactions();
      _showMessage(
          'Bonus claimed successfully! \$${bonusAmount.toStringAsFixed(0)} added to your wallet!');
    } catch (e) {
      _showMessage('Failed to claim bonus: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _loadTransactions() async {
    if (_currentUserUid == null) return;
    try {
      final futures = await Future.wait([
        _firestore
            .collection('add_money')
            .where('userId', isEqualTo: _currentUserUid)
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get(),
        _firestore
            .collection('buy_details')
            .where('userId', isEqualTo: _currentUserUid)
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get(),
        _firestore
            .collection('sell_details')
            .where('userId', isEqualTo: _currentUserUid)
            .orderBy('sellDate', descending: true)
            .limit(10)
            .get(),
      ]);

      final transactions = <WalletTransaction>[];

      // Add money transactions
      for (var doc in futures[0].docs) {
        final data = doc.data() as Map<String, dynamic>;
        transactions.add(WalletTransaction(
          id: doc.id,
          type: TransactionType.deposit,
          amount: data['amount']?.toDouble() ?? 0.0,
          description: data['description'] ?? 'Money added to wallet',
          date: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }

      // Buy transactions
      for (var doc in futures[1].docs) {
        final data = doc.data() as Map<String, dynamic>;
        transactions.add(WalletTransaction(
          id: doc.id,
          type: TransactionType.withdrawal,
          amount: data['total_investment']?.toDouble() ?? 0.0,
          description: 'Bought ${data['symbol'] ?? 'Stock'}',
          date: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }

      // Sell transactions
      for (var doc in futures[2].docs) {
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

  void _navigateToPayment(double amount) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: amount,
          userUid: _currentUserUid!,
          onPaymentSuccess: (amount) {
            setState(() => walletBalance += amount);
            _saveBalance();
            _loadTransactions();
            _showMessage(
                'Payment successful! \$${amount.toStringAsFixed(0)} added to your wallet!');
          },
        ),
      ),
    );
  }

  double _getWalletAmount() =>
      (double.tryParse(_amountController.text) ?? 0.0) * 50;

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Widget _buildExpandableAddMoney() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => setState(() {
              _showAddDrawer = !_showAddDrawer;
              if (_showAddDrawer) _amountController.clear();
            }),
            icon: Icon(_showAddDrawer
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down),
            label: const Text('Add Money'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _showAddDrawer ? null : 0,
          child: _showAddDrawer ? _buildAddMoneyContent() : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildAddMoneyContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            decoration: const InputDecoration(
              labelText: 'Amount to Pay (₹)',
              prefixText: '₹',
              border: OutlineInputBorder(),
              helperText: '₹100 = \$5000 in wallet',
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (_amountController.text.isNotEmpty) _buildAmountPreview(),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildAmountPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('You will get:', style: Theme.of(context).textTheme.bodyLarge),
          Text(
            '\$${_getWalletAmount().toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() => _showAddDrawer = false);
              _amountController.clear();
            },
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _amountController.text.isNotEmpty
                ? () {
              final payAmount =
                  double.tryParse(_amountController.text) ?? 0.0;
              if (payAmount > 0) _navigateToPayment(payAmount);
            }
                : null,
            child: const Text('Pay Now'),
          ),
        ),
      ],
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
        subtitle: Text(
            '${transaction.date.day}/${transaction.date.month}/${transaction.date.year} ${transaction.date.hour}:${transaction.date.minute.toString().padLeft(2, '0')}'),
        trailing: Text(
          '${isDeposit ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: isDeposit ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
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
        builder: (context, scrollController) => Container(
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
                  color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Transaction History',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Expanded(
                child: _transactions.isEmpty
                    ? const Center(child: Text('No transactions yet'))
                    : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) =>
                      _buildTransactionTile(_transactions[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBonusSection() {
    if (_bonusClaimed) return const SizedBox();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.amber],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, size: 40, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome Bonus',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Text('Claim your \$100,000 bonus!',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isProcessing ? null : _claimBonus,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: _isProcessing
                ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Claim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (_currentUserUid != authProvider.userUid) {
          _currentUserUid = authProvider.userUid;
          if (_currentUserUid != null) _loadWalletData();
        }
        if (!authProvider.isAuthenticated || _currentUserUid == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Wallet')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Please log in to access your wallet',
                      style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Wallet'),
            actions: [
              IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: _showTransactionHistory),
              IconButton(
                  icon: const Icon(Icons.refresh), onPressed: _loadWalletData),
            ],
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Balance Card
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
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_wallet,
                          size: 48, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Available Balance',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${walletBalance.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                _buildBonusSection(),
                _buildExpandableAddMoney(),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Recent Transactions',
                                  style:
                                  Theme.of(context).textTheme.titleLarge),
                              TextButton(
                                  onPressed: _showTransactionHistory,
                                  child: const Text('View All')),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _transactions.isEmpty
                              ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long,
                                    size: 64,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text('No transactions yet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7))),
                              ],
                            ),
                          )
                              : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            itemCount: _transactions.length > 5
                                ? 5
                                : _transactions.length,
                            itemBuilder: (context, index) =>
                                _buildTransactionTile(
                                    _transactions[index]),
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
      },
    );
  }
}

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String userUid;
  final Function(double) onPaymentSuccess;
  const PaymentScreen({
    super.key,
    required this.amount,
    required this.userUid,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Razorpay _razorpay;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = true);
    try {
      final walletAmount = widget.amount * 50;
      // Add transaction record
      await FirebaseFirestore.instance.collection('add_money').add({
        'userId': widget.userUid,
        'amount': walletAmount,
        'description':
        'Money added via Razorpay (₹${widget.amount.toStringAsFixed(0)})',
        'paymentId': response.paymentId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      // Update wallet balance in Firestore
      await WalletUtils.updateBalance(widget.userUid, walletAmount);
      widget.onPaymentSuccess(walletAmount);
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Payment successful but failed to update wallet: $e',
          isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showMessage('Payment failed: ${response.message}', isError: true);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showMessage('External wallet selected: ${response.walletName}');
  }

  void _startPayment() {
    var options = {
      'key': 'rzp_test_cFaOVaXjJp8oB2',
      'amount': (widget.amount * 100).toInt(),
      'name': 'Wallet Top-up',
      'description': 'Add money to wallet',
      'prefill': {'contact': '9999999999', 'email': 'user@example.com'}
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      _showMessage('Error: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletAmount = widget.amount * 50;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Money'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.payment, size: 64, color: Colors.blue),
                  const SizedBox(height: 24),
                  Text('Payment Details',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pay Amount:', style: TextStyle(fontSize: 16)),
                      Text('₹${widget.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Wallet Credit:',
                          style: TextStyle(fontSize: 16)),
                      Text(
                        '\$${walletAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _startPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Pay Now',
                          style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
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

class WalletUtils {
  static Future<double> getCurrentBalance(String userUid) async {
    try {
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(userUid)
          .get();
      if (walletDoc.exists) {
        final data = walletDoc.data() as Map<String, dynamic>;
        return data['balance']?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print('Error getting current balance from Firestore: $e');
    }
    return 0.0; // Return 0.0 if document doesn't exist or on error
  }

  static Future<void> updateBalance(String userUid, double amount) async {
    try {
      // Get current balance from Firestore
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(userUid)
          .get();
      double currentBalance = 0.0;
      if (walletDoc.exists) {
        final data = walletDoc.data() as Map<String, dynamic>;
        currentBalance = data['balance']?.toDouble() ?? 0.0;
      }

      final newBalance = currentBalance + amount;

      // Update in Firestore
      await FirebaseFirestore.instance.collection('wallets').doc(userUid).set({
        'userId': userUid,
        'balance': newBalance,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating balance in Firestore: $e');
      // Consider adding a mechanism to retry or notify user if Firestore update fails
    }
  }
}
