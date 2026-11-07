import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final String? accountId;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.accountId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final netAmount = transaction.getAmountForAccount(accountId);
    final isCredit = netAmount > 0;
    final absAmount = netAmount.abs();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withOpacity(0.6)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isCredit
                ? AppColors.success.withOpacity(0.12)
                : AppColors.error.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: isCredit ? AppColors.success : AppColors.error,
            size: 22,
          ),
        ),
        title: Text(
          transaction.description?.isNotEmpty == true
              ? transaction.description!
              : (isCredit ? 'Nhận tiền chuyển khoản' : 'Chuyển tiền đi'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                Formatters.formatDateTime(transaction.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${transaction.reference}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        trailing: Text(
          '${isCredit ? "+" : "-"}${Formatters.formatCurrency(absAmount)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isCredit ? AppColors.success : AppColors.error,
          ),
        ),
      ),
    );
  }
}
