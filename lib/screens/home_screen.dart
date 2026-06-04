import 'package:flutter/material.dart';
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('이름 등록',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('이름과 전화번호를 입력해주세요',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: '전화번호 (선택)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                // Firestore에서 최신 목록으로 중복 확인
                final latestUsers = await _firestoreService.getUsers();
                final exists = latestUsers.any((u) => u.name == name);
                if (exists) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('"$name"은 이미 등록된 이름입니다'),
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                    );
                  }
                  return;
                }

                await _firestoreService.createUser(
                  name: name,
                  phone: phoneCtrl.text.trim(),
                  role: 'member',
                );
                await _loadUsers();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('등록',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _onUserSelected(UserModel user) async {
    final token = await _notificationService.getToken();
    if (token != null) {
      await _firestoreService.updateFcmToken(user.id, token);
    }
    if (!mounted) return;
    context.read<AppProvider>().setUser(user);

    // 승인자·담당자도 지출 신청 가능 → 역할 선택 다이얼로그
    if (user.isManager || user.isApprover) {
      _showRoleDialog(user);
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const DepartmentScreen()));
    }
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
        title: const Text(
          '교회 지출 관리',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
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
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final roleLabel = user.isManager
                            ? '(담당자)'
                            : user.isApprover
                                ? '(승인자)'
                                : '';
                        return BigButton(
                          label: user.name,
                          subLabel: roleLabel.isEmpty ? null : roleLabel,
                          onTap: () => _onUserSelected(user),
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
