import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense_model.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';

class PurposeScreen extends StatefulWidget {
  final String receiptImagePath;
  final int amount;
  final String bankName;
  final String accountNumber;
  final XFile? xFile;

  const PurposeScreen({
    super.key,
    required this.receiptImagePath,
    required this.amount,
    required this.bankName,
    required this.accountNumber,
    this.xFile,
  });

  @override
  State<PurposeScreen> createState() => _PurposeScreenState();
}

class _PurposeScreenState extends State<PurposeScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _descController = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _descController.text.trim().isNotEmpty &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    try {
      final user = context.read<AppProvider>().currentUser!;
      final department = context.read<AppProvider>().selectedDepartment!;

      // 1. 영수증 사진 업로드 (있는 경우에만)
      String imageUrl = '';
      if (widget.receiptImagePath.isNotEmpty || widget.xFile != null) {
        imageUrl = await _storageService.uploadReceipt(
            widget.receiptImagePath, user.id,
            userName: user.name,
            purpose: _descController.text.trim(),
            xFile: widget.xFile);
      }

      // 2. Firestore에 지출 저장
      await _firestoreService.createExpense(ExpenseModel(
        userId: user.id,
        userName: user.name,
        department: department,
        purpose: _descController.text.trim(),
        description: _descController.text.trim(),
        amount: widget.amount,
        receiptImageUrl: imageUrl,
        bankName: widget.bankName,
        bankAccount: widget.accountNumber,
        status: 'pending',
        createdAt: Timestamp.now(),
      ));

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
      setState(() => _submitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 64),
            SizedBox(height: 16),
            Text('결재가 접수되었습니다',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('승인자에게 알림이 전송되었습니다',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('확인',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final user = appProvider.currentUser!;
    final department = appProvider.selectedDepartment!;

    final formattedAmount = widget.amount
        .toString()
        .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        title: const Text('사용 내역',
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
            // 진행 단계
            _StepBar(current: 4),
            const SizedBox(height: 28),

            const Text('사용 내역을 적어주세요',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 20),

            TextField(
                  controller: _descController,
                  style: const TextStyle(fontSize: 22),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '예) 12/20 중식비, 전도지 인쇄비 3매',
                    hintStyle: const TextStyle(
                        fontSize: 18, color: Color(0xFF9CA3AF)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
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

            const SizedBox(height: 24),

            // 신청 요약
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('신청 내용 확인',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 10),
                  _SummaryRow('신청자', user.name),
                  _SummaryRow('부서', department),
                  _SummaryRow('금액', '$formattedAmount원'),
                  _SummaryRow('은행', widget.bankName +
                      (widget.accountNumber.isNotEmpty
                          ? '  ${widget.accountNumber}'
                          : '')),
                  if (_descController.text.trim().isNotEmpty)
                    _SummaryRow('내용', _descController.text.trim()),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 결재 올리기 버튼
            SizedBox(
              height: 64,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '결재 올리기',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
              ),
            ),

            if (!_canSubmit && _descController.text.trim().isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '사용 내역을 입력해 주세요',
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF9CA3AF))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937))),
          ),
        ],
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
