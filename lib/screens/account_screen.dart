import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bank_account.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import 'purpose_screen.dart';

class AccountScreen extends StatefulWidget {
  final String receiptImagePath;
  final int amount;

  const AccountScreen({
    super.key,
    required this.receiptImagePath,
    required this.amount,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _firestoreService = FirestoreService();

  String? _selectedAccountId;
  bool _addingNew = false;

  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  bool _saveNewAccount = true;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppProvider>().currentUser!;
    if (user.accounts.isNotEmpty) {
      _selectedAccountId = user.accounts.first.id;
    } else {
      _addingNew = true;
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  bool get _canProceed {
    if (_selectedAccountId != null && !_addingNew) return true;
    if (_addingNew) return _bankNameController.text.trim().isNotEmpty;
    return false;
  }

  Future<void> _proceed() async {
    final user = context.read<AppProvider>().currentUser!;

    String bankName;
    String accountNumber;

    if (_selectedAccountId != null && !_addingNew) {
      final account = user.accounts.firstWhere((a) => a.id == _selectedAccountId);
      bankName = account.bankName;
      accountNumber = account.accountNumber;
    } else {
      bankName = _bankNameController.text.trim();
      accountNumber = _accountNumberController.text.trim();

      if (_saveNewAccount) {
        final newAccount = BankAccount(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          bankName: bankName,
          accountNumber: accountNumber,
        );
        final updatedAccounts = [...user.accounts, newAccount];
        await _firestoreService.saveUserAccounts(user.id, updatedAccounts);
        if (mounted) {
          context.read<AppProvider>().updateUserAccounts(updatedAccounts);
        }
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurposeScreen(
          receiptImagePath: widget.receiptImagePath,
          amount: widget.amount,
          bankName: bankName,
          accountNumber: accountNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        title: const Text('계좌 정보',
            style: TextStyle(color: Colors.white, fontSize: 20)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            tooltip: '홈',
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepBar(current: 3),
            const SizedBox(height: 28),
            const Text(
              '입금받을 계좌를 알려주세요',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 6),
            const Text(
              '계좌번호가 없어도 은행 이름만 써도 됩니다',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 24),

            // 저장된 계좌 목록
            if (user.accounts.isNotEmpty) ...[
              const Text('저장된 계좌',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 10),
              ...user.accounts.map((account) {
                final selected =
                    _selectedAccountId == account.id && !_addingNew;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedAccountId = account.id;
                    _addingNew = false;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEDE9FE)
                          : const Color(0xFFF9FAFB),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF6366F1)
                            : const Color(0xFFE5E7EB),
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance,
                          color: selected
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF9CA3AF),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.bankName,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: selected
                                      ? const Color(0xFF4338CA)
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                              if (account.accountNumber.isNotEmpty)
                                Text(
                                  account.accountNumber,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF6B7280)),
                                ),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle,
                              color: Color(0xFF6366F1), size: 24),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _addingNew = true;
                  _selectedAccountId = null;
                  _bankNameController.clear();
                  _accountNumberController.clear();
                }),
                icon: const Icon(Icons.add, color: Color(0xFF6366F1)),
                label: const Text('다른 계좌 입력하기',
                    style: TextStyle(
                        fontSize: 16, color: Color(0xFF6366F1))),
              ),
            ],

            // 새 계좌 입력 폼
            if (_addingNew || user.accounts.isEmpty) ...[
              if (user.accounts.isNotEmpty)
                const Divider(height: 28),
              if (user.accounts.isEmpty)
                const SizedBox(height: 0),

              // 은행명 직접 입력
              Row(
                children: const [
                  Text('은행명',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  SizedBox(width: 6),
                  Text('(필수)',
                      style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bankNameController,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: '예) 국민은행, 카카오뱅크',
                  hintStyle: const TextStyle(fontSize: 16, color: Color(0xFF9CA3AF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 20),

              // 계좌번호 (선택)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text('계좌번호',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151))),
                      SizedBox(width: 6),
                      Text('(없으면 안 써도 됩니다)',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _accountNumberController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: '예) 1234-56-789012',
                      hintStyle: const TextStyle(
                          fontSize: 16, color: Color(0xFF9CA3AF)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF6366F1), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 저장 여부
              GestureDetector(
                onTap: () =>
                    setState(() => _saveNewAccount = !_saveNewAccount),
                child: Row(
                  children: [
                    Icon(
                      _saveNewAccount
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: const Color(0xFF6366F1),
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    const Text('이 계좌 저장해서 다음에 또 쓰기',
                        style: TextStyle(
                            fontSize: 16, color: Color(0xFF374151))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: _canProceed ? _proceed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('다음',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),

            if (!_canProceed && _addingNew)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '은행을 선택해 주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFFDC2626)),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int current;
  const _StepBar({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
            height: 6,
            decoration: BoxDecoration(
              color: i + 1 <= current
                  ? const Color(0xFF6366F1)
                  : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
