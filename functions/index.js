const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

// 지출 신청 생성 → 승인자 2명에게 알림
exports.onExpenseCreated = onDocumentCreated('expenses/{expenseId}', async (event) => {
  const expense = event.data.data();
  const tokens = [];

  for (const field of ['approver1Id', 'approver2Id']) {
    const approverId = expense[field];
    if (!approverId) continue;
    const userDoc = await db.collection('users').doc(approverId).get();
    const token = userDoc.data()?.fcmToken;
    if (token) tokens.push(token);
  }

  if (tokens.length === 0) return;

  await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: '결재 승인 요청',
      body: `${expense.userName}님의 ${expense.purpose} ${_formatAmount(expense.amount)} 결재를 확인해 주세요`,
    },
    android: { priority: 'high' },
  });
});

// 지출 상태 변경 → 관련자에게 알림
exports.onExpenseUpdated = onDocumentUpdated('expenses/{expenseId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  // 두 명 모두 승인 완료 → 담당자에게 알림
  if (after.status === 'approved') {
    const managerSnap = await db.collection('users')
      .where('role', '==', 'manager').limit(1).get();
    const token = managerSnap.docs[0]?.data()?.fcmToken;
    if (token) {
      await getMessaging().send({
        token,
        notification: {
          title: '송금 처리 요청',
          body: `${after.userName}님 ${after.purpose} ${_formatAmount(after.amount)} 처리가 필요합니다`,
        },
        android: { priority: 'high' },
      });
    }
  }

  // 반려 → 신청자에게 알림
  if (after.status === 'rejected') {
    const userDoc = await db.collection('users').doc(after.userId).get();
    const token = userDoc.data()?.fcmToken;
    if (token) {
      await getMessaging().send({
        token,
        notification: {
          title: '결재 반려',
          body: `${after.purpose} 결재가 반려되었습니다: ${after.rejectedReason ?? ''}`,
        },
      });
    }
  }

  // 송금완료 → 신청자에게 알림
  if (after.status === 'completed') {
    const userDoc = await db.collection('users').doc(after.userId).get();
    const token = userDoc.data()?.fcmToken;
    if (token) {
      await getMessaging().send({
        token,
        notification: {
          title: '지출 처리 완료',
          body: `${after.purpose} ${_formatAmount(after.amount)} 송금이 완료되었습니다`,
        },
      });
    }
  }
});

function _formatAmount(amount) {
  return amount.toLocaleString('ko-KR') + '원';
}
