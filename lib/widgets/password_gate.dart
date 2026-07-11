import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

const _maxAttempts = 10;

Future<void> showPasswordGate(
  BuildContext context,
  VoidCallback onSuccess,
) async {
  final controller = TextEditingController();
  int attempts = 0;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) {
        Future<void> verify() async {
          final entered = controller.text.trim();
          String stored;
          try {
            stored = await FirestoreService().getAdminPassword();
          } catch (_) {
            stored = '0000';
          }
          if (entered == stored) {
            if (ctx.mounted) Navigator.pop(ctx);
            onSuccess();
          } else {
            controller.clear();
            setDlg(() => attempts++);
            if (attempts >= _maxAttempts && ctx.mounted) {
              Navigator.pop(ctx);
            }
          }
        }

        return AlertDialog(
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
                onSubmitted: (_) => verify(),
              ),
              if (attempts > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '비밀번호가 틀렸습니다 · ${_maxAttempts - attempts}회 남음',
                    style: const TextStyle(
                        color: Color(0xFFDC2626), fontSize: 13),
                  ),
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
              onPressed: verify,
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
        );
      },
    ),
  );
}
