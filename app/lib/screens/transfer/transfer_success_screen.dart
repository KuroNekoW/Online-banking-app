import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/transfer_model.dart';
import '../../providers/banking_provider.dart';
import '../../services/banking_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_badge.dart';
import '../home/main_navigation_screen.dart';
import 'transfer_form_screen.dart';

class TransferSuccessScreen extends StatefulWidget {
  final TransferModel transfer;
  final String destinationAccountNumber;
  final String destinationBankName;

  const TransferSuccessScreen({
    super.key,
    required this.transfer,
    required this.destinationAccountNumber,
    required this.destinationBankName,
  });

  @override
  State<TransferSuccessScreen> createState() => _TransferSuccessScreenState();
}

class _TransferSuccessScreenState extends State<TransferSuccessScreen> {
  bool _isSavedBeneficiary = false;
  bool _isSavingBeneficiary = false;

  void _saveBeneficiary() async {
    final nicknameController =
        TextEditingController(text: widget.destinationAccountNumber);
    final nameController = TextEditingController(text: 'Người nhận');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lưu vào danh bạ thụ hưởng',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nicknameController,
              decoration: const InputDecoration(labelText: 'Tên gợi nhớ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tên chủ tài khoản'),
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
              Navigator.pop(ctx);
              setState(() => _isSavingBeneficiary = true);
              try {
                await BankingService.createBeneficiary(
                  nickname: nicknameController.text.trim(),
                  accountNumber: widget.destinationAccountNumber,
                  accountName: nameController.text.trim(),
                  bankCode: widget.transfer.isInternal ? null : 'BANK',
                );
                if (mounted) {
                  await context.read<BankingProvider>().loadBeneficiaries();
                  setState(() => _isSavedBeneficiary = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Đã lưu vào danh bạ người thụ hưởng')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: AppColors.error),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSavingBeneficiary = false);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isCopyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              if (isCopyable) ...[
                const SizedBox(width: 4),
                const Icon(Icons.copy,
                    size: 14, color: AppColors.textSecondary),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    final isPendingExternal = t.status == 'pending_external';

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Biên lai giao dịch'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Success Badge & Header
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: isPendingExternal
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPendingExternal
                          ? Icons.hourglass_top
                          : Icons.check_circle,
                      size: 48,
                      color: isPendingExternal
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    isPendingExternal
                        ? 'Giao dịch đang xử lý liên ngân hàng'
                        : 'Chuyển tiền thành công!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    Formatters.formatCurrency(t.amount, currency: t.currency),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Receipt Card
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Trạng thái',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          StatusBadge(status: t.status),
                        ],
                      ),
                      const Divider(height: 20),
                      _buildRow('Mã giao dịch', t.reference, isCopyable: true),
                      _buildRow(
                          'Thời gian',
                          Formatters.formatDateTime(
                              t.completedAt ?? t.createdAt)),
                      _buildRow('Tài khoản thụ hưởng',
                          widget.destinationAccountNumber),
                      _buildRow(
                          'Ngân hàng thụ hưởng', widget.destinationBankName),
                      _buildRow('Phí giao dịch', '0 ₫'),
                      const Divider(height: 20),
                      _buildRow('Nội dung', t.description ?? 'Chuyen tien'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Save Beneficiary button if not saved
                if (!_isSavedBeneficiary)
                  OutlinedButton.icon(
                    onPressed: _isSavingBeneficiary ? null : _saveBeneficiary,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                    label: const Text('Lưu người thụ hưởng này'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),

                const SizedBox(height: 20),

                CustomButton(
                  text: 'Thực hiện giao dịch mới',
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TransferFormScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),

                CustomButton(
                  text: 'Về trang chủ',
                  isOutlined: true,
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const MainNavigationScreen()),
                      (route) => false,
                    );
                  },
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
