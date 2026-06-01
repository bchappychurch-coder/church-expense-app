import 'package:flutter/material.dart';
import '../models/expense_model.dart';

class StatusBadge extends StatelessWidget {
  final ExpenseModel expense;

  const StatusBadge({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: expense.statusBgColor,
        border: Border.all(color: expense.statusColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        expense.statusLabel,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: expense.statusColor,
        ),
      ),
    );
  }
}
