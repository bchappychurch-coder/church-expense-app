const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
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

// PIN 초기화 요청 → 담당자에게 알림 (create/update 모두 처리)
exports.onPinResetRequested = onDocumentWritten('pinResetRequests/{userId}', async (event) => {
  if (!event.data.after.exists) return; // 삭제 이벤트 무시

  const request = event.data.after.data();

  const managerSnap = await db.collection('users')
    .where('role', '==', 'manager').limit(1).get();
  const token = managerSnap.docs[0]?.data()?.fcmToken;
  if (!token) {
    console.log('담당자 FCM 토큰 없음');
    return;
  }

  try {
    await getMessaging().send({
      token,
      notification: {
        title: 'PIN 초기화 요청',
        body: `${request.userName}님이 비밀번호 초기화를 요청했습니다`,
      },
      android: { priority: 'high' },
      webpush: { headers: { Urgency: 'high' } },
    });
    console.log('PIN 초기화 알림 전송 완료:', request.userName);
  } catch (e) {
    console.error('FCM 전송 실패:', e);
  }
});

// 매주일 오전 8시 5분 → 승인자들에게 미결재 건수 알림
exports.weeklyApprovalReminder = onSchedule({
  schedule: '5 8 * * 0',   // 매주 일요일 08:05 (Asia/Seoul 기준)
  timeZone: 'Asia/Seoul',
}, async (_event) => {
  // 미결재 건수 조회 (pending + approved1)
  const [pendingSnap, approved1Snap] = await Promise.all([
    db.collection('expenses').where('status', '==', 'pending').get(),
    db.collection('expenses').where('status', '==', 'approved1').get(),
  ]);
  const pendingCount = pendingSnap.size + approved1Snap.size;

  // 승인자 FCM 토큰 수집
  const approversSnap = await db.collection('users')
    .where('role', '==', 'approver').get();

  const tokens = approversSnap.docs
    .map(doc => doc.data()?.fcmToken)
    .filter(Boolean);

  if (tokens.length === 0) {
    console.log('승인자 FCM 토큰 없음');
    return;
  }

  const body = pendingCount > 0
    ? `미결재 ${pendingCount}건이 있습니다. 지금 바로 확인해 주세요!`
    : '이번 주 미결재 건이 없습니다. 앱을 확인해 주세요.';

  try {
    const result = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: '⛪ 주일 결재 알림',
        body,
      },
      android: { priority: 'high' },
      webpush: { headers: { Urgency: 'high' } },
    });
    console.log(`주일 결재 알림 전송: 성공 ${result.successCount}, 실패 ${result.failureCount}, 미결재 ${pendingCount}건`);

    // 담당자에게도 알림 전송
    const managerSnap = await db.collection('users')
      .where('role', '==', 'manager').limit(1).get();
    const managerToken = managerSnap.docs[0]?.data()?.fcmToken;
    if (managerToken) {
      await getMessaging().send({
        token: managerToken,
        notification: {
          title: '✅ 주일 결재 알림 발송 완료',
          body: `승인자에게 푸시 메세지 보냈습니다 (${result.successCount}명 전송 완료)`,
        },
        android: { priority: 'high' },
        webpush: { headers: { Urgency: 'high' } },
      });
    }
  } catch (e) {
    console.error('FCM 전송 실패:', e);
  }
});

function _formatAmount(amount) {
  return amount.toLocaleString('ko-KR') + '원';
}
