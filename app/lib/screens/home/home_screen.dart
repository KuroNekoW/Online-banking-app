import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/banking_provider.dart';
import '../../widgets/account_card.dart';
import '../../widgets/quick_action_item.dart';
import '../../widgets/transaction_tile.dart';
import '../beneficiaries/beneficiary_list_screen.dart';
import '../history/transaction_detail_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/change_password_screen.dart';
import '../transfer/transfer_form_screen.dart';
import 'main_navigation_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final bankingProvider = context.watch<BankingProvider>();
    final user = authProvider.currentUser;
    final account = bankingProvider.selectedAccount;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await bankingProvider.loadDashboard();
            await authProvider.refreshProfile();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: User Greeting & Notification
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            user?.fullName.isNotEmpty == true
                                ? user!.fullName.substring(0, 1).toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Xin chào,',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              user?.fullName ?? 'Khách hàng',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                          tooltip: 'Làm mới số dư',
                          onPressed: () => bankingProvider.loadDashboard(),
                        ),
                        IconButton(
                          icon: bankingProvider.unreadNotificationCount > 0
                              ? Badge.count(
                                  count: bankingProvider.unreadNotificationCount,
                                  backgroundColor: AppColors.error,
                                  child: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                                )
                              : const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Bank Account Card
                AccountCard(
                  account: account,
                  cardHolderName: user?.fullName ?? 'KHACH HANG',
                  isBalanceHidden: bankingProvider.isBalanceHidden,
                  onToggleVisibility: () => bankingProvider.toggleBalanceVisibility(),
                  onRefresh: () => bankingProvider.refreshBalance(),
                ),

                const SizedBox(height: 26),

                // Quick Action Buttons
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      QuickActionItem(
                        icon: Icons.send_rounded,
                        label: 'Chuyển tiền',
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TransferFormScreen()),
                          );
                        },
                      ),
                      QuickActionItem(
                        icon: Icons.contacts_outlined,
                        label: 'Danh bạ',
                        color: AppColors.accent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BeneficiaryListScreen()),
                          );
                        },
                      ),
                      QuickActionItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Lịch sử GD',
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MainNavigationScreen(initialIndex: 2),
                            ),
                          );
                        },
                      ),
                      QuickActionItem(
                        icon: Icons.lock_reset,
                        label: 'Đổi MK',
                        color: Colors.orange.shade700,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Recent Transactions Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Giao dịch gần đây',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainNavigationScreen(initialIndex: 2),
                          ),
                        );
                      },
                      child: const Text(
                        'Xem tất cả',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Transactions List
                if (bankingProvider.isLoading && bankingProvider.recentTransactions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (bankingProvider.recentTransactions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.receipt_outlined, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có giao dịch nào',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Thực hiện chuyển tiền để phát sinh giao dịch đầu tiên',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ...bankingProvider.recentTransactions.map(
                    (tx) => TransactionTile(
                      transaction: tx,
                      accountId: account?.id,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TransactionDetailScreen(transactionId: tx.id),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
