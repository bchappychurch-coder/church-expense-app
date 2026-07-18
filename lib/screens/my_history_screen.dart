import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense_model.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/receipt_image_viewer.dart';

class MyHistoryScreen extends StatefulWidget {
  const MyHistoryScreen({super.key});

  @override
  State<MyHistoryScreen> createState() => _MyHistoryScreenState();
}

class _MyHistoryScreenState extends State<MyHistoryScreen> {
  // 0=1주, 1=1개월, 2=3개월, 3=직접입력
  int _selectedPeriod = 0;
  DateTime? _customFrom;
  DateTime? _customTo;

  DateTime get _fromDate {
    if (_selectedPeriod == 3 && _customFrom != null) return _customFrom!;
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 1:
        return now.subtract(const Duration(days: 30));
      case 2:
        return now.subtract(const Duration(days: 90));
      default:
        return now.subtract(const Duration(days: 7));
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
        title: const Text('내 청구 내역',
            style: TextStyle(color: Colors.white, fontSize: 20)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            tooltip: '홈',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: service.getMyExpenses(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return const Center(
              child: Text('데이터를 불러올 수 없습니다.\n인터넷 연결을 확인해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF))),
            );
          }

          final all = snapshot.data ?? [];
          final expenses = _filterByPeriod(all);
          final total = expenses.fold<int>(0, (sum, e) => sum + e.amount);

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
              // 합산 배너
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: const Color(0xFFEEF2FF),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$_periodLabel · ${expenses.length}건',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF6366F1))),
                    Text(_formatAmount(total),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4338CA))),
                  ],
                ),
              ),
              // 목록
              Expanded(
                child: expenses.isEmpty
                    ? const Center(
                        child: Text('해당 기간에 신청 내역이 없습니다',
                            style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF))),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: expenses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _ExpenseCard(expense: expenses[i]),
                      ),
              ),
            ],
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

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  const _ExpenseCard({required this.expense});

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
                  Text('${expense.department} · ${expense.purpose}',
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  Text(expense.description,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(expense.formattedDate,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF9CA3AF))),
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
      builder: (_) => _ExpenseDetail(expense: expense),
    );
  }
}

class _ExpenseDetail extends StatelessWidget {
  final ExpenseModel expense;
  const _ExpenseDetail({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
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
                  borderRadius: BorderRadius.circular(2),
                ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(expense.formattedAmount,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              StatusBadge(expense: expense),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow('부서', expense.department),
          _DetailRow('용도', expense.purpose),
          _DetailRow('내용', expense.description),
          _DetailRow('신청일', expense.formattedDate),
          if (expense.status == 'rejected' && expense.rejectedReason != null)
            _DetailRow('반려 사유', expense.rejectedReason!,
                valueColor: const Color(0xFFDC2626)),
          const SizedBox(height: 16),
          if (expense.receiptImageUrl.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('영수증',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 8),
            ReceiptImageViewer(imageUrl: expense.receiptImageUrl),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, color: Color(0xFF9CA3AF))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF1F2937))),
          ),
        ],
      ),
    );
  }
}
