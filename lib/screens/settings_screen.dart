import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bank_account.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/password_gate.dart';
import 'admin_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firestoreService = FirestoreService();
  bool _saving = false;


  Future<void> _saveAccounts(List<BankAccount> accounts) async {
    final user = context.read<AppProvider>().currentUser!;
    setState(() => _saving = true);
    try {
      await _firestoreService.saveUserAccounts(user.id, accounts);
      if (mounted) context.read<AppProvider>().updateUserAccounts(accounts);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addAccount() {
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('계좌 추가',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                const Text('은행명',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                const SizedBox(height: 8),
                TextField(
                  controller: bankNameController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: '예) 국민은행, 카카오뱅크',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF6366F1), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onChanged: (_) => setModalState(() {}),
                ),

                const SizedBox(height: 20),

                const Text('계좌번호 (없으면 안 써도 됩니다)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                const SizedBox(height: 8),
                TextField(
                  controller: accountNumberController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: '예) 1234-56-789012',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
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
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: bankNameController.text.trim().isEmpty
                      ? null
                      : () {
                          final account = BankAccount(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            bankName: bankNameController.text.trim(),
                            accountNumber:
                                accountNumberController.text.trim(),
                          );
                          final user =
                              context.read<AppProvider>().currentUser!;
                          final updated = [...user.accounts, account];
                          _saveAccounts(updated);
                          Navigator.pop(ctx);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('저장',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _deleteAccount(BankAccount account) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('계좌 삭제'),
        content: Text(
            '${account.bankName}${account.accountNumber.isNotEmpty ? " (${account.accountNumber})" : ""} 계좌를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              final user = context.read<AppProvider>().currentUser!;
              final updated =
                  user.accounts.where((a) => a.id != account.id).toList();
              _saveAccounts(updated);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('삭제',
                style: TextStyle(color: Colors.white)),
          ),
        ],
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
        title: Text('${user.name}님 계좌 관리',
            style: const TextStyle(color: Colors.white, fontSize: 20)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '저장된 계좌',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 6),
                const Text(
                  '계좌번호 없이 은행 이름만 저장해도 됩니다',
                  style:
                      TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 20),
                if (user.accounts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        '저장된 계좌가 없습니다\n아래 버튼으로 추가해 주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: user.accounts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final account = user.accounts[i];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            border: Border.all(
                                color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance,
                                  color: Color(0xFF6366F1), size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(account.bankName,
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937))),
                                    if (account.accountNumber.isNotEmpty)
                                      Text(account.accountNumber,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF6B7280))),
                                    if (account.accountNumber.isEmpty)
                                      const Text('계좌번호 미입력',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF9CA3AF))),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deleteAccount(account),
                                icon: const Icon(Icons.delete_outline,
                                    color: Color(0xFFDC2626), size: 24),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _addAccount,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('계좌 추가하기',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => showPasswordGate(context, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminSettingsScreen()),
                      );
                    }),
                    icon: const Icon(Icons.admin_panel_settings,
                        color: Color(0xFF6366F1)),
                    label: const Text('관리자 설정',
                        style: TextStyle(
                            fontSize: 18, color: Color(0xFF6366F1))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
