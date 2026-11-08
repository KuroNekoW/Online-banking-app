import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/transfer_model.dart';
import '../../providers/banking_provider.dart';
import '../../services/transfer_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/otp_input_field.dart';
import '../../widgets/auth_brand_header.dart';
import 'transfer_success_screen.dart';

class TransferOtpScreen extends StatefulWidget {
  final TransferModel transfer;
  final String challengeId;
  final String destinationAccountNumber;
  final String destinationBankName;

  const TransferOtpScreen({
    super.key,
    required this.transfer,
    required this.challengeId,
    required this.destinationAccountNumber,
    required this.destinationBankName,
  });

  @override
  State<TransferOtpScreen> createState() => _TransferOtpScreenState();
}

class _TransferOtpScreenState extends State<TransferOtpScreen> {
  String _otpCode = '';
  bool _isLoading = false;

  void _handleAuthenticate() async {
    if (_otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ 6 chữ số OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final completedTransfer = await TransferService.authenticateTransfer(
        transferId: widget.transfer.id,
        code: _otpCode,
      );

      // Refresh balance and dashboard data
      if (mounted) {
        await context.read<BankingProvider>().loadDashboard();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TransferSuccessScreen(
            transfer: completedTransfer,
            destinationAccountNumber: widget.destinationAccountNumber,
            destinationBankName: widget.destinationBankName,
          ),
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
    final t = widget.transfer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác thực OTP'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(
                title: 'Xác thực giao dịch',
                subtitle: 'Mã OTP giúp bảo vệ giao dịch của bạn.',
                icon: Icons.lock_clock_outlined,
              ),
              const SizedBox(height: 15),
              Center(
                child: Text(
                  'Số tiền: ${Formatters.formatCurrency(t.amount)}\nĐến STK: ${widget.destinationAccountNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Local development Mailpit reminder
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD8E3F0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.mark_email_unread_outlined,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mã OTP đã được gửi về email Mailpit (http://localhost:8025).',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              OtpInputField(
                length: 6,
                onChanged: (code) => _otpCode = code,
                onCompleted: (code) {
                  _otpCode = code;
                  _handleAuthenticate();
                },
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: 'Xác thực chuyển tiền',
                isLoading: _isLoading,
                onPressed: _handleAuthenticate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
