import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../providers/banking_provider.dart';
import '../../services/banking_service.dart';
import '../../widgets/transaction_tile.dart';
import 'transaction_detail_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => TransactionHistoryScreenState();
}

class TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalTransactions = 0;
  String _filter = 'ALL'; // 'ALL', 'CREDIT', 'DEBIT'

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> reload() => _loadTransactions(page: 1, refresh: true);

  Future<void> _loadTransactions({int page = 1, bool refresh = false}) async {
    setState(() => _isLoading = true);
    final accountId = context.read<BankingProvider>().selectedAccount?.id;

    try {
      final res = await BankingService.getTransactions(
        accountId: accountId,
        page: page,
        pageSize: 20,
      );

      final newItems = res['items'] as List<TransactionModel>;
      if (!mounted) return;
      setState(() {
        _currentPage = page;
        _totalTransactions = res['total'] as int;
        if (refresh || page == 1) {
          _transactions = newItems;
        } else {
          _transactions.addAll(newItems);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TransactionModel> _getFilteredTransactions() {
    final accountId = context.read<BankingProvider>().selectedAccount?.id;
    if (_filter == 'ALL') return _transactions;
    if (_filter == 'CREDIT') {
      return _transactions.where((t) => t.getAmountForAccount(accountId) > 0).toList();
    }
    return _transactions.where((t) => t.getAmountForAccount(accountId) < 0).toList();
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.divider),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filter = value;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<BankingProvider>().selectedAccount;
    final filtered = _getFilteredTransactions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Header Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  _buildFilterChip('Tất cả', 'ALL'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Tiền vào (+)', 'CREDIT'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Tiền ra (-)', 'DEBIT'),
                ],
              ),
            ),
            const Divider(height: 1),

            // Transactions List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadTransactions(page: 1, refresh: true),
                child: _isLoading && _transactions.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textMuted),
                                  SizedBox(height: 12),
                                  Text(
                                    'Không tìm thấy giao dịch nào',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: filtered.length + (_transactions.length < _totalTransactions ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filtered.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: OutlinedButton(
                                      onPressed: _isLoading ? null : () => _loadTransactions(page: _currentPage + 1),
                                      child: _isLoading
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Text('Tải thêm giao dịch cũ hơn'),
                                    ),
                                  ),
                                );
                              }
                              final tx = filtered[index];
                              return TransactionTile(
                                transaction: tx,
                                accountId: account?.id,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TransactionDetailScreen(transactionId: tx.id),
                                    ),
                                  ).then((_) {
                                    if (mounted) reload();
                                  });
                                },
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
