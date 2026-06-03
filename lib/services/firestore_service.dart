import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

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

  // ── 부서 관리 ────────────────────────────────────────

  static const _defaultDepartments = ['사업부', '전도국', '선교국', '기타 선교회'];

  Stream<List<String>> streamDepartments() {
    return _db.collection('settings').doc('departments').snapshots().map((doc) {
      if (!doc.exists) return _defaultDepartments;
      final list = doc.data()?['list'];
      if (list is List) return List<String>.from(list);
      return _defaultDepartments;
    });
  }

  Future<void> addDepartment(String name) async {
    final ref = _db.collection('settings').doc('departments');
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({'list': [..._defaultDepartments, name]});
    } else {
      final current = List<String>.from(doc.data()?['list'] ?? _defaultDepartments);
      if (!current.contains(name)) {
        current.add(name);
        await ref.update({'list': current});
      }
    }
  }

  Future<void> deleteDepartment(String name) async {
    final ref = _db.collection('settings').doc('departments');
    final doc = await ref.get();
    final current = List<String>.from(doc.data()?['list'] ?? _defaultDepartments);
    current.remove(name);
    await ref.set({'list': current});
  }

  // ── 지출 신청 ────────────────────────────────────────

  Future<String> createExpense(ExpenseModel expense) async {
    final approvers = await getApprovers();
    final data = expense.toMap();

    if (approvers.isNotEmpty) data['approver1Id'] = approvers[0].id;
    if (approvers.length > 1) data['approver2Id'] = approvers[1].id;

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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList());
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
