import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/banking_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/auth_brand_header.dart';
import '../home/main_navigation_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    final saved = StorageService.getRememberedIdentifier();
    if (saved != null && saved.isNotEmpty) {
      _identifierController.text = saved;
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _identifierController.text.trim(),
      _passwordController.text,
      remember: _rememberMe,
    );

    if (!mounted) return;

    if (success) {
      await context.read<BankingProvider>().loadDashboard();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(authProvider.errorMessage ?? 'Đăng nhập không thành công'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showServerConfigDialog() {
    final urlController = TextEditingController(text: ApiClient.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cài đặt địa chỉ máy chủ API',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nếu dùng máy ảo Android: http://10.0.2.2:8000\nNếu dùng thiết bị thật: http://<IP_LAN>:8000\nNếu Web / Desktop: http://127.0.0.1:8000',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Backend Base URL',
                hintText: 'http://10.0.2.2:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              await StorageService.setCustomBaseUrl(urlController.text.trim());
              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Đã cập nhật máy chủ: ${urlController.text.trim()}')),
              );
              setState(() {});
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Cài đặt kết nối API',
              onPressed: _showServerConfigDialog,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(color: const Color(0xFFE9EEF3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Đăng nhập',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Nhập thông tin tài khoản của bạn',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _identifierController,
                        label: 'Tên đăng nhập / Email / SĐT',
                        hint: 'Nhập email hoặc số điện thoại',
                        prefixIcon: Icons.person_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Vui lòng nhập tên đăng nhập'
                            : null,
                      ),
                      const SizedBox(height: 17),
                      CustomTextField(
                        controller: _passwordController,
                        label: 'Mật khẩu',
                        hint: 'Nhập mật khẩu',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Vui lòng nhập mật khẩu'
                            : null,
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) =>
                                setState(() => _rememberMe = val ?? true),
                          ),
                          const Expanded(
                              child: Text('Ghi nhớ tài khoản',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary))),
                          TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen())),
                            child: const Text('Quên mật khẩu?',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                          text: 'Đăng nhập',
                          icon: Icons.arrow_forward_rounded,
                          isLoading: authProvider.isLoading,
                          onPressed: _handleLogin),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Chưa có tài khoản? ',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RegisterScreen())),
                            child: const Text('Đăng ký ngay',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 15, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('Kết nối được bảo vệ',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
