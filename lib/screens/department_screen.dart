import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/big_button.dart';
import 'receipt_screen.dart';
import 'settings_screen.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: '계좌 관리',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) {
              // 계좌 변경 시 AppProvider 업데이트는 SettingsScreen에서 처리됨
            }),
          ),
        ],
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
                        onTap: () async {
                          final user = context.read<AppProvider>().currentUser!;
                          context.read<AppProvider>().setDepartment(dept);
                          // 카메라 후 앱 재시작 대비 세션 저장
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('session_user_id', user.id);
                          await prefs.setString('session_department', dept);
                          if (!context.mounted) return;
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
