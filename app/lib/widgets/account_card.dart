import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(21, 19, 21, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF183A66),
                  Color(0xFF214E82),
                  Color(0xFF187C83)
                ],
                stops: [0, .58, 1],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.account_balance_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SE113 DIGITAL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1)),
                          SizedBox(height: 2),
                          Text('TÀI KHOẢN THANH TOÁN',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: .8)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cập nhật số dư',
                      onPressed: onRefresh,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.sync_rounded,
                          color: Colors.white70, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('SỐ DƯ KHẢ DỤNG',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.15)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isBalanceHidden
                              ? '•••••••• ₫'
                              : Formatters.formatCurrency(balance,
                                  currency: currency),
                          maxLines: 1,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .2),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: isBalanceHidden ? 'Hiện số dư' : 'Ẩn số dư',
                      padding: const EdgeInsets.only(left: 8),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                          isBalanceHidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white70,
                          size: 19),
                      onPressed: onToggleVisibility,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                  child: Text(accountNumber,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.4))),
                              const SizedBox(width: 7),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () {
                                  Clipboard.setData(
                                      ClipboardData(text: accountNumber));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Đã sao chép số tài khoản'),
                                          duration: Duration(seconds: 2)));
                                },
                                child: const Padding(
                                    padding: EdgeInsets.all(3),
                                    child: Icon(Icons.copy_rounded,
                                        size: 14, color: Colors.white70)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(cardHolderName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: .75)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(9)),
                      child: const Text('NAPAS 247',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
              right: -42,
              top: 44,
              child: _GlowCircle(size: 145, opacity: .055)),
          Positioned(
              right: 35,
              bottom: -76,
              child: _GlowCircle(size: 150, opacity: .045)),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _GlowCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: opacity), width: 22)),
        ),
      );
}
