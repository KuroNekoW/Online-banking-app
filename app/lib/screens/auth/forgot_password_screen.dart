import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/otp_input_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifierController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 1; // 1: enter identifier, 2: enter otp and new password
  String? _challengeId;
  String _otpCode = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRequestOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email hoặc số điện thoại')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await AuthService.requestPasswordReset(identifier);
      setState(() {
        _challengeId = res['challenge_id'] as String;
        _currentStep = 2;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã xác thực khôi phục mật khẩu đã được gửi đến email!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleResetPassword() async {
    if (_otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ 6 chữ số OTP')),
      );
      return;
    }
    if (_newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu mới phải có ít nhất 8 ký tự')),
      );
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu xác nhận không khớp')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.confirmPasswordReset(
        challengeId: _challengeId!,
        code: _otpCode,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Thành công', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Mật khẩu của bạn đã được đặt lại thành công. Vui lòng đăng nhập lại.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khôi phục mật khẩu'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentStep == 1) ...[
                const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nhập địa chỉ email hoặc tên đăng nhập đã đăng ký để nhận mã xác minh khôi phục mật khẩu.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                CustomTextField(
                  controller: _identifierController,
                  label: 'Tên đăng nhập / Email',
                  hint: 'example@email.com',
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 28),
                CustomButton(
                  text: 'Gửi mã xác thực',
                  isLoading: _isLoading,
                  onPressed: _handleRequestOtp,
                ),
              ] else ...[
                const Text(
                  'Đặt lại mật khẩu mới',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nhập mã OTP được gửi qua email (Mailpit :8025) và mật khẩu mới của bạn.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mã OTP 6 chữ số',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                OtpInputField(
                  length: 6,
                  onCompleted: (code) => _otpCode = code,
                  onChanged: (code) => _otpCode = code,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _newPasswordController,
                  label: 'Mật khẩu mới',
                  hint: 'Tối thiểu 8 ký tự',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Xác nhận mật khẩu mới',
                  hint: 'Nhập lại mật khẩu mới',
                  prefixIcon: Icons.lock_reset,
                  isPassword: true,
                ),
                const SizedBox(height: 28),
                CustomButton(
                  text: 'Hoàn tất đặt lại mật khẩu',
                  isLoading: _isLoading,
                  onPressed: _handleResetPassword,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
