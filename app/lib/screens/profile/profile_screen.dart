import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/status_badge.dart';
import '../auth/login_screen.dart';
import '../beneficiaries/beneficiary_list_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showServerConfigDialog(BuildContext context) {
    final urlController = TextEditingController(text: ApiClient.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cài đặt máy chủ Backend API', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Máy ảo Android: http://10.0.2.2:8000\nThiết bị thật / LAN: http://<IP>:8000\nWeb / Desktop: http://127.0.0.1:8000',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'API Base URL'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              await StorageService.setCustomBaseUrl(urlController.text.trim());
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã cập nhật máy chủ: ${urlController.text.trim()}')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withOpacity(0.8)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.primary).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor ?? AppColors.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
            : null,
        trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // User Card Profile
              Container(
                width: double.infinity,
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
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        user?.fullName.isNotEmpty == true
                            ? user!.fullName.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.fullName ?? 'Khách hàng',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (user?.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        user!.phone!,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 10),
                    StatusBadge(status: user?.status ?? 'active'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Menu Items
              _buildMenuItem(
                icon: Icons.contacts_outlined,
                title: 'Danh bạ người thụ hưởng',
                subtitle: 'Quản lý danh sách nhận tiền',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BeneficiaryListScreen()),
                  );
                },
              ),

              _buildMenuItem(
                icon: Icons.lock_outline,
                title: 'Đổi mật khẩu',
                subtitle: 'Cập nhật mật khẩu đăng nhập',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  );
                },
              ),

              _buildMenuItem(
                icon: Icons.dns_outlined,
                title: 'Cài đặt máy chủ Backend',
                subtitle: ApiClient.baseUrl,
                onTap: () => _showServerConfigDialog(context),
              ),

              _buildMenuItem(
                icon: Icons.info_outline,
                title: 'Thông tin đồ án',
                subtitle: 'SE113.R11 - Kiểm chứng phần mềm (Nhóm 5)',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Mobile Online Banking',
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Đồ án môn học SE113 - Trường ĐH CNTT (UIT - ĐHQG-HCM)\nNhóm 5',
                  );
                },
              ),

              const SizedBox(height: 8),

              _buildMenuItem(
                icon: Icons.logout,
                title: 'Đăng xuất',
                iconColor: AppColors.error,
                textColor: AppColors.error,
                onTap: () => _handleLogout(context),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
