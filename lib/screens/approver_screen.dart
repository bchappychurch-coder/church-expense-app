import 'package:flutter/material.dart';
import '../widgets/receipt_image_viewer.dart';
import 'package:provider/provider.dart';
import '../models/expense_model.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/status_badge.dart';
import 'department_screen.dart';

class ApproverScreen extends StatefulWidget {
  const ApproverScreen({super.key});

  @override
  State<ApproverScreen> createState() => _ApproverScreenState();
}

class _ApproverScreenState extends State<ApproverScreen> {
  // 0=1주, 1=1개월, 2=3개월, 3=직접입력
  int _selectedPeriod = 0;
  DateTime? _customFrom;
  DateTime? _customTo;

  DateTime get _fromDate {
    if (_selectedPeriod == 3 && _customFrom != null) return _customFrom!;
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 1: return now.subtract(const Duration(days: 30));
      case 2: return now.subtract(const Duration(days: 90));
      default: return now.subtract(const Duration(days: 7));
    }
  }

  DateTime get _toDate {
    if (_selectedPeriod == 3 && _customTo != null) return _customTo!;
    return DateTime.now();
  }

  String get _periodLabel {
    if (_selectedPeriod == 3 && _customFrom != null && _customTo != null) {
      return '${_customFrom!.month}/${_customFrom!.day} ~ ${_customTo!.month}/${_customTo!.day}';
    }
    return ['최근 1주', '최근 1개월', '최근 3개월', '직접입력'][_selectedPeriod];
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final from = await showDatePicker(
      context: context,
      initialDate: _customFrom ?? now.subtract(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: '시작일 선택',
    );
    if (from == null || !mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _customTo ?? now,
      firstDate: from,
      lastDate: now,
      helpText: '종료일 선택',
    );
    if (to == null || !mounted) return;
    setState(() {
      _customFrom = from;
      _customTo = to;
      _selectedPeriod = 3;
    });
  }

  List<ExpenseModel> _filterByPeriod(List<ExpenseModel> all) {
    final from = _fromDate;
    final to = _toDate.add(const Duration(days: 1));
    return all.where((e) {
      final dt = e.createdAt.toDate();
      return dt.isAfter(from) && dt.isBefore(to);
    }).toList();
  }

  String _formatAmount(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted원';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppProvider>().currentUser!;
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        title: Text('${user.name}님 — 결재 승인',
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            tooltip: '홈',
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
          TextButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DepartmentScreen())),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('지출 신청',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: service.getAllExpensesForApprover(),
        builder: (context, allSnapshot) {
          final allExpenses = allSnapshot.data ?? [];
          final periodExpenses = _filterByPeriod(allExpenses);
          final periodTotal = periodExpenses.fold<int>(0, (sum, e) => sum + e.amount);

          return StreamBuilder<List<ExpenseModel>>(
            stream: service.getPendingExpenses(),
            builder: (context, pendingSnapshot) {
          if (pendingSnapshot.connectionState == ConnectionState.waiting &&
              !pendingSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pending = pendingSnapshot.data ?? [];

          return Column(
                children: [
                  // 기간 선택 칩
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        _PeriodChip(label: '1주', selected: _selectedPeriod == 0,
                            onTap: () => setState(() => _selectedPeriod = 0)),
                        const SizedBox(width: 8),
                        _PeriodChip(label: '1개월', selected: _selectedPeriod == 1,
                            onTap: () => setState(() => _selectedPeriod = 1)),
                        const SizedBox(width: 8),
                        _PeriodChip(label: '3개월', selected: _selectedPeriod == 2,
                            onTap: () => setState(() => _selectedPeriod = 2)),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: _selectedPeriod == 3 ? _periodLabel : '직접입력',
                          selected: _selectedPeriod == 3,
                          onTap: _pickCustomRange,
                          icon: Icons.calendar_today,
                        ),
                      ],
                    ),
                  ),
                  // 기간 합산 배너
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    color: const Color(0xFFEEF2FF),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$_periodLabel · ${periodExpenses.length}건',
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF6366F1))),
                        Text(_formatAmount(periodTotal),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4338CA))),
                      ],
                    ),
                  ),
                  // 승인 대기 배너
                  if (pending.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      color: const Color(0xFFFEF9C3),
                      child: Text(
                        '승인 대기 ${pending.length}건',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E)),
                      ),
                    ),
                  // 목록
                  Expanded(
                    child: pending.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 64, color: Color(0xFF16A34A)),
                                SizedBox(height: 16),
                                Text('처리할 결재가 없습니다',
                                    style: TextStyle(
                                        fontSize: 20, color: Color(0xFF6B7280))),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: pending.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _ApprovalCard(
                              expense: pending[i],
                              approverId: user.id,
                              service: service,
                            ),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1) : Colors.white,
          border: Border.all(
              color: selected ? const Color(0xFF6366F1) : const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13,
                  color: selected ? Colors.white : const Color(0xFF6B7280)),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final ExpenseModel expense;
  final String approverId;
  final FirestoreService service;

  const _ApprovalCard({
    required this.expense,
    required this.approverId,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.userName,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${expense.department} · ${expense.purpose}',
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF6B7280))),
                  Text(expense.description,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF374151))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(expense.formattedAmount,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                StatusBadge(expense: expense),
                const SizedBox(height: 6),
                Text(expense.formattedDate,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ApprovalDetail(
        expense: expense,
        approverId: approverId,
        service: service,
      ),
    );
  }
}

class _ApprovalDetail extends StatefulWidget {
  final ExpenseModel expense;
  final String approverId;
  final FirestoreService service;

  const _ApprovalDetail({
    required this.expense,
    required this.approverId,
    required this.service,
  });

  @override
  State<_ApprovalDetail> createState() => _ApprovalDetailState();
}

class _ApprovalDetailState extends State<_ApprovalDetail> {
  bool _processing = false;

  Future<void> _approve() async {
    setState(() => _processing = true);
    await widget.service.approveExpense(
        widget.expense.id!, widget.approverId);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('승인 완료했습니다')),
      );
    }
  }

  Future<void> _reject() async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _processing = true);
    await widget.service.rejectExpense(widget.expense.id!, reason);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반려 처리했습니다')),
      );
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('반려 사유 입력', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            hintText: '반려 사유를 입력해 주세요',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: const Text('반려',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    return SafeArea(
      top: false,
      child: Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(e.userName,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _Row('부서', e.department),
          _Row('용도', e.purpose),
          _Row('내용', e.description),
          _Row('금액', e.formattedAmount),
          _Row('계좌', '${e.bankName} ${e.bankAccount}'),
          const SizedBox(height: 16),
          if (e.receiptImageUrl.isNotEmpty) ...[
            const Text('영수증',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 8),
            ReceiptImageViewer(imageUrl: e.receiptImageUrl),
          ],
          const SizedBox(height: 20),
          if (!_processing) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reject,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('반려',
                        style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('승인',
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF9CA3AF)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('나중에 결정하기',
                    style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ] else
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, color: Color(0xFF9CA3AF))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
