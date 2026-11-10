import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/notification_model.dart';
import '../../providers/banking_provider.dart';
import '../../services/banking_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await BankingService.getNotifications(
          unreadOnly: _unreadOnly, limit: 50);
      setState(() {
        _notifications = res['items'] as List<NotificationModel>;
      });
      if (mounted) {
        await context.read<BankingProvider>().loadDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markAsRead(NotificationModel notif) async {
    if (notif.isRead) return;
    try {
      await BankingService.markNotificationRead(notif.id);
      _loadNotifications();
    } catch (_) {}
  }

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'transfer':
        return Icons.swap_horiz;
      case 'security':
        return Icons.security;
      default:
        return Icons.notifications_none;
    }
  }

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'transfer':
        return AppColors.success;
      case 'security':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo biến động'),
        actions: [
          IconButton(
            icon: Icon(
              _unreadOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _unreadOnly ? AppColors.primary : AppColors.textSecondary,
            ),
            tooltip: _unreadOnly ? 'Xem tất cả' : 'Chỉ xem chưa đọc',
            onPressed: () {
              setState(() {
                _unreadOnly = !_unreadOnly;
              });
              _loadNotifications();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNotifications,
          child: _isLoading && _notifications.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _notifications.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.notifications_off_outlined,
                                size: 64, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'Không có thông báo nào',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        final isUnread = !notif.isRead;

                        return Container(
                          decoration: BoxDecoration(
                            color: isUnread
                                ? Colors.blue.shade50.withValues(alpha: 0.4)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUnread
                                  ? AppColors.primaryLight
                                      .withValues(alpha: 0.3)
                                  : AppColors.divider,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => _markAsRead(notif),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _getIconColor(notif.type)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIcon(notif.type),
                                color: _getIconColor(notif.type),
                                size: 22,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notif.title,
                                    style: TextStyle(
                                      fontWeight: isUnread
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notif.body,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    Formatters.formatDateTime(notif.createdAt),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
