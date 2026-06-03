import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/expense_model.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/receipt_image_viewer.dart';
import 'department_screen.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  void _showDepartmentSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _DepartmentSettings(),
    );
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
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: '부서 설정',
            onPressed: () => _showDepartmentSettings(context),
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data ?? [];
          final pending = all.where((e) => e.status == 'pending').length;
          final inProgress = all.where((e) => e.status == 'approved1').length;
          final needAction = all.where((e) => e.status == 'approved').length;
          final completed = all.where((e) => e.status == 'completed').length;
          final rejected = all.where((e) => e.status == 'rejected').length;

          return Column(
            children: [
              // 요약 카드
              Padding(
                padding: const EdgeInsets.all(16),
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

              // 전체 목록
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: all.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ExpenseRow(
                    expense: all[i],
                    service: service,
                  ),
                ),
              ),
            ],
          );
        },
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: fg)),
            Text(label,
                style: TextStyle(fontSize: 11, color: fg)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
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
          if (e.receiptImageUrl.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('영수증',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 8),
            ReceiptImageViewer(imageUrl: e.receiptImageUrl),
          ],
          const SizedBox(height: 20),

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
        ],
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
