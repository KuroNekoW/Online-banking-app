import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../services/banking_service.dart';
import '../../widgets/status_badge.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionModel? _transaction;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  void _loadDetail() async {
    try {
      final tx = await BankingService.getTransactionDetail(widget.transactionId);
      setState(() {
        _transaction = tx;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giao dịch'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Trạng thái sổ cái', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                StatusBadge(status: _transaction!.status),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildRow('Mã tham chiếu', _transaction!.reference),
                            _buildRow('Thời gian tạo', Formatters.formatDateTime(_transaction!.createdAt)),
                            if (_transaction!.postedAt != null)
                              _buildRow('Thời gian đăng sổ (Posted)', Formatters.formatDateTime(_transaction!.postedAt)),
                            _buildRow('Nội dung', _transaction!.description ?? 'Giao dịch chuyển khoản'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Double-entry Ledger entries
                      const Text(
                        'Bút toán sổ cái (Double-Entry Ledger)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: _transaction!.entries.map((entry) {
                            final isCredit = entry.amount > 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
                                        size: 18,
                                        color: isCredit ? AppColors.success : AppColors.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isCredit ? 'Ghi có (Credit)' : 'Ghi nợ (Debit)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isCredit ? AppColors.success : AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    Formatters.formatCurrency(entry.amount.abs()),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isCredit ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
