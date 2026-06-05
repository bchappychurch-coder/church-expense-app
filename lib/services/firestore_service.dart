import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  static const _defaultPurposes = ['식비', '교통비', '소모품', '행사비', '봉사활동', '기타'];
  static const _defaultDepartments = ['사업부', '전도국', '선교국', '기타 선교회'];

  // ── 앱 설정 (config/app) ─────────────────────────────

  Future<Map<String, dynamic>> _getConfigDoc() async {
    final doc = await _db.collection('config').doc('app').get();
    return doc.exists ? (doc.data() as Map<String, dynamic>) : {};
  }

  Future<List<String>> getPurposes() async {
    final data = await _getConfigDoc();
    if (data['purposes'] == null) return List<String>.from(_defaultPurposes);
    return List<String>.from(data['purposes']);
  }

  Future<void> updatePurposes(List<String> purposes) async {
    await _db.collection('config').doc('app')
        .set({'purposes': purposes}, SetOptions(merge: true));
  }

  Future<List<String>> getApproverIds() async {
    final data = await _getConfigDoc();
    return List<String>.from(data['approverIds'] ?? []);
  }

  Future<void> updateApproverIds(List<String> ids) async {
    await _db.collection('config').doc('app')
        .set({'approverIds': ids}, SetOptions(merge: true));
  }

  Future<String> getAdminPassword() async {
    final data = await _getConfigDoc();
    return data['adminPassword'] as String? ?? '0000';
  }

  Future<void> updateAdminPassword(String password) async {
    await _db.collection('config').doc('app')
        .set({'adminPassword': password}, SetOptions(merge: true));
  }

  Future<void> updatePin(String pin) => updateAdminPassword(pin);

  // ── 부서 관리 ─────────────────────────────────────────

  Future<List<String>> getDepartments() async {
    final data = await _getConfigDoc();
    final list = data['departments'];
    if (list == null || (list as List).isEmpty) return List<String>.from(_defaultDepartments);
    return List<String>.from(list);
  }

  Stream<List<String>> streamDepartments() {
    return _db.collection('config').doc('app').snapshots().map((doc) {
      if (!doc.exists) return List<String>.from(_defaultDepartments);
      final data = doc.data() as Map<String, dynamic>;
      final list = data['departments'];
      if (list == null || (list as List).isEmpty) return List<String>.from(_defaultDepartments);
      return List<String>.from(list);
    });
  }

  Future<void> addDepartment(String name) async {
    final data = await _getConfigDoc();
    final existing = data['departments'];
    final departments = existing != null && (existing as List).isNotEmpty
        ? List<String>.from(existing)
        : List<String>.from(_defaultDepartments);
    if (!departments.contains(name)) {
      departments.add(name);
      await _db.collection('config').doc('app')
          .set({'departments': departments}, SetOptions(merge: true));
    }
  }

  Future<void> deleteDepartment(String name) async {
    final data = await _getConfigDoc();
    final existing = data['departments'];
    final departments = existing != null && (existing as List).isNotEmpty
        ? List<String>.from(existing)
        : List<String>.from(_defaultDepartments);
    departments.remove(name);
    await _db.collection('config').doc('app')
        .set({'departments': departments}, SetOptions(merge: true));
  }

  // ── 사용자 ──────────────────────────────────────────

  Future<List<UserModel>> getUsers() async {
    final snap = await _db.collection('users').orderBy('name').get();
    return snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  Future<List<UserModel>> getApprovers() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'approver')
        .get();
    return snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  Future<UserModel?> getManager() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'manager')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromFirestore(snap.docs.first);
  }

  Future<void> updateFcmToken(String userId, String token) async {
    await _db.collection('users').doc(userId).update({'fcmToken': token});
  }

  Future<void> saveUserAccounts(String userId, List accounts) async {
    await _db.collection('users').doc(userId).update({
      'accounts': accounts.map((a) => a.toMap()).toList(),
    });
  }

  Future<String> createUser({
    required String name,
    required String phone,
    required String role,
  }) async {
    final ref = await _db.collection('users').add({
      'name': name,
      'phone': phone,
      'role': role,
      'accounts': [],
      'fcmToken': '',
    });
    return ref.id;
  }

  Future<void> updateUser(String userId, {
    required String name,
    required String phone,
    required String role,
  }) async {
    await _db.collection('users').doc(userId).update({
      'name': name,
      'phone': phone,
      'role': role,
    });
  }

  Future<void> deleteUser(String userId) async {
    await _db.collection('users').doc(userId).delete();
  }

  // ── 지출 신청 ────────────────────────────────────────

  Future<String> createExpense(ExpenseModel expense) async {
    // config 결재자 우선, 없으면 role 기반 fallback
    List<String> approverIds = await getApproverIds();
    if (approverIds.isEmpty) {
      final approvers = await getApprovers();
      approverIds = approvers.map((u) => u.id).toList();
    }

    final data = expense.toMap();
    if (approverIds.isNotEmpty) data['approver1Id'] = approverIds[0];
    if (approverIds.length > 1) data['approver2Id'] = approverIds[1];

    final ref = await _db.collection('expenses').add(data);
    return ref.id;
  }

  Future<ExpenseModel?> getExpense(String expenseId) async {
    final doc = await _db.collection('expenses').doc(expenseId).get();
    if (!doc.exists) return null;
    return ExpenseModel.fromFirestore(doc);
  }

  // 본인 신청 내역
  Stream<List<ExpenseModel>> getMyExpenses(String userId) {
    return _db
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // 승인자용: 대기 중인 건
  Stream<List<ExpenseModel>> getPendingExpenses() {
    return _db
        .collection('expenses')
        .where('status', whereIn: ['pending', 'approved1'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList());
  }

  // 담당자용: 전체
  Stream<List<ExpenseModel>> getAllExpenses() {
    return _db
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList());
  }

  // ── 승인 처리 ────────────────────────────────────────

  Future<bool> approveExpense(String expenseId, String approverId) async {
    final expense = await getExpense(expenseId);
    if (expense == null) return false;

    final Map<String, dynamic> updates = {};

    if (expense.approver1Id == approverId) {
      updates['approver1ApprovedAt'] = Timestamp.now();
    } else if (expense.approver2Id == approverId) {
      updates['approver2ApprovedAt'] = Timestamp.now();
    }

    // 상대방이 이미 승인했는지 확인
    final bool otherAlreadyApproved = expense.approver1Id == approverId
        ? expense.approver2ApprovedAt != null
        : expense.approver1ApprovedAt != null;

    if (otherAlreadyApproved) {
      updates['status'] = 'approved'; // 두 명 모두 승인 완료
    } else {
      updates['status'] = 'approved1'; // 1명 승인 완료
    }

    await _db.collection('expenses').doc(expenseId).update(updates);
    return otherAlreadyApproved; // true면 담당자에게 알림 필요
  }

  Future<void> rejectExpense(String expenseId, String reason) async {
    await _db.collection('expenses').doc(expenseId).update({
      'status': 'rejected',
      'rejectedReason': reason,
    });
  }

  Future<void> completeExpense(String expenseId) async {
    await _db.collection('expenses').doc(expenseId).update({
      'status': 'completed',
      'completedAt': Timestamp.now(),
    });
  }

  Future<void> updateExpenseAmount(String expenseId, int amount) async {
    await _db.collection('expenses').doc(expenseId).update({'amount': amount});
  }

  Future<void> deleteExpense(String expenseId) async {
    await _db.collection('expenses').doc(expenseId).delete();
  }

  // 상태별 건수 스트림 (담당자 대시보드 요약용)
  Stream<Map<String, int>> getStatusCounts() {
    return _db.collection('expenses').snapshots().map((snap) {
      final counts = {'pending': 0, 'approved1': 0, 'approved': 0, 'completed': 0, 'rejected': 0};
      for (final doc in snap.docs) {
        final status = doc['status'] as String? ?? 'pending';
        counts[status] = (counts[status] ?? 0) + 1;
      }
      return counts;
    });
  }
}
