import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/beneficiary_model.dart';
import '../../providers/banking_provider.dart';
import '../../services/banking_service.dart';
import '../transfer/transfer_form_screen.dart';
import 'add_beneficiary_screen.dart';

class BeneficiaryListScreen extends StatefulWidget {
  const BeneficiaryListScreen({super.key});

  @override
  State<BeneficiaryListScreen> createState() => _BeneficiaryListScreenState();
}

class _BeneficiaryListScreenState extends State<BeneficiaryListScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await context.read<BankingProvider>().loadBeneficiaries();
    if (mounted) setState(() => _isLoading = false);
  }

  void _deleteBeneficiary(BeneficiaryModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa người thụ hưởng "${item.nickname}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BankingService.deleteBeneficiary(item.id);
        if (mounted) {
          await context.read<BankingProvider>().loadBeneficiaries();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa người thụ hưởng')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final beneficiaries = context.watch<BankingProvider>().beneficiaries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh bạ thụ hưởng'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('Thêm mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddBeneficiaryScreen()),
          );
          if (added == true) {
            _refresh();
          }
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: _isLoading && beneficiaries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : beneficiaries.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.contacts_outlined, size: 64, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'Chưa có người thụ hưởng nào',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Lưu thông tin người nhận để chuyển tiền nhanh hơn',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: beneficiaries.length,
                      itemBuilder: (context, index) {
                        final item = beneficiaries[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primaryLight.withOpacity(0.12),
                              child: Text(
                                item.nickname.isNotEmpty ? item.nickname[0].toUpperCase() : 'B',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(
                              item.nickname,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.accountName} • ${item.accountNumber}',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: item.isInternal ? Colors.blue.shade50 : Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.isInternal ? 'Nội bộ SE113' : (item.bankCode ?? 'Liên ngân hàng'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: item.isInternal ? AppColors.primary : AppColors.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                                  tooltip: 'Chuyển tiền nhanh',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TransferFormScreen(initialBeneficiary: item),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.textMuted),
                                  tooltip: 'Xóa',
                                  onPressed: () => _deleteBeneficiary(item),
                                ),
                              ],
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
