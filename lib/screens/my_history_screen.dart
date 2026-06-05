import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense_model.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/receipt_image_viewer.dart';

class MyHistoryScreen extends StatelessWidget {
  const MyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppProvider>().currentUser!;
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        title: const Text('내 신청 내역',
            style: TextStyle(color: Colors.white, fontSize: 20)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
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
          final expenses = snapshot.data ?? [];
          if (expenses.isEmpty) {
            return const Center(
              child: Text('신청 내역이 없습니다',
                  style: TextStyle(fontSize: 18, color: Color(0xFF9CA3AF))),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _ExpenseCard(expense: expenses[i]),
          );
        },
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
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
