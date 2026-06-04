import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/bank_account.dart';

class AppProvider extends ChangeNotifier {
  UserModel? _currentUser;
  String? _selectedDepartment;

  UserModel? get currentUser => _currentUser;
  String? get selectedDepartment => _selectedDepartment;

  void setUser(UserModel user) {
    _currentUser = user;
    _selectedDepartment = null;
    notifyListeners();
  }

  void setDepartment(String department) {
    _selectedDepartment = department;
    notifyListeners();
  }

  void updateUserAccounts(List<BankAccount> accounts) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(accounts: accounts);
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    _selectedDepartment = null;
    notifyListeners();
  }
}
