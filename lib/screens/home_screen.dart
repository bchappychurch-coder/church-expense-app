import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/big_button.dart';
import 'department_screen.dart';
import 'approver_screen.dart';
import 'manager_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _notificationService = NotificationService();
  final _nameController = TextEditingController();
  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _initNotifications();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onDirectNameSubmit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final existing = _users.where((u) => u.name == name).firstOrNull;
    if (existing != null) {
      _onUserSelected(existing);
    } else {
      final tempUser = UserModel(
        id: 'temp_$name',
        name: name,
        phone: '',
        bankName: '',
        bankAccount: '',
        role: 'member',
      );
      _onUserSelected(tempUser);
    }
  }

  Future<void> _loadUsers() async {
    final users = await _firestoreService.getUsers();
    if (mounted) setState(() { _users = users; _loading = false; });
  }

  Future<void> _initNotifications() async {
    final token = await _notificationService.initialize();
    // 토큰은 사용자 선택 후 저장 (이 시점에서는 아직 사용자 미선택)
    debugPrint('FCM Token: $token');
  }

  void _onUserSelected(UserModel user) {
    // 토큰 업데이트는 백그라운드에서 (UI 블로킹 방지)
    _notificationService.getToken().then((token) {
      if (token != null) _firestoreService.updateFcmToken(user.id, token);
    }).catchError((_) {});

    context.read<AppProvider>().setUser(user);

    if (user.isManager || user.isApprover) {
      _showPinDialog(user);
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const DepartmentScreen()));
    }
  }

  void _showPinDialog(UserModel user) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${user.name}님 인증',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PIN 번호를 입력하세요',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              final entered = pinController.text;
              Navigator.pop(context);
              final correctPin = await _firestoreService.getPin();
              if (!mounted) return;
              if (entered == correctPin) {
                _showRoleDialog(user);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN 번호가 틀렸습니다')),
                );
                context.read<AppProvider>().clearUser();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1)),
            child: const Text('확인',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
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
                  if (user.isManager) {
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const ManagerDashboard()));
                  } else {
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const ApproverScreen()));
                  }
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
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '목록에 없으면 직접 입력하세요',
                    style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          onSubmitted: (_) => _onDirectNameSubmit(),
                          decoration: InputDecoration(
                            hintText: '이름 입력',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFFD1D5DB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF6366F1), width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _onDirectNameSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('확인',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
