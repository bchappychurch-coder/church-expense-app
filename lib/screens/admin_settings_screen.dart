import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _firestoreService = FirestoreService();

  List<String> _purposes = [];
  List<String> _departments = [];
  List<String> _approverIds = [];
  List<UserModel> _allUsers = [];
  bool _loading = true;
  bool _saving = false;

  static const _roleLabels = {
    'member': '일반',
    'approver': '승인자',
    'manager': '담당자',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _firestoreService.getPurposes(),
      _firestoreService.getApproverIds(),
      _firestoreService.getUsers(),
      _firestoreService.getDepartments(),
    ]);
    if (!mounted) return;
    setState(() {
      _purposes = results[0] as List<String>;
      _approverIds = results[1] as List<String>;
      _allUsers = results[2] as List<UserModel>;
      _departments = results[3] as List<String>;
      _loading = false;
    });
  }

  Future<void> _savePurposes() async {
    setState(() => _saving = true);
    await _firestoreService.updatePurposes(_purposes);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveApprovers() async {
    setState(() => _saving = true);
    await _firestoreService.updateApproverIds(_approverIds);
    // approverIds 변경 시 user.role도 동기화
    for (final user in _allUsers) {
      final shouldBeApprover = _approverIds.contains(user.id);
      if (shouldBeApprover && user.role == 'member') {
        await _firestoreService.updateUser(user.id,
            name: user.name, phone: user.phone, role: 'approver');
      } else if (!shouldBeApprover && user.role == 'approver') {
        await _firestoreService.updateUser(user.id,
            name: user.name, phone: user.phone, role: 'member');
      }
    }
    await _load();
    if (mounted) setState(() => _saving = false);
  }

  // ── 구성원 ──────────────────────────────────────────

  void _showMemberDialog({UserModel? editing}) {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    String role = editing?.role ?? 'member';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(editing == null ? '구성원 추가' : '구성원 수정',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              _InputField(controller: nameCtrl, hint: '이름', label: '이름'),
              const SizedBox(height: 14),
              _InputField(
                  controller: phoneCtrl,
                  hint: '010-0000-0000',
                  label: '전화번호',
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 14),

              const Text('역할',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Row(
                children: _roleLabels.entries.map((e) {
                  final sel = role == e.key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setSheet(() => role = e.key),
                      child: Container(
                        margin: EdgeInsets.only(
                            right: e.key != 'manager' ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF6366F1)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF6366F1)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(e.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF374151),
                            )),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  setState(() => _saving = true);
                  try {
                    if (editing == null) {
                      await _firestoreService.createUser(
                        name: name,
                        phone: phoneCtrl.text.trim(),
                        role: role,
                      );
                    } else {
                      await _firestoreService.updateUser(
                        editing.id,
                        name: name,
                        phone: phoneCtrl.text.trim(),
                        role: role,
                      );
                    }
                    await _load();
                  } finally {
                    if (mounted) setState(() => _saving = false);
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(editing == null ? '추가' : '저장',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteMember(UserModel user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${user.name}님 삭제'),
        content: const Text('이 구성원을 삭제할까요?\n지출 내역은 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _saving = true);
              await _firestoreService.deleteUser(user.id);
              // 결재자로 지정돼 있으면 제거
              if (_approverIds.contains(user.id)) {
                _approverIds.remove(user.id);
                await _firestoreService.updateApproverIds(_approverIds);
              }
              await _load();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('삭제',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── 지출 용도 ─────────────────────────────────────

  void _addPurpose() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('용도 추가'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: '예) 교육비',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty && !_purposes.contains(text)) {
                setState(() => _purposes.add(text));
                _savePurposes();
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('추가',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deletePurpose(String purpose) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('"$purpose" 삭제'),
        content: const Text('이 용도를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _purposes.remove(purpose));
              _savePurposes();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('삭제',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── 부서 관리 ─────────────────────────────────────

  void _addDepartment() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('부서 추가'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: '예) 청년부',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isNotEmpty && !_departments.contains(text)) {
                setState(() => _saving = true);
                await _firestoreService.addDepartment(text);
                await _load();
                if (mounted) setState(() => _saving = false);
              }
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('추가', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteDepartment(String dept) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('"$dept" 삭제'),
        content: const Text('이 부서를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _saving = true);
              await _firestoreService.deleteDepartment(dept);
              await _load();
              if (mounted) {
                setState(() => _saving = false);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── 비밀번호 변경 ─────────────────────────────────

  void _changePassword() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('비밀번호 변경'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PwField(controller: oldCtrl, hint: '현재 비밀번호'),
              const SizedBox(height: 12),
              _PwField(controller: newCtrl, hint: '새 비밀번호'),
              const SizedBox(height: 12),
              _PwField(controller: confirmCtrl, hint: '새 비밀번호 확인'),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style: const TextStyle(
                        color: Color(0xFFDC2626), fontSize: 14)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPw =
                    await _firestoreService.getAdminPassword();
                if (oldCtrl.text != currentPw) {
                  setDlg(() => error = '현재 비밀번호가 틀렸습니다');
                  return;
                }
                if (newCtrl.text.isEmpty) {
                  setDlg(() => error = '새 비밀번호를 입력해주세요');
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  setDlg(() => error = '새 비밀번호가 일치하지 않습니다');
                  return;
                }
                await _firestoreService.updateAdminPassword(newCtrl.text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('비밀번호가 변경되었습니다')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('변경',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        title: const Text('관리자 설정',
            style: TextStyle(color: Colors.white, fontSize: 20)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // ── 구성원 관리 ──
                    _SectionHeader(
                      icon: Icons.people,
                      title: '구성원 관리',
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add,
                            color: Color(0xFF6366F1), size: 26),
                        onPressed: () => _showMemberDialog(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('총 ${_allUsers.length}명',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF9CA3AF))),
                    const SizedBox(height: 12),
                    if (_allUsers.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('구성원이 없습니다.\n+ 버튼으로 추가하세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF9CA3AF))),
                        ),
                      )
                    else
                      ..._allUsers.map((user) => _MemberTile(
                            user: user,
                            roleLabels: _roleLabels,
                            onEdit: () => _showMemberDialog(editing: user),
                            onDelete: () => _deleteMember(user),
                          )),

                    const SizedBox(height: 32),

                    // ── 지출 용도 ──
                    _SectionHeader(
                      icon: Icons.category,
                      title: '지출 용도',
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: Color(0xFF6366F1), size: 28),
                        onPressed: _addPurpose,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _purposes.map((p) {
                        return Chip(
                          label: Text(p,
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF1F2937))),
                          backgroundColor: const Color(0xFFEDE9FE),
                          side: const BorderSide(
                              color: Color(0xFFA78BFA)),
                          deleteIcon: const Icon(Icons.close,
                              size: 16, color: Color(0xFF7C3AED)),
                          onDeleted: () => _deletePurpose(p),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    // ── 부서 관리 ──
                    _SectionHeader(
                      icon: Icons.business,
                      title: '부서 관리',
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: Color(0xFF6366F1), size: 28),
                        onPressed: _addDepartment,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_departments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('부서가 없습니다. + 버튼으로 추가하세요.',
                            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _departments.map((d) {
                          return Chip(
                            label: Text(d,
                                style: const TextStyle(
                                    fontSize: 15, color: Color(0xFF1F2937))),
                            backgroundColor: const Color(0xFFE0F2FE),
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            deleteIcon: const Icon(Icons.close,
                                size: 16, color: Color(0xFF0284C7)),
                            onDeleted: () => _deleteDepartment(d),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 32),

                    // ── 결재자 지정 ──
                    _SectionHeader(
                      icon: Icons.how_to_reg,
                      title: '결재자 지정 (최대 2명)',
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '선택한 사람들이 모든 지출 결재 요청을 받습니다',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(height: 12),
                    ..._allUsers.map((user) {
                      final isSelected = _approverIds.contains(user.id);
                      final isDisabled =
                          !isSelected && _approverIds.length >= 2;
                      return GestureDetector(
                        onTap: isDisabled
                            ? null
                            : () {
                                setState(() {
                                  if (isSelected) {
                                    _approverIds.remove(user.id);
                                  } else {
                                    _approverIds.add(user.id);
                                  }
                                });
                                _saveApprovers();
                              },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEDE9FE)
                                : const Color(0xFFF9FAFB),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFFE5E7EB),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                    : isDisabled
                                        ? const Color(0xFFD1D5DB)
                                        : const Color(0xFF9CA3AF),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(user.name,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: isDisabled
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF1F2937),
                                    )),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '결재자 ${_approverIds.indexOf(user.id) + 1}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 32),

                    // ── 비밀번호 변경 ──
                    _SectionHeader(
                      icon: Icons.lock_outline,
                      title: '관리자 비밀번호',
                    ),
                    const SizedBox(height: 4),
                    const Text('초기 비밀번호: 0000',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF9CA3AF))),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _changePassword,
                      icon: const Icon(Icons.edit,
                          color: Color(0xFF6366F1), size: 20),
                      label: const Text('비밀번호 변경',
                          style: TextStyle(
                              fontSize: 16, color: Color(0xFF6366F1))),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                            color: Color(0xFF6366F1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
                if (_saving)
                  Container(
                    color: Colors.black12,
                    child: const Center(
                        child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final UserModel user;
  final Map<String, String> roleLabels;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemberTile({
    required this.user,
    required this.roleLabels,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = user.isManager
        ? const Color(0xFF1D4ED8)
        : user.isApprover
            ? const Color(0xFF7C3AED)
            : const Color(0xFF374151);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: roleColor.withAlpha(80)),
                      ),
                      child: Text(
                        roleLabels[user.role] ?? user.role,
                        style: TextStyle(
                            fontSize: 12,
                            color: roleColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (user.phone.isNotEmpty)
                  Text(user.phone,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Color(0xFF6366F1), size: 22),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFDC2626), size: 22),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6366F1), size: 22),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937))),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PwField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _PwField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 18),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.label,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
