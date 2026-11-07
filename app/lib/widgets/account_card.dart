import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/account_model.dart';

class AccountCard extends StatelessWidget {
  final AccountModel? account;
  final String cardHolderName;
  final bool isBalanceHidden;
  final VoidCallback onToggleVisibility;
  final VoidCallback? onRefresh;

  const AccountCard({
    super.key,
    required this.account,
    required this.cardHolderName,
    required this.isBalanceHidden,
    required this.onToggleVisibility,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final accountNumber = account?.accountNumber ?? '000000000000';
    final balance = account?.balance ?? 0.0;
    final currency = account?.currency ?? 'VND';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradientBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Bank name and chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'SE113',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'DIGITAL BANK',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              // EMV Chip representation
              Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Container(
                    width: 28,
                    height: 18,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.brown.withOpacity(0.4), width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Middle: Balance
          const Text(
            'Số dư khả dụng',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                isBalanceHidden ? '•••••••• ₫' : Formatters.formatCurrency(balance, currency: currency),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isBalanceHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Bottom: Account number & cardholder
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        accountNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: accountNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép số tài khoản'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Icon(Icons.copy, size: 16, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cardHolderName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              // Payment Network Logo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'NAPAS 247',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
