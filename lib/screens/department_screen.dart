import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/big_button.dart';
import 'receipt_screen.dart';

class DepartmentScreen extends StatelessWidget {
  const DepartmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppProvider>().currentUser!;
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        title: Text(
          '${user.name}님',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepIndicator(current: 1, total: 4),
            const SizedBox(height: 28),
            const Text(
              '사용 부서를 선택해 주세요',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: service.streamDepartments(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final departments = snapshot.data!;
                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.6,
                    children: departments.map((dept) {
                      return BigButton(
                        label: dept,
                        color: const Color(0xFFF0FDF4),
                        borderColor: const Color(0xFF86EFAC),
                        onTap: () {
                          context.read<AppProvider>().setDepartment(dept);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ReceiptScreen()),
                          );
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i + 1 <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 6,
            decoration: BoxDecoration(
              color: active
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
