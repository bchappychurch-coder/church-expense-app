import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/big_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/password_gate.dart';
import 'admin_settings_screen.dart';
import 'department_screen.dart';
import 'approver_screen.dart';
import 'manager_dashboard.dart';
import 'my_history_screen.dart';
import 'receipt_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _notificationService = NotificationService();
  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _initNotifications();
    _checkCameraResume();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _firestoreService.getUsers();
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (e) {
      debugPrint('사용자 로드 오류: $e');
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _initNotifications() async {
    try {
      final token = await _notificationService.initialize();
      debugPrint('FCM Token: $token');
    } catch (e) {
      debugPrint('FCM 초기화 오류 (무시): $e');
    }
  }

  Future<void> _checkCameraResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('pending_user_id');
      final dept = prefs.getString('pending_department');
      if (userId == null || dept == null) return;

      // 카메라에서 돌아온 이미지 확인
      final lostData = await ImagePicker().retrieveLostData();
      if (lostData.file == null) return;

      await _loadUsers();
      if (!mounted) return;

      final user = _users.firstWhere(
        (u) => u.id == userId,
        orElse: () => _users.first,
      );

      prefs.remove('pending_user_id');
      prefs.remove('pending_department');

      context.read<AppProvider>().setUser(user);
      context.read<AppProvider>().setDepartment(dept);

      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ReceiptScreen(initialImagePath: lostData.file!.path),
      ));
    } catch (_) {}
  }

  void _showRegisterDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    void showError(String msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    Future<void> doRegister(BuildContext dialogCtx) async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        showError('이름을 입력해주세요');
        return;
      }

      try {
        final latestUsers = await _firestoreService.getUsers();
        final exists = latestUsers.any((u) => u.name == name);
        if (exists) {
          await _loadUsers(); // 목록 새로고침해서 화면에 표시
          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
          showError('"$name"은 이미 등록된 이름입니다');
          return;
        }

        await _firestoreService.createUser(
          name: name,
          phone: phoneCtrl.text.trim(),
          role: 'member',
        );
        await _loadUsers();
        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      } catch (e) {
        showError('등록 실패: $e');
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('이름 등록',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('이름과 전화번호를 입력해주세요',
                  style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 18),
                onSubmitted: (_) => doRegister(ctx),
                decoration: InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 18),
                onSubmitted: (_) => doRegister(ctx),
                decoration: InputDecoration(
                  labelText: '전화번호 (선택)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => doRegister(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('등록',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onUserSelected(UserModel user) {
    context.read<AppProvider>().setUser(user);

    // 백그라운드로 FCM 토큰 업데이트 (실패해도 무관)
    _notificationService.getToken().then((token) {
      if (token != null) {
        _firestoreService.updateFcmToken(user.id, token);
      }
    }).catchError((_) {});

    // 모든 사용자 → 역할 선택 다이얼로그
    _showRoleDialog(user);
  }

  void _showRoleDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${user.name}님',
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold)),
        content: const Text('무엇을 하시겠어요?',
            style: TextStyle(fontSize: 17, color: Color(0xFF6B7280))),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long, color: Colors.white),
                label: const Text('지출 신청하기',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const DepartmentScreen()));
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.history, color: Colors.white),
                label: const Text('내 신청 내역',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const MyHistoryScreen()));
                },
              ),
              if (user.isManager || user.isApprover) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.approval, color: Colors.white),
                  label: Text(
                    user.isManager ? '전체 현황 보기' : '결재 승인하기',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    showPasswordGate(context, () {
                      if (user.isManager) {
                        Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const ManagerDashboard()));
                      } else {
                        Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const ApproverScreen()));
                      }
                    });
                  },
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        title: const Column(
          children: [
            Text(
              '행복한교회 지출청구',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'made by 주원아빠',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: '관리자 설정',
            onPressed: () => showPasswordGate(context, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminSettingsScreen()),
              ).then((_) => _loadUsers());
            }),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '본인 이름을 눌러주세요',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '이름을 선택하면 지출 신청 화면으로 이동합니다',
                    style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showRegisterDialog,
                      icon: const Icon(Icons.person_add, color: Color(0xFF6366F1)),
                      label: const Text('내 이름 등록하기',
                          style: TextStyle(fontSize: 16, color: Color(0xFF6366F1))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth - 16) / 3;
                        return SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _users.map((user) {
                              final roleLabel = user.isManager
                                  ? '(담당자)'
                                  : user.isApprover
                                      ? '(승인자)'
                                      : '';
                              return SizedBox(
                                width: itemWidth,
                                child: BigButton(
                                  label: user.name,
                                  subLabel: roleLabel.isEmpty ? null : roleLabel,
                                  onTap: () => _onUserSelected(user),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '입금 계좌',
                              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '국민은행  66590101759600',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(
                              const ClipboardData(text: '66590101759600'),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('계좌번호가 복사되었습니다'),
                                backgroundColor: Color(0xFF10B981),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 20, color: Color(0xFF6366F1)),
                          tooltip: '복사',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '앱 주소',
                              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'church-expense-app.web.app',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(
                              const ClipboardData(text: 'https://church-expense-app.web.app'),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('앱 주소가 복사되었습니다'),
                                backgroundColor: Color(0xFF10B981),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 20, color: Color(0xFF6366F1)),
                          tooltip: '복사',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
