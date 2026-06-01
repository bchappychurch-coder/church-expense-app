import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String bankName;
  final String bankAccount;
  final String role; // 'member' | 'approver' | 'manager'
  String fcmToken;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.bankName,
    required this.bankAccount,
    required this.role,
    this.fcmToken = '',
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      bankName: data['bankName'] ?? '',
      bankAccount: data['bankAccount'] ?? '',
      role: data['role'] ?? 'member',
      fcmToken: data['fcmToken'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'bankName': bankName,
        'bankAccount': bankAccount,
        'role': role,
        'fcmToken': fcmToken,
      };

  bool get isApprover => role == 'approver';
  bool get isManager => role == 'manager';
}
