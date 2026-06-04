class BankAccount {
  final String id;
  final String bankName;
  final String accountNumber;

  BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'bankName': bankName,
        'accountNumber': accountNumber,
      };

  factory BankAccount.fromMap(Map<String, dynamic> map) => BankAccount(
        id: map['id'] as String? ?? '',
        bankName: map['bankName'] as String? ?? '',
        accountNumber: map['accountNumber'] as String? ?? '',
      );

  String get displayText => '$bankName  $accountNumber';
}
