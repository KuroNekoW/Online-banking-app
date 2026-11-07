import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/banking_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class AddBeneficiaryScreen extends StatefulWidget {
  const AddBeneficiaryScreen({super.key});

  @override
  State<AddBeneficiaryScreen> createState() => _AddBeneficiaryScreenState();
}

class _AddBeneficiaryScreenState extends State<AddBeneficiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  String? _selectedBank = 'INTERNAL';
  bool _isLoading = false;

  final List<Map<String, String>> _banks = const [
    {'code': 'INTERNAL', 'name': 'Nội bộ ngân hàng SE113'},
    {'code': 'VCB', 'name': 'Vietcombank'},
    {'code': 'TCB', 'name': 'Techcombank'},
    {'code': 'MB', 'name': 'MBBank'},
    {'code': 'ACB', 'name': 'ACB'},
    {'code': 'VPB', 'name': 'VPBank'},
    {'code': 'BIDV', 'name': 'BIDV'},
  ];

  @override
  void dispose() {
    _nicknameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final isInternal = _selectedBank == 'INTERNAL';
      await BankingService.createBeneficiary(
        nickname: _nicknameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountName: _accountNameController.text.trim(),
        bankCode: isInternal ? null : _selectedBank,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm người thụ hưởng thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
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
        title: const Text('Thêm người thụ hưởng'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _nicknameController,
                  label: 'Tên gợi nhớ',
                  hint: 'Ví dụ: Mẹ, Bạn Hào, Anh Minh',
                  prefixIcon: Icons.badge_outlined,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tên gợi nhớ';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text(
                  'Ngân hàng thụ hưởng',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBank,
                      isExpanded: true,
                      items: _banks.map((bank) {
                        return DropdownMenuItem<String>(
                          value: bank['code'],
                          child: Text(bank['name']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedBank = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _accountNumberController,
                  label: 'Số tài khoản',
                  hint: 'Nhập số tài khoản ngân hàng',
                  prefixIcon: Icons.account_box_outlined,
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Vui lòng nhập số tài khoản';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _accountNameController,
                  label: 'Tên chủ tài khoản',
                  hint: 'NGUYEN VAN B',
                  prefixIcon: Icons.person_outline,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tên chủ tài khoản';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Lưu thông tin',
                  isLoading: _isLoading,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
