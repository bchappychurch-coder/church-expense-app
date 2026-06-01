# 교회 지출 관리 앱 — 설계 문서

**작성일**: 2026-06-01  
**프로젝트**: 교회 지출 결재 모바일 앱  
**대상 플랫폼**: Android (Flutter)

---

## 1. 프로젝트 목적

교회 교인(특히 60~70대 권사/집사)이 지출 영수증을 사진으로 찍어 결재를 신청하고, 승인자 2명의 동시 승인을 거쳐 담당자에게 전달되는 과정을 모바일 앱으로 간소화한다. 기존의 종이 영수증 → 수기 지출결의서 → 대면 결재 프로세스를 대체한다.

---

## 2. 사용자 역할

| 역할 | 인원 | 권한 |
|------|------|------|
| 일반 교인 | ~50명 | 지출 신청, 본인 신청 내역 조회 |
| 승인자 | 2명 | 신청 건 승인 / 반려 (동시 알림) |
| 담당자 | 1명 | 전체 현황 조회, 최종 송금완료 처리 |

---

## 3. 기술 스택

| 항목 | 선택 | 이유 |
|------|------|------|
| 앱 프레임워크 | Flutter | 큰 버튼/글씨 UI 구현 용이, 안드로이드 단일 타겟 |
| 데이터베이스 | Firebase Firestore | 관리형 서비스, 서버 구축 불필요 |
| 파일 저장 | Firebase Storage | 영수증 사진 저장 |
| 푸시 알림 | Firebase FCM | 무료, Flutter 연동 간편 |
| OCR | Google ML Kit | 기기 내 처리(무료), 네트워크 불필요 |
| 인증 | 이름 목록 선택 | 어르신 편의 최우선, 별도 로그인 없음 |
| 배포 | Google Play Store 또는 APK 직접 설치 | |

---

## 4. 앱 화면 흐름

```
[홈] 이름 선택
    ↓
[부서 선택] 사업부 / 전도국 / 선교국 / 기타 선교회
    ↓
[영수증 촬영] 카메라 → ML Kit OCR → 금액 자동 인식 → 확인/수정
    ↓
[용도 선택] 식비 / 교통비 / 소모품 / 행사비 / 봉사활동 / 기타
           + 상세 내용 직접 입력 (선택 사항, 예: "○○ 행사 다과비")
    ↓
[결재 제출] → FCM 푸시: 승인자 2명에게 동시 발송
    ↓
[승인자 화면] 영수증 사진 확인 → 승인 또는 반려
    (승인자 1, 2 모두 승인 시)
    ↓
[담당자 알림] 최종 처리 요청 푸시 수신
    ↓
[담당자 화면] 은행계좌 확인 → 송금완료 처리
```

- 반려 시: 신청자에게 반려 사유 푸시 알림 발송
- 승인자 중 1명만 승인한 경우: 나머지 1명 승인 대기 상태 유지

---

## 5. Firebase 데이터 구조

### `users` 컬렉션
```
users/{userId}
  - name: string          // 표시 이름 (예: "김영희 권사")
  - phone: string         // 연락처
  - bankName: string      // 은행명 (예: "국민은행")
  - bankAccount: string   // 계좌번호
  - role: "member" | "approver" | "manager"
  - fcmToken: string      // 푸시 알림 토큰
```

### `expenses` 컬렉션
```
expenses/{expenseId}
  - userId: string          // 신청자 ID
  - userName: string        // 신청자 이름
  - department: string      // 부서
  - purpose: string         // 용도 (preset: 식비/교통비/소모품/행사비/봉사활동/기타)
  - description: string     // 사용자가 직접 입력한 상세 내용 (필수, 예: "12/20 중식비")
  - amount: number          // 금액
  - receiptImageUrl: string // Firebase Storage 경로
  - bankName: string        // 신청자 은행명
  - bankAccount: string     // 신청자 계좌번호
  - status: "pending" | "approved1" | "approved" | "completed" | "rejected"
  - approver1Id: string     // 승인자1 ID
  - approver1ApprovedAt: timestamp | null
  - approver2Id: string     // 승인자2 ID
  - approver2ApprovedAt: timestamp | null
  - rejectedReason: string  // 반려 사유
  - createdAt: timestamp
  - completedAt: timestamp | null
```

---

## 6. 화면 목록 (Flutter)

| 화면 | 설명 |
|------|------|
| `HomeScreen` | 교인 이름 목록 (그리드 버튼) |
| `DepartmentScreen` | 부서 선택 (4개 큰 버튼) |
| `ReceiptScreen` | 카메라 촬영 + OCR 금액 확인/수정 |
| `PurposeScreen` | 용도 선택 + 결재 제출 버튼 |
| `MyHistoryScreen` | 본인 신청 내역 및 상태 |
| `ApproverScreen` | 승인자용: 대기 목록 + 상세 + 승인/반려 |
| `ManagerDashboard` | 담당자용: 전체 현황 + 상세 + 송금완료 처리 |

---

## 7. UI 원칙 (60~70대 어르신 대상)

- 버튼 최소 높이: 56dp
- 기본 글씨 크기: 18sp 이상, 제목: 22sp 이상
- 한 화면 내 선택지 최대 4~6개
- 진행 단계 상단에 표시 (예: "2단계 / 4단계")
- 오류 메시지 대신 재시도 버튼 제공
- 색상: 고대비, 흰 배경 + 진한 텍스트

---

## 8. 개인정보 등록 방식

- 앱 내 회원가입 없음
- 담당자 또는 개발자가 Firebase 콘솔에서 직접 등록
- 등록 항목: 이름, 연락처, 은행명, 계좌번호, 역할
- 교인 추가/수정은 Firebase 콘솔 또는 간단한 관리자 웹 페이지로 처리

---

## 9. 서버 비용 예측 (Firebase 무료 플랜 기준)

| 항목 | 예상 사용량 | 무료 한도 |
|------|------------|-----------|
| Firestore 읽기/쓰기 | ~5,000건/월 | 50,000건/일 |
| Storage | ~750MB/월 (사진 500KB × 50건) | 5GB |
| FCM 푸시 알림 | ~500건/월 | 무제한 무료 |

→ **월 비용 0원** (무료 플랜으로 충분)

---

## 10. 개발 범위 외 (향후 고려)

- iOS 지원 (Flutter 코드베이스 재사용 가능)
- Naver Clova OCR 교체 (ML Kit 정확도 부족 시)
- 월별 지출 통계 리포트
- 관리자 전용 웹 대시보드
