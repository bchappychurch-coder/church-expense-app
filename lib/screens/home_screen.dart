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
      await _notificationService.initialize();
    } catch (_) {}
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
        if (mounted) _showPinSetupDialog(name);
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

  void _showPinSetupDialog(String userId, {VoidCallback? afterSetup}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          afterSetup != null ? '비밀번호 재설정' : '비밀번호 설정',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Text(
          afterSetup != null
              ? '관리자가 비밀번호를 초기화했습니다.\n새 비밀번호를 설정해주세요.'
              : '내 이름을 누를 때\n비밀번호를 사용하시겠어요?',
          style: const TextStyle(fontSize: 18, height: 1.6, color: Color(0xFF374151)),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showPinInputDialog(userId, afterSave: afterSetup);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('비밀번호 설정하기',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (afterSetup != null) {
                    await _firestoreService.clearPinRequired(userId);
                    await _loadUsers();
                    afterSetup();
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF9CA3AF)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  afterSetup != null ? '나중에 설정하기' : '그냥 사용하기',
                  style: const TextStyle(fontSize: 18, color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ],
      ),
    );
  }

  void _showPinInputDialog(String userId, {VoidCallback? afterSave}) {
    final pinCtrl = TextEditingController();

    Future<void> savePin(BuildContext ctx) async {
      final pin = pinCtrl.text.trim();
      final messenger = ScaffoldMessenger.of(context);
      if (pin.length < 4) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('비밀번호는 4자리 이상 입력해주세요'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
      try {
        await _firestoreService.updateUserPin(userId, pin);
        if (ctx.mounted) Navigator.pop(ctx);
        if (mounted) {
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(
              content: Text('비밀번호가 설정되었습니다'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );
          afterSave?.call();
        }
        _loadUsers(); // 백그라운드로 목록 갱신
      } catch (e) {
        if (mounted) {
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: Text('저장 실패: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('비밀번호 입력',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('사용할 비밀번호(숫자)를 입력해주세요',
                style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              textAlign: TextAlign.center,
              onSubmitted: (_) => savePin(ctx),
              decoration: InputDecoration(
                hintText: '● ● ● ●',
                hintStyle: const TextStyle(fontSize: 18, color: Color(0xFF9CA3AF), letterSpacing: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => savePin(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('저장', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPinVerifyDialog(UserModel user) {
    final pinCtrl = TextEditingController();
    int failCount = 0;
    const maxAttempts = 10;

    void verify(BuildContext ctx, StateSetter setDlg) {
      if (pinCtrl.text.trim() == user.pin) {
        Navigator.pop(ctx);
        _showRoleDialog(user);
      } else {
        pinCtrl.clear();
        failCount++;
        setDlg(() {});
        if (failCount >= maxAttempts) {
          Navigator.pop(ctx);
          showDialog(
            context: context,
            builder: (ctx2) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('비밀번호 ${maxAttempts}회 오류',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              content: const Text(
                '관리자에게 비밀번호 리셋을\n요청할까요?',
                style: TextStyle(fontSize: 17, height: 1.6),
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('취소', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _firestoreService.requestPinReset(user.id, user.name);
                    if (ctx2.mounted) Navigator.pop(ctx2);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('관리자에게 리셋 요청을 보냈습니다'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('요청하기', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('비밀번호가 틀렸습니다 ($failCount/${maxAttempts}회)'),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('${user.name}님',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('비밀번호를 입력해주세요',
                  style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                textAlign: TextAlign.center,
                onSubmitted: (_) => verify(ctx, setDlg),
                decoration: InputDecoration(
                  hintText: '● ● ● ●',
                  hintStyle: const TextStyle(fontSize: 18, color: Color(0xFF9CA3AF), letterSpacing: 4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () => verify(ctx, setDlg),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('확인', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _onUserSelected(UserModel user) {
    context.read<AppProvider>().setUser(user);

    // 이름 탭 시 (사용자 제스처) 권한 요청 + FCM 토큰 저장
    _notificationService.requestPermissionAndGetToken().then((token) {
      if (token != null && token.isNotEmpty) {
        _firestoreService.updateFcmToken(user.id, token);
      }
    }).catchError((_) {});

    if (user.pin != null && user.pin!.isNotEmpty) {
      _showPinVerifyDialog(user);
    } else if (user.pinRequired) {
      _showPinSetupDialog(user.id, afterSetup: () => _showRoleDialog(user));
    } else {
      _showRoleDialog(user);
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
                label: const Text('지출 청구하기',
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
                label: const Text('내 청구 내역',
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
              '행복한교회 지출청구앱',
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
                    '이름을 선택하면 지출 청구 화면으로 이동합니다',
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
                              '국민은행  665901-01-759600',
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
                              const ClipboardData(text: '665901-01-759600'),
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
                ],
              ),
            ),
    );
  }
}
