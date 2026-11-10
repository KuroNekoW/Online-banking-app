import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/transfer_model.dart';
import '../../services/transfer_service.dart';
import '../../widgets/custom_button.dart';
import 'transfer_otp_screen.dart';

class TransferConfirmScreen extends StatefulWidget {
  final TransferModel transfer;
  final String destinationAccountNumber;
  final String destinationBankName;

  const TransferConfirmScreen({
    super.key,
    required this.transfer,
    required this.destinationAccountNumber,
    required this.destinationBankName,
  });

  @override
  State<TransferConfirmScreen> createState() => _TransferConfirmScreenState();
}

class _TransferConfirmScreenState extends State<TransferConfirmScreen> {
  bool _isLoading = false;

  void _handleConfirm() async {
    setState(() => _isLoading = true);
    try {
      final res = await TransferService.confirmTransfer(widget.transfer.id);
      final challengeId = res['challenge_id'] as String?;

      if (!mounted) return;
      if (challengeId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransferOtpScreen(
              transfer: widget.transfer,
              challengeId: challengeId,
              destinationAccountNumber: widget.destinationAccountNumber,
              destinationBankName: widget.destinationBankName,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res['message'] ?? 'Giao dịch đã được xác nhận')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildRow(String label, String value,
      {bool isHighlight = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: isHighlight ? 17 : 14,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: valueColor ??
                    (isHighlight ? AppColors.primary : AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận giao dịch'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Số tiền chuyển',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.formatCurrency(t.amount, currency: t.currency),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    _buildRow(
                        'Tài khoản thụ hưởng', widget.destinationAccountNumber),
                    _buildRow('Ngân hàng nhận', widget.destinationBankName),
                    _buildRow('Phí giao dịch', '0 ₫ (Miễn phí)',
                        valueColor: AppColors.success),
                    _buildRow('Tổng tiền thanh toán',
                        Formatters.formatCurrency(t.amount + t.fee),
                        isHighlight: true),
                    const Divider(),
                    _buildRow('Lời nhắn', t.description ?? 'Chuyen tien'),
                    _buildRow('Mã tham chiếu', t.reference),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined,
                        color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Giao dịch được bảo mật bởi xác thực OTP 6 chữ số theo tiêu chuẩn an toàn ngân hàng.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              CustomButton(
                text: 'Xác nhận & Nhận mã OTP',
                isLoading: _isLoading,
                onPressed: _handleConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
