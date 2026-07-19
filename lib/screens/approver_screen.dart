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
  int _selectedPeriod = 1;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _showPending = true;
  bool _showApproved = false;

  Set<String> _selectedExpenseIds = {};

  static const _pendingStatuses = {'pending', 'approved1'};
  static const _doneStatuses = {'approved', 'completed', 'rejected'};

  DateTime get _fromDate {
    if (_selectedPeriod == 3 && _customFrom != null) return _customFrom!;
    return DateTime.now().subtract(const Duration(days: 30));
  }

  DateTime get _toDate {
    if (_selectedPeriod == 3 && _customTo != null) return _customTo!;
    return DateTime.now();
  }

  String get _periodLabel {
    if (_selectedPeriod == 3 && _customFrom != null && _customTo != null) {
      return '${_customFrom!.month}/${_customFrom!.day} ~ ${_customTo!.month}/${_customTo!.day}';
    }
    return '최근 1개월';
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

  List<ExpenseModel> _filterExpenses(List<ExpenseModel> all) {
    final from = _fromDate;
    final to = _toDate.add(const Duration(days: 1));
    return all.where((e) {
      final dt = e.createdAt.toDate();
      if (!dt.isAfter(from) || !dt.isBefore(to)) return false;
      if (_showPending && _pendingStatuses.contains(e.status)) return true;
      if (_showApproved && _doneStatuses.contains(e.status)) return true;
      return false;
    }).toList();
  }

  String _formatAmount(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted원';
  }

  Future<void> _bulkApprove(FirestoreService service, String approverId) async {
    if (_selectedExpenseIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('일괄결재'),
        content: Text('선택한 ${_selectedExpenseIds.length}건을 일괄 승인하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('승인', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final id in _selectedExpenseIds) {
      await service.approveExpense(id, approverId);
    }
    setState(() => _selectedExpenseIds.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일괄 승인이 완료됐습니다'), backgroundColor: Color(0xFF16A34A)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppProvider>().currentUser!;
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
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
            onPressed: () => Navigator.of(context).pop(),
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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data ?? [];
          final filtered = _filterExpenses(all);
          final filteredTotal = filtered.fold<int>(0, (sum, e) => sum + e.amount);
          final selectedTotal = _selectedExpenseIds.isEmpty
              ? filteredTotal
              : filtered
                  .where((e) => _selectedExpenseIds.contains(e.id))
                  .fold<int>(0, (sum, e) => sum + e.amount);

          final pending = all.where((e) => e.status == 'pending').length;
          final inProgress = all.where((e) => e.status == 'approved1').length;
          final needAction = all.where((e) => e.status == 'approved').length;
          final completed = all.where((e) => e.status == 'completed').length;
          final rejected = all.where((e) => e.status == 'rejected').length;

          return Column(
            children: [
              // 요약 카드
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _SummaryCard('대기', pending, const Color(0xFFFEF9C3),
                        const Color(0xFF92400E)),
                    const SizedBox(width: 8),
                    _SummaryCard('승인중', inProgress,
                        const Color(0xFFEDE9FE), const Color(0xFF5B21B6)),
                    const SizedBox(width: 8),
                    _SummaryCard('처리필요', needAction,
                        const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
                    const SizedBox(width: 8),
                    _SummaryCard('완료', completed, const Color(0xFFF0FDF4),
                        const Color(0xFF166534)),
                    const SizedBox(width: 8),
                    _SummaryCard('반려', rejected, const Color(0xFFFEF2F2),
                        const Color(0xFF991B1B)),
                  ],
                ),
              ),

              // 처리 필요 강조 배너
              if (needAction > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  color: const Color(0xFFDCFCE7),
                  child: Text(
                    '⚡ 송금 처리 필요: $needAction건',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534)),
                  ),
                ),

              // 필터 행
              Container(
                color: const Color(0xFFF9FAFB),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _CheckChip(
                      label: '승인필요',
                      checked: _showPending,
                      color: const Color(0xFFF59E0B),
                      onChanged: (v) => setState(() {
                        _showPending = v;
                        if (!v) {
                          _selectedExpenseIds.removeWhere((id) => all
                              .where((e) => _pendingStatuses.contains(e.status))
                              .any((e) => e.id == id));
                        }
                      }),
                    ),
                    const SizedBox(width: 10),
                    _CheckChip(
                      label: '기결',
                      checked: _showApproved,
                      color: const Color(0xFF16A34A),
                      onChanged: (v) => setState(() => _showApproved = v),
                    ),
                    const Spacer(),
                    _PeriodChip(
                      label: _selectedPeriod == 3 ? _periodLabel : '기간직접입력',
                      selected: _selectedPeriod == 3,
                      onTap: _pickCustomRange,
                      icon: Icons.calendar_today,
                    ),
                  ],
                ),
              ),

              // 합산 + 일괄승인 배너
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFEEF2FF),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedExpenseIds.isEmpty
                          ? '$_periodLabel · ${filtered.length}건'
                          : '선택 ${_selectedExpenseIds.length}건',
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF6366F1))),
                    Row(
                      children: [
                        Text(_formatAmount(selectedTotal),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4338CA))),
                        if (_selectedExpenseIds.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _bulkApprove(service, user.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '일괄승인',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 목록
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          (!_showPending && !_showApproved)
                              ? '필터를 선택해 주세요'
                              : '해당 기간에 내역이 없습니다',
                          style: const TextStyle(
                              fontSize: 16, color: Color(0xFF9CA3AF)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final expense = filtered[i];
                          final isPending = _pendingStatuses.contains(expense.status);
                          return _ApprovalRow(
                            key: ValueKey(expense.id),
                            expense: expense,
                            approverId: user.id,
                            service: service,
                            isPending: isPending,
                            selected: _selectedExpenseIds.contains(expense.id),
                            onToggle: isPending
                                ? () => setState(() {
                                      _selectedExpenseIds.contains(expense.id!)
                                          ? _selectedExpenseIds.remove(expense.id!)
                                          : _selectedExpenseIds.add(expense.id!);
                                    })
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckChip extends StatelessWidget {
  final String label;
  final bool checked;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _CheckChip({
    required this.label,
    required this.checked,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: checked ? color.withOpacity(0.12) : Colors.white,
          border: Border.all(color: checked ? color : const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: checked ? color : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: checked ? color : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color bg;
  final Color fg;
  const _SummaryCard(this.label, this.count, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: fg)),
            Text(label,
                style: TextStyle(fontSize: 10, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _ApprovalRow extends StatelessWidget {
  final ExpenseModel expense;
  final String approverId;
  final FirestoreService service;
  final bool isPending;
  final bool selected;
  final VoidCallback? onToggle;

  const _ApprovalRow({
    super.key,
    required this.expense,
    required this.approverId,
    required this.service,
    required this.isPending,
    required this.selected,
    this.onToggle,
  });

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

  void _showReceipt(BuildContext context) {
    precacheImage(NetworkImage(expense.receiptImageUrl), context);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${expense.userName} 영수증',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ReceiptImageViewer(imageUrl: expense.receiptImageUrl),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0FDF4) : Colors.white,
        border: Border.all(
          color: selected
              ? const Color(0xFF86EFAC)
              : expense.status == 'approved'
                  ? const Color(0xFF93C5FD)
                  : const Color(0xFFE5E7EB),
          width: selected || expense.status == 'approved' ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // 체크박스 (승인필요 항목만)
          if (isPending)
            SizedBox(
              width: 36,
              child: Checkbox(
                value: selected,
                activeColor: const Color(0xFF16A34A),
                onChanged: (_) => onToggle?.call(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          else
            const SizedBox(width: 10),
          // 내용 (탭 → 상세)
          Expanded(
            child: GestureDetector(
              onTap: () => _showDetail(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(expense.userName,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        Text(expense.formattedAmount,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        StatusBadge(expense: expense),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${expense.department} · ${expense.purpose} · ${expense.description}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 영수증 버튼
          if (expense.receiptImageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showReceipt(context),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('영수증',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600)),
              ),
            )
          else
            const SizedBox(width: 8),
        ],
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
            if (!_processing && {'pending', 'approved1'}.contains(e.status)) ...[
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
            ] else if (_processing)
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
