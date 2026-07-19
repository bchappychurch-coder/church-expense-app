import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/expense_model.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/receipt_image_viewer.dart';
import '../utils/print_utils.dart';
import 'department_screen.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  // 0=1주, 1=1개월, 2=3개월, 3=직접입력
  int _selectedPeriod = 1;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _showPending = true;   // 미결건: pending, approved1
  bool _showApproved = false; // 승인건: approved, completed, rejected

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

  void _showDepartmentSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _DepartmentSettings(),
    );
  }

  void _printSelected(List<ExpenseModel> filtered) {
    final selected = _selectedExpenseIds.isEmpty
        ? filtered
        : filtered.where((e) => _selectedExpenseIds.contains(e.id)).toList();
    if (selected.isEmpty) return;

    final total = selected.fold<int>(0, (sum, e) => sum + e.amount);
    final now = DateTime.now();
    final dateStr = '${now.year}.${now.month.toString().padLeft(2,'0')}.${now.day.toString().padLeft(2,'0')}';

    final rows = selected.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final e = entry.value;
      final dt = e.createdAt.toDate();
      final d = '${dt.month}/${dt.day}';
      return '''
        <tr>
          <td style="text-align:center">$i</td>
          <td style="text-align:center">$d</td>
          <td>${e.userName}</td>
          <td>${e.department}</td>
          <td>${e.purpose} / ${e.description}</td>
          <td style="text-align:right">${e.formattedAmount}</td>
          <td>${e.bankName} ${e.bankAccount}</td>
        </tr>''';
    }).join();

    final formattedTotal = total.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    final html = '''<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <title>지출 결재 내역</title>
  <style>
    body { font-family: "Malgun Gothic", sans-serif; padding: 24px; font-size: 13px; }
    h2 { text-align: center; margin-bottom: 4px; font-size: 18px; }
    .sub { text-align: center; color: #666; margin-bottom: 16px; font-size: 12px; }
    table { border-collapse: collapse; width: 100%; }
    th { background: #6366F1; color: white; padding: 8px 6px; }
    td { border: 1px solid #ddd; padding: 7px 6px; }
    thead tr th { border: 1px solid #5254cc; }
    tfoot td { font-weight: bold; background: #f5f5f5; }
    @media print { body { padding: 0; } }
  </style>
</head>
<body>
  <h2>지출 결재 내역</h2>
  <p class="sub">출력일: $dateStr &nbsp;|&nbsp; 총 ${selected.length}건</p>
  <table>
    <thead>
      <tr>
        <th style="width:32px">No</th>
        <th style="width:48px">날짜</th>
        <th style="width:60px">신청자</th>
        <th style="width:72px">부서</th>
        <th>용도 / 내용</th>
        <th style="width:90px">금액</th>
        <th style="width:160px">계좌</th>
      </tr>
    </thead>
    <tbody>$rows</tbody>
    <tfoot>
      <tr>
        <td colspan="5" style="text-align:right">합 계</td>
        <td style="text-align:right">$formattedTotal원</td>
        <td></td>
      </tr>
    </tfoot>
  </table>
  <script>window.onload = function() { window.print(); };</script>
</body>
</html>''';

    printExpensesHtml(html);
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
        title: Text('${user.name}님 — 전체 현황',
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            tooltip: '홈',
            onPressed: () => Navigator.of(context).pop(),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: '부서 설정',
            onPressed: _showDepartmentSettings,
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
        stream: service.getAllExpenses(),
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
              // 요약 카드 (전체 현황)
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  color: const Color(0xFFDCFCE7),
                  child: Text(
                    '⚡ 송금 처리 필요: $needAction건',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534)),
                  ),
                ),

              // 비밀번호 리셋 요청 배너
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: service.streamPinResetRequests(),
                builder: (context, snap) {
                  final requests = snap.data ?? [];
                  if (requests.isEmpty) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    color: const Color(0xFFFEF3C7),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🔑 비밀번호 리셋 요청',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                        const SizedBox(height: 6),
                        ...requests.map((r) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${r['userName']}님',
                                style: const TextStyle(fontSize: 15, color: Color(0xFF78350F))),
                            TextButton(
                              onPressed: () async {
                                await service.clearPinReset(r['id'] as String);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${r['userName']}님 비밀번호가 초기화됐습니다'),
                                        backgroundColor: const Color(0xFF10B981)),
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('리셋', style: TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                          ],
                        )),
                      ],
                    ),
                  );
                },
              ),

              // 2번째 줄: 필터 (승인필요·기결 + 직접입력)
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
                        if (filtered.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _printSelected(filtered),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.print, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedExpenseIds.isEmpty ? '전체인쇄' : '선택인쇄',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_selectedExpenseIds.isNotEmpty) ...[
                          const SizedBox(width: 8),
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
                          final isPending =
                              _pendingStatuses.contains(expense.status);
                          return _DashboardRow(
                            key: ValueKey(expense.id),
                            expense: expense,
                            service: service,
                            isPending: isPending,
                            selected:
                                _selectedExpenseIds.contains(expense.id),
                            onToggle: isPending
                                ? () => setState(() {
                                      _selectedExpenseIds
                                              .contains(expense.id!)
                                          ? _selectedExpenseIds
                                              .remove(expense.id!)
                                          : _selectedExpenseIds
                                              .add(expense.id!);
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

class _ExpenseRow extends StatelessWidget {
  final ExpenseModel expense;
  final FirestoreService service;
  const _ExpenseRow({required this.expense, required this.service});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: expense.status == 'approved'
                ? const Color(0xFF93C5FD)
                : const Color(0xFFE5E7EB),
            width: expense.status == 'approved' ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.userName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                      '${expense.department} · ${expense.purpose} · ${expense.description}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(expense.formattedAmount,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
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
      builder: (_) =>
          _ManagerDetail(expense: expense, service: service),
    );
  }
}

class _ManagerDetail extends StatefulWidget {
  final ExpenseModel expense;
  final FirestoreService service;
  const _ManagerDetail({required this.expense, required this.service});

  @override
  State<_ManagerDetail> createState() => _ManagerDetailState();
}

class _ManagerDetailState extends State<_ManagerDetail> {
  bool _processing = false;
  bool _showRejectInput = false;
  bool _replacingReceipt = false;
  final _rejectController = TextEditingController();

  @override
  void dispose() {
    _rejectController.dispose();
    super.dispose();
  }

  Future<void> _proxyApprove() async {
    setState(() => _processing = true);
    try {
      await widget.service.proxyApproveExpense(widget.expense.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('대리 승인 처리되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmProxyReject() async {
    final reason = _rejectController.text.trim();
    if (reason.isEmpty) return;
    setState(() => _processing = true);
    await widget.service.rejectExpense(widget.expense.id!, reason);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('대리 반려 처리되었습니다')),
      );
    }
  }

  Future<void> _replaceReceipt() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('영수증 교체'),
        content: const Text('새 영수증 이미지를 선택해주세요'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('카메라'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('갤러리'),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    final xFile = await picker.pickImage(source: source, imageQuality: 85);
    if (xFile == null || !mounted) return;

    setState(() => _replacingReceipt = true);
    try {
      final storageService = StorageService();
      final newUrl = await storageService.uploadReceipt(
        xFile.path,
        widget.expense.userId,
        userName: widget.expense.userName,
        purpose: widget.expense.purpose,
        xFile: xFile,
      );
      await widget.service.updateExpenseReceiptUrl(widget.expense.id!, newUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('영수증이 교체되었습니다'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
        setState(() => _replacingReceipt = false);
      }
    }
  }

  Future<void> _editAmount() async {
    final controller = TextEditingController(
        text: widget.expense.amount.toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('금액 수정', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            suffixText: '원',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1)),
            child: const Text('저장',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final newAmount = int.tryParse(controller.text.replaceAll(',', ''));
    if (newAmount == null || newAmount <= 0) return;
    await widget.service.updateExpenseAmount(widget.expense.id!, newAmount);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('지출 삭제'),
        content: Text('${widget.expense.userName}님의 지출 신청을 삭제할까요?\n삭제하면 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _processing = true);
    await widget.service.deleteExpense(widget.expense.id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _complete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('송금 완료 처리', style: TextStyle(fontSize: 18)),
        content: Text(
            '${widget.expense.userName}님께 ${widget.expense.formattedAmount} 송금 완료로 처리하시겠습니까?',
            style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A)),
            child: const Text('완료 처리',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing = true);
    await widget.service.completeExpense(widget.expense.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.userName,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              StatusBadge(expense: e),
            ],
          ),
          const SizedBox(height: 12),
          _Row('부서', e.department),
          _Row('용도', e.purpose),
          _Row('내용', e.description),
          Row(
            children: [
              const SizedBox(
                width: 56,
                child: Text('금액',
                    style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF))),
              ),
              Expanded(
                child: Text(e.formattedAmount,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                onPressed: _editAmount,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('수정', style: TextStyle(fontSize: 14)),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1)),
              ),
            ],
          ),
          _Row('신청일', e.formattedDate),
          const Divider(height: 24),

          // 은행 계좌 (복사 가능)
          Row(
            children: [
              const SizedBox(
                  width: 56,
                  child: Text('계좌',
                      style: TextStyle(
                          fontSize: 15, color: Color(0xFF9CA3AF)))),
              Expanded(
                child: Text('${e.bankName}  ${e.bankAccount}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: e.bankAccount));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('계좌번호가 복사되었습니다')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Text('영수증',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: _replacingReceipt
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _replaceReceipt,
                    icon: const Icon(Icons.swap_horiz, size: 20),
                    label: const Text('영수증 교체',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          if (e.receiptImageUrl.isNotEmpty)
            ReceiptImageViewer(imageUrl: e.receiptImageUrl)
          else
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(
                child: Text('영수증 없음',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
              ),
            ),
          const SizedBox(height: 20),

          // 대리결재 버튼 (pending, approved1 상태일 때)
          if ((e.status == 'pending' || e.status == 'approved1') && !_processing) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('담당자 대리결재',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            if (_showRejectInput) ...[
              TextField(
                controller: _rejectController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: '반려 사유를 입력해 주세요',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                  ),
                ),
                maxLines: 2,
                autofocus: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _showRejectInput = false;
                        _rejectController.clear();
                      }),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('취소', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmProxyReject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('대리 반려 확인',
                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _showRejectInput = true),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('대리 반려',
                          style: TextStyle(fontSize: 16, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _proxyApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('대리 승인',
                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
          ],

          // 송금완료 버튼 (approved 상태일 때만)
          if (e.status == 'approved' && !_processing)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _complete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('송금 완료 처리',
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            )
          else if (_processing)
            const Center(child: CircularProgressIndicator()),

          const SizedBox(height: 12),
          // 삭제 버튼 (담당자 전용)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              label: const Text('지출 삭제',
                  style: TextStyle(color: Color(0xFFDC2626), fontSize: 16)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDC2626)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
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

class _DashboardRow extends StatelessWidget {
  final ExpenseModel expense;
  final FirestoreService service;
  final bool isPending;
  final bool selected;
  final VoidCallback? onToggle;

  const _DashboardRow({
    super.key,
    required this.expense,
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
      builder: (_) => _ManagerDetail(expense: expense, service: service),
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

class _DepartmentSettings extends StatefulWidget {
  const _DepartmentSettings();

  @override
  State<_DepartmentSettings> createState() => _DepartmentSettingsState();
}

class _DepartmentSettingsState extends State<_DepartmentSettings> {
  final _service = FirestoreService();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('PIN 번호 변경'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '새 PIN 입력',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1)),
            child: const Text('저장',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || controller.text.length < 4) return;
    await _service.updatePin(controller.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN이 변경되었습니다')),
      );
    }
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await _service.addDepartment(name);
    _controller.clear();
  }

  Future<void> _delete(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('부서 삭제'),
        content: Text('"$name" 부서를 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red),
              child: const Text('삭제',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmed == true) await _service.deleteDepartment(name);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('부서 관리',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          StreamBuilder<List<String>>(
            stream: _service.streamDepartments(),
            builder: (context, snapshot) {
              final departments = snapshot.data ?? [];
              return Column(
                children: departments
                    .map((dept) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(dept,
                              style: const TextStyle(fontSize: 16)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _delete(dept),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('PIN 번호 변경',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            trailing: TextButton(
              onPressed: _changePin,
              child: const Text('변경', style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: '새 부서 이름',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF6366F1), width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _add,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: Size.zero,
                ),
                child: const Text('추가',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
