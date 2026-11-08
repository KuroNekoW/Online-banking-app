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
    final firstName = user?.fullName.trim().split(' ').last ?? 'bạn';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await bankingProvider.loadDashboard();
            await authProvider.refreshProfile();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _DashboardHeader(
                      firstName: firstName,
                      fullName: user?.fullName ?? 'Khách hàng',
                      unreadCount: bankingProvider.unreadNotificationCount,
                      onNotifications: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tài khoản thanh toán',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (bankingProvider.isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          TextButton.icon(
                            onPressed: () => bankingProvider.refreshBalance(),
                            icon: const Icon(Icons.refresh_rounded, size: 17),
                            label: const Text('Cập nhật'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    AccountCard(
                      account: account,
                      cardHolderName: user?.fullName ?? 'KHACH HANG',
                      isBalanceHidden: bankingProvider.isBalanceHidden,
                      onToggleVisibility:
                          bankingProvider.toggleBalanceVisibility,
                      onRefresh: bankingProvider.refreshBalance,
                    ),
                    const SizedBox(height: 26),
                    _SectionHeading(
                      title: 'Dịch vụ',
                      trailing: 'Tất cả',
                      onTrailing: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BeneficiaryListScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 13, 8, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFEAEFF4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                              child: QuickActionItem(
                            icon: Icons.arrow_upward_rounded,
                            label: 'Chuyển tiền',
                            color: AppColors.primary,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const TransferFormScreen())),
                          )),
                          Expanded(
                              child: QuickActionItem(
                            icon: Icons.people_alt_outlined,
                            label: 'Người nhận',
                            color: const Color(0xFF168C79),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BeneficiaryListScreen())),
                          )),
                          Expanded(
                              child: QuickActionItem(
                            icon: Icons.receipt_long_outlined,
                            label: 'Lịch sử',
                            color: const Color(0xFF7757B7),
                            onTap: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const MainNavigationScreen(
                                        initialIndex: 2))),
                          )),
                          Expanded(
                              child: QuickActionItem(
                            icon: Icons.lock_outline_rounded,
                            label: 'Bảo mật',
                            color: const Color(0xFFCE7A36),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ChangePasswordScreen())),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 27),
                    _SectionHeading(
                      title: 'Giao dịch gần đây',
                      trailing: 'Xem tất cả',
                      onTrailing: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const MainNavigationScreen(initialIndex: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (bankingProvider.isLoading &&
                        bankingProvider.recentTransactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (bankingProvider.recentTransactions.isEmpty)
                      _EmptyTransactions(
                          onTransfer: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TransferFormScreen())))
                    else
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFEAEFF4)),
                        ),
                        child: Column(
                          children: bankingProvider.recentTransactions
                              .map((tx) => TransactionTile(
                                    transaction: tx,
                                    accountId: account?.id,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              TransactionDetailScreen(
                                                  transactionId: tx.id)),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String firstName;
  final String fullName;
  final int unreadCount;
  final VoidCallback onNotifications;

  const _DashboardHeader({
    required this.firstName,
    required this.fullName,
    required this.unreadCount,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : 'U';
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF315B9B), Color(0xFF18335D)]),
            borderRadius: BorderRadius.circular(17),
          ),
          alignment: Alignment.center,
          child: Text(initial,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Xin chào,',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 2),
              Text(firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFEAEFF4))),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onNotifications,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: unreadCount > 0
                    ? Badge.count(
                        count: unreadCount,
                        backgroundColor: const Color(0xFFE76E63),
                        child: const Icon(Icons.notifications_none_rounded,
                            color: AppColors.textPrimary))
                    : const Icon(Icons.notifications_none_rounded,
                        color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String trailing;
  final VoidCallback onTrailing;

  const _SectionHeading(
      {required this.title, required this.trailing, required this.onTrailing});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700))),
          TextButton(
            onPressed: onTrailing,
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4)),
            child: Row(children: [
              Text(trailing,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right_rounded, size: 18)
            ]),
          ),
        ],
      );
}

class _EmptyTransactions extends StatelessWidget {
  final VoidCallback onTransfer;
  const _EmptyTransactions({required this.onTransfer});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEAEFF4))),
        child: Column(
          children: [
            Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                    color: Color(0xFFEAF0F8), shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_outlined,
                    color: AppColors.primary, size: 25)),
            const SizedBox(height: 12),
            const Text('Chưa có giao dịch nào',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 5),
            const Text('Các giao dịch của bạn sẽ xuất hiện tại đây.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
                onPressed: onTransfer,
                child: const Text('Thực hiện giao dịch')),
          ],
        ),
      );
}
