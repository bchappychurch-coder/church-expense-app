import 'package:cloud_firestore/cloud_firestore.dart';
import 'bank_account.dart';

class UserModel {
  final String id;
  final String name;
  final String phone;
  final List<BankAccount> accounts;
  final String role; // 'member' | 'approver' | 'manager'
  String fcmToken;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.accounts = const [],
    required this.role,
    this.fcmToken = '',
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<BankAccount> accounts = [];
    if (data['accounts'] != null) {
      accounts = (data['accounts'] as List)
          .map((a) => BankAccount.fromMap(a as Map<String, dynamic>))
          .toList();
    } else if ((data['bankName'] as String? ?? '').isNotEmpty) {
      // 하위호환: 기존 단일 bankName/bankAccount 필드
      accounts = [
        BankAccount(
          id: 'legacy',
          bankName: data['bankName'] as String,
          accountNumber: data['bankAccount'] as String? ?? '',
        ),
      ];
    }

    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      accounts: accounts,
      role: data['role'] ?? 'member',
      fcmToken: data['fcmToken'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'accounts': accounts.map((a) => a.toMap()).toList(),
        'role': role,
        'fcmToken': fcmToken,
      };

  UserModel copyWith({List<BankAccount>? accounts}) => UserModel(
        id: id,
        name: name,
        phone: phone,
        accounts: accounts ?? this.accounts,
        role: role,
        fcmToken: fcmToken,
      );

  bool get isApprover => role == 'approver';
  bool get isManager => role == 'manager';
}
