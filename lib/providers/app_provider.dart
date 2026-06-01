import 'package:flutter/material.dart';
import '../models/user_model.dart';

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

  void clearUser() {
    _currentUser = null;
    _selectedDepartment = null;
    notifyListeners();
  }
}
