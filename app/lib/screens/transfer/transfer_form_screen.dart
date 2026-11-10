import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/beneficiary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/banking_provider.dart';
import '../../services/transfer_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'transfer_confirm_screen.dart';

class TransferFormScreen extends StatefulWidget {
  final BeneficiaryModel? initialBeneficiary;

  const TransferFormScreen({super.key, this.initialBeneficiary});

  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _destAccountController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late TabController _tabController;
  bool _isInterbank = false;
  String? _selectedBankCode = 'VCB';
  bool _isLoading = false;

  final List<Map<String, String>> _popularBanks = const [
    {'code': 'VCB', 'name': 'Vietcombank'},
    {'code': 'TCB', 'name': 'Techcombank'},
    {'code': 'MB', 'name': 'MBBank'},
    {'code': 'ACB', 'name': 'ACB'},
    {'code': 'VPB', 'name': 'VPBank'},
    {'code': 'BIDV', 'name': 'BIDV'},
  ];

  final List<double> _quickAmounts = const [
    50000,
    100000,
    500000,
    1000000,
    2000000,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _isInterbank = _tabController.index == 1;
      });
    });

    final userName =
        context.read<AuthProvider>().currentUser?.fullName ?? 'KHACH HANG';
    _descriptionController.text = '$userName chuyen tien';

    if (widget.initialBeneficiary != null) {
      final b = widget.initialBeneficiary!;
      _destAccountController.text = b.accountNumber;
      if (!b.isInternal && b.bankCode != null) {
        _isInterbank = true;
        _selectedBankCode = b.bankCode;
        _tabController.index = 1;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _destAccountController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showBeneficiaryPicker() {
    final beneficiaries = context.read<BankingProvider>().beneficiaries;
    if (beneficiaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Danh bạ thụ hưởng chưa có người nhận nào')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn người thụ hưởng đã lưu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: beneficiaries.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final item = beneficiaries[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primaryLight.withValues(alpha: 0.15),
                        child: Text(
                          item.nickname.isNotEmpty
                              ? item.nickname[0].toUpperCase()
                              : 'B',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(item.nickname,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${item.accountNumber} • ${item.isInternal ? "Nội bộ" : (item.bankCode ?? "Liên ngân hàng")}'),
                      onTap: () {
                        setState(() {
                          _destAccountController.text = item.accountNumber;
                          if (!item.isInternal) {
                            _isInterbank = true;
                            _selectedBankCode = item.bankCode ?? 'VCB';
                            _tabController.index = 1;
                          } else {
                            _isInterbank = false;
                            _tabController.index = 0;
                          }
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final bankingProvider = context.read<BankingProvider>();
    final sourceAccount = bankingProvider.selectedAccount;

    if (sourceAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy tài khoản nguồn')),
      );
      return;
    }

    final amount = double.tryParse(
            _amountController.text.replaceAll(',', '').replaceAll('.', '')) ??
        0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền chuyển phải lớn hơn 0 ₫')),
      );
      return;
    }

    if (amount > sourceAccount.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số dư khả dụng không đủ để thực hiện giao dịch'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final transfer = await TransferService.createTransfer(
        sourceAccountId: sourceAccount.id,
        destinationAccountNumber: _destAccountController.text.trim(),
        destinationBankCode: _isInterbank ? _selectedBankCode : null,
        amount: amount,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransferConfirmScreen(
            transfer: transfer,
            destinationAccountNumber: _destAccountController.text.trim(),
            destinationBankName: _isInterbank
                ? (_popularBanks.firstWhere(
                        (b) => b['code'] == _selectedBankCode,
                        orElse: () =>
                            {'name': _selectedBankCode ?? ''})['name'] ??
                    '')
                : 'SE113 Bank (Nội bộ)',
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
    final bankingProvider = context.watch<BankingProvider>();
    final sourceAccount = bankingProvider.selectedAccount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chuyển tiền'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0F8),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: AppColors.primary, size: 23),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chuyển tiền an toàn',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark)),
                            SizedBox(height: 3),
                            Text(
                                'Kiểm tra kỹ thông tin người nhận trước khi tiếp tục.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                // Source Account Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Từ tài khoản nguồn',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sourceAccount?.accountNumber ?? '000000000000',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            Formatters.formatCurrency(
                                sourceAccount?.balance ?? 0.0),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Transfer Type Tabs
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Nội bộ SE113'),
                      Tab(text: 'Liên ngân hàng 24/7'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Interbank Bank Selector
                if (_isInterbank) ...[
                  const Text(
                    'Ngân hàng thụ hưởng',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
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
                        value: _selectedBankCode,
                        isExpanded: true,
                        items: _popularBanks.map((bank) {
                          return DropdownMenuItem<String>(
                            value: bank['code'],
                            child: Text('${bank['name']} (${bank['code']})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedBankCode = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Destination Account input
                CustomTextField(
                  controller: _destAccountController,
                  label: 'Số tài khoản nhận',
                  hint: 'Nhập số tài khoản thụ hưởng',
                  prefixIcon: Icons.account_box_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  suffixIcon: TextButton.icon(
                    onPressed: _showBeneficiaryPicker,
                    icon: const Icon(Icons.contacts, size: 16),
                    label:
                        const Text('Danh bạ', style: TextStyle(fontSize: 12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập số tài khoản nhận';
                    }
                    if (sourceAccount != null &&
                        val.trim() == sourceAccount.accountNumber &&
                        !_isInterbank) {
                      return 'Không thể chuyển đến chính tài khoản nguồn';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Amount input
                CustomTextField(
                  controller: _amountController,
                  label: 'Số tiền chuyển (VND)',
                  hint: '0',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập số tiền';
                    }
                    final numVal = double.tryParse(val) ?? 0;
                    if (numVal <= 0) return 'Số tiền phải lớn hơn 0';
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Quick amount chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickAmounts.map((amt) {
                    return ActionChip(
                      label: Text(
                        Formatters.formatCurrency(amt),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      onPressed: () {
                        setState(() {
                          _amountController.text = amt.toInt().toString();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Description
                CustomTextField(
                  controller: _descriptionController,
                  label: 'Nội dung chuyển tiền',
                  hint: 'Nhập lời nhắn chuyển tiền',
                  prefixIcon: Icons.notes,
                ),
                const SizedBox(height: 30),

                // Continue Button
                CustomButton(
                  text: 'Tiếp tục',
                  isLoading: _isLoading,
                  onPressed: _handleContinue,
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
