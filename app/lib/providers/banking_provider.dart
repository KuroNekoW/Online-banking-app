import 'package:flutter/material.dart';
import '../core/storage/storage_service.dart';
import '../models/account_model.dart';
import '../models/beneficiary_model.dart';
import '../models/transaction_model.dart';
import '../services/banking_service.dart';

class BankingProvider extends ChangeNotifier {
  List<AccountModel> _accounts = [];
  AccountModel? _selectedAccount;
  bool _isBalanceHidden = false;
  List<TransactionModel> _recentTransactions = [];
  List<BeneficiaryModel> _beneficiaries = [];
  int _unreadNotificationCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<AccountModel> get accounts => _accounts;
  AccountModel? get selectedAccount => _selectedAccount;
  bool get isBalanceHidden => _isBalanceHidden;
  List<TransactionModel> get recentTransactions => _recentTransactions;
  List<BeneficiaryModel> get beneficiaries => _beneficiaries;
  int get unreadNotificationCount => _unreadNotificationCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  BankingProvider() {
    _isBalanceHidden = StorageService.isBalanceHidden();
  }

  void toggleBalanceVisibility() {
    _isBalanceHidden = !_isBalanceHidden;
    StorageService.setBalanceHidden(_isBalanceHidden);
    notifyListeners();
  }

  void selectAccount(AccountModel account) {
    _selectedAccount = account;
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Load accounts
      _accounts = await BankingService.getAccounts();
      if (_accounts.isNotEmpty) {
        // Keep currently selected or default to first
        if (_selectedAccount != null) {
          final matched = _accounts.where((a) => a.id == _selectedAccount!.id);
          _selectedAccount = matched.isNotEmpty ? matched.first : _accounts.first;
        } else {
          _selectedAccount = _accounts.first;
        }
      }

      // 2. Load recent transactions (first page, limit 5)
      try {
        final txResult = await BankingService.getTransactions(
          accountId: _selectedAccount?.id,
          page: 1,
          pageSize: 5,
        );
        _recentTransactions = txResult['items'] as List<TransactionModel>;
      } catch (_) {}

      // 3. Load notifications count
      try {
        final notifResult = await BankingService.getNotifications(limit: 1);
        _unreadNotificationCount = notifResult['unread_count'] as int;
      } catch (_) {}

      // 4. Load beneficiaries
      try {
        _beneficiaries = await BankingService.getBeneficiaries();
      } catch (_) {}
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshBalance() async {
    if (_selectedAccount == null) return;
    try {
      final newBalance = await BankingService.getAccountBalance(_selectedAccount!.id);
      final index = _accounts.indexWhere((a) => a.id == _selectedAccount!.id);
      if (index != -1) {
        final updated = AccountModel(
          id: _selectedAccount!.id,
          accountNumber: _selectedAccount!.accountNumber,
          currency: _selectedAccount!.currency,
          status: _selectedAccount!.status,
          balance: newBalance,
          updatedAt: DateTime.now(),
        );
        _accounts[index] = updated;
        _selectedAccount = updated;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadBeneficiaries() async {
    try {
      _beneficiaries = await BankingService.getBeneficiaries();
      notifyListeners();
    } catch (_) {}
  }
}
