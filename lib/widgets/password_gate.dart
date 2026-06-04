import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

/// 관리자 비밀번호 확인 다이얼로그.
/// 비밀번호가 맞으면 [onSuccess] 호출.
Future<void> showPasswordGate(
  BuildContext context,
  VoidCallback onSuccess,
) async {
  final controller = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('관리자 비밀번호',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 22, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '● ● ● ●',
                hintStyle: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 4),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              onSubmitted: (_) => _verify(ctx, controller, setDlg, onSuccess),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () =>
                _verify(ctx, controller, setDlg, onSuccess),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('확인',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

Future<void> _verify(
  BuildContext ctx,
  TextEditingController controller,
  StateSetter setDlg,
  VoidCallback onSuccess,
) async {
  final entered = controller.text.trim();
  String stored;
  try {
    stored = await FirestoreService().getAdminPassword();
  } catch (e) {
    stored = '0000'; // Firestore 연결 실패 시 기본값
  }
  if (entered == stored) {
    if (ctx.mounted) Navigator.pop(ctx);
    onSuccess();
  } else {
    controller.clear();
    setDlg(() {});
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('비밀번호가 틀렸습니다'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
