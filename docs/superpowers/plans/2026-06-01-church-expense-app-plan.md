# 교회 지출 관리 앱 — 개발 구현 계획

**설계 문서**: `docs/superpowers/specs/2026-06-01-church-expense-app-design.md`  
**예상 기간**: 6~8주  
**플랫폼**: Android (Flutter)  
**백엔드**: Firebase

---

## 단계 개요

| 단계 | 내용 | 예상 기간 |
|------|------|-----------|
| 1 | 개발 환경 세팅 | 1~2일 |
| 2 | Firebase 프로젝트 구성 | 1일 |
| 3 | 앱 기본 구조 및 네비게이션 | 2~3일 |
| 4 | 교인 이름 선택 화면 | 1일 |
| 5 | 부서 선택 화면 | 1일 |
| 6 | 영수증 촬영 + OCR | 3~4일 |
| 7 | 용도 선택 + 결재 제출 | 1~2일 |
| 8 | 승인자 화면 | 2~3일 |
| 9 | 담당자 대시보드 | 2~3일 |
| 10 | 푸시 알림 (FCM) | 2일 |
| 11 | 내 신청 내역 화면 | 1일 |
| 12 | 전체 테스트 및 배포 | 3~5일 |

---

## 단계 1: 개발 환경 세팅

### 1-1. Flutter 설치
- Flutter SDK 설치 (https://flutter.dev)
- Android Studio 설치 + Android SDK 설정
- VS Code + Flutter/Dart 플러그인 설치
- `flutter doctor` 실행하여 환경 확인

### 1-2. 프로젝트 생성
```bash
flutter create church_expense_app
cd church_expense_app
```

### 1-3. 패키지 추가 (`pubspec.yaml`)
```yaml
dependencies:
  flutter:
    sdk: flutter
  # Firebase
  firebase_core: ^3.0.0
  cloud_firestore: ^5.0.0
  firebase_storage: ^12.0.0
  firebase_messaging: ^15.0.0
  # OCR
  google_mlkit_text_recognition: ^0.13.0
  # 카메라
  image_picker: ^1.1.0
  camera: ^0.11.0
  # 상태관리
  provider: ^6.1.0
  # 기타
  intl: ^0.19.0
  shared_preferences: ^2.3.0
```

### 확인 기준
- `flutter run` 실행 시 빈 앱이 에뮬레이터에서 동작

---

## 단계 2: Firebase 프로젝트 구성

### 2-1. Firebase 콘솔 설정
1. https://console.firebase.google.com 접속
2. 새 프로젝트 생성: `church-expense-app`
3. Android 앱 추가: 패키지명 `com.church.expense_app`
4. `google-services.json` 다운로드 → `android/app/` 에 복사

### 2-2. Firebase 서비스 활성화
- **Firestore Database**: 프로덕션 모드로 생성 (서울 리전: `asia-northeast3`)
- **Firebase Storage**: 기본 설정으로 활성화
- **Cloud Messaging**: 자동 활성화됨

### 2-3. Firestore 보안 규칙
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 인증된 사용자만 읽기/쓰기
    match /users/{userId} {
      allow read: if true;
      allow write: if false; // 관리자만 콘솔에서 수정
    }
    match /expenses/{expenseId} {
      allow read: if true;
      allow create: if true;
      allow update: if true;
    }
  }
}
```

### 2-4. 초기 교인 데이터 등록 (Firebase 콘솔)
- `users` 컬렉션에 교인 정보 수동 입력
- 필드: `name`, `phone`, `bankName`, `bankAccount`, `role`, `fcmToken`

### 확인 기준
- Flutter 앱에서 Firestore 연결 확인 (테스트 문서 읽기/쓰기)

---

## 단계 3: 앱 기본 구조 및 네비게이션

### 3-1. 폴더 구조
```
lib/
├── main.dart
├── models/
│   ├── user_model.dart
│   └── expense_model.dart
├── services/
│   ├── firestore_service.dart
│   ├── storage_service.dart
│   └── notification_service.dart
├── screens/
│   ├── home_screen.dart          # 이름 선택
│   ├── department_screen.dart    # 부서 선택
│   ├── receipt_screen.dart       # 영수증 촬영+OCR
│   ├── purpose_screen.dart       # 용도 선택+제출
│   ├── my_history_screen.dart    # 내 신청 내역
│   ├── approver_screen.dart      # 승인자 화면
│   └── manager_dashboard.dart   # 담당자 대시보드
├── widgets/
│   ├── big_button.dart           # 어르신용 큰 버튼 공통 위젯
│   └── status_badge.dart         # 상태 표시 뱃지
└── providers/
    └── app_provider.dart          # 현재 로그인 사용자 상태
```

### 3-2. 공통 테마 설정 (`main.dart`)
```dart
ThemeData(
  primarySwatch: Colors.indigo,
  textTheme: TextTheme(
    bodyMedium: TextStyle(fontSize: 18),
    bodyLarge: TextStyle(fontSize: 20),
    titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
  ),
)
```

### 3-3. 라우팅 설정
- `/` → HomeScreen
- `/department` → DepartmentScreen
- `/receipt` → ReceiptScreen
- `/purpose` → PurposeScreen
- `/history` → MyHistoryScreen
- `/approver` → ApproverScreen
- `/manager` → ManagerDashboard

### 확인 기준
- 각 화면 간 네비게이션 동작 확인 (더미 데이터로)

---

## 단계 4: 홈 화면 — 이름 선택

### 4-1. Firestore에서 교인 목록 불러오기
```dart
// firestore_service.dart
Future<List<UserModel>> getUsers() async {
  final snapshot = await firestore.collection('users').orderBy('name').get();
  return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
}
```

### 4-2. UI 구현 (home_screen.dart)
- 상단: 교회 이름 + 앱 타이틀
- 본문: 2열 그리드 버튼 (이름 목록)
- 각 버튼: 높이 70dp 이상, 글씨 20sp, 이름+직분 표시
- 하단: 승인자/담당자 전용 버튼 (해당 역할만 표시)

### 4-3. 이름 선택 후 처리
- `Provider`에 현재 사용자 저장
- DepartmentScreen으로 이동

### 확인 기준
- Firestore 교인 목록이 화면에 표시됨
- 이름 선택 후 다음 화면으로 이동

---

## 단계 5: 부서 선택 화면

### 5-1. UI 구현 (department_screen.dart)
- 상단: 선택한 이름 표시 ("김영희 권사님, 안녕하세요")
- 본문: 2×2 그리드 큰 버튼
  - 사업부 / 전도국 / 선교국 / 기타 선교회
- 각 버튼: 높이 100dp, 글씨 20sp, 아이콘 포함

### 5-2. 상태 저장
- 선택한 부서를 Provider에 저장
- ReceiptScreen으로 이동

### 확인 기준
- 4개 부서 버튼이 명확하게 표시됨
- 선택 후 영수증 화면으로 이동

---

## 단계 6: 영수증 촬영 + OCR 화면

### 6-1. 카메라 권한 설정 (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

### 6-2. 영수증 촬영 기능
```dart
// image_picker로 카메라 실행
final ImagePicker picker = ImagePicker();
final XFile? image = await picker.pickImage(
  source: ImageSource.camera,
  imageQuality: 85,  // 파일 크기 절약
);
```

### 6-3. ML Kit OCR 금액 인식
```dart
Future<String?> extractAmount(String imagePath) async {
  final inputImage = InputImage.fromFilePath(imagePath);
  final textRecognizer = TextRecognizer();
  final recognized = await textRecognizer.processImage(inputImage);
  
  // 금액 패턴 찾기: "합계", "총액", "결제금액" 다음 숫자
  final amountPattern = RegExp(r'(합\s*계|총\s*액|결제금액|받을금액)[^\d]*(\d[\d,]+)');
  final match = amountPattern.firstMatch(recognized.text);
  
  return match?.group(2);  // 인식된 금액 문자열 반환
}
```

### 6-4. UI 구현 (receipt_screen.dart)
- 상단: 진행 단계 표시 (3/4단계)
- 큰 카메라 버튼 (재촬영 가능)
- 촬영된 사진 미리보기 (전체 화면)
- OCR 결과 금액 표시 (노란 박스, 큰 글씨)
- 금액 수정 가능한 숫자 입력 필드
- "다음" 버튼

### 6-5. OCR 실패 처리
- 금액 인식 실패 시: "금액을 직접 입력해 주세요" 안내
- 0원 제출 방지: 금액 > 0 확인

### 확인 기준
- 카메라 실행 및 사진 촬영 가능
- 영수증 사진에서 금액 자동 인식
- 금액 수동 입력 및 수정 가능

---

## 단계 7: 용도 선택 + 결재 제출

### 7-1. UI 구현 (purpose_screen.dart)
- 용도 버튼 (3×2 그리드): 식비 / 교통비 / 소모품 / 행사비 / 봉사활동 / 기타
- 선택한 항목 하이라이트
- **상세 내용 입력 필드**: 용도 버튼 아래 텍스트 입력창
  - 힌트 텍스트: "예) 12/20 중식비, 전도지 인쇄비"
  - **필수 입력** — 빈칸이면 "결재 올리기" 버튼 비활성화
  - 입력 시 버튼 활성화, 미입력 시 버튼 회색 처리 + "내용을 입력해 주세요" 안내
  - 글씨 크기 18sp, 한 줄 입력
- 신청 요약 미리보기: 이름 / 부서 / 금액 / 용도 / 상세내용
- 큰 "결재 올리기" 버튼

### 7-2. 결재 제출 로직
```dart
Future<void> submitExpense() async {
  // 1. 영수증 사진 Firebase Storage에 업로드
  final imageUrl = await storageService.uploadReceipt(imagePath, userId);
  
  // 2. Firestore에 지출 신청 저장
  await firestoreService.createExpense(ExpenseModel(
    userId: currentUser.id,
    userName: currentUser.name,
    department: selectedDepartment,
    purpose: selectedPurpose,
    description: descriptionController.text.trim(),  // 필수 입력 내용
    amount: amount,
    receiptImageUrl: imageUrl,
    bankName: currentUser.bankName,
    bankAccount: currentUser.bankAccount,
    status: 'pending',
    createdAt: Timestamp.now(),
  ));
  
  // 3. 승인자 2명에게 FCM 푸시 알림 전송
  await notificationService.notifyApprovers(expenseId, currentUser.name, amount);
}
```

### 확인 기준
- 제출 후 Firestore에 expense 문서 생성 확인
- Storage에 영수증 사진 저장 확인
- 완료 화면 표시 ("결재가 접수되었습니다")

---

## 단계 8: 승인자 화면

### 8-1. 대기 목록 UI (approver_screen.dart)
- 상단: 처리 대기 건수 배지
- 목록: 신청자명 / 금액 / 부서 / 날짜
- 실시간 업데이트: `StreamBuilder` + Firestore 스트림

### 8-2. 상세 화면
- 영수증 사진 (탭하면 전체화면)
- 신청자 정보: 이름 / 부서 / 용도 / 금액
- 은행계좌 정보
- **승인** 버튼 (초록, 크게) / **반려** 버튼 (빨강)
- 반려 시 사유 입력 다이얼로그

### 8-3. 승인 처리 로직
```dart
Future<void> approveExpense(String expenseId, String approverId) async {
  final expense = await firestoreService.getExpense(expenseId);
  
  // 어느 승인자인지 판단하여 업데이트
  if (expense.approver1Id == approverId) {
    await firestoreService.updateExpense(expenseId, {
      'approver1ApprovedAt': Timestamp.now(),
    });
  } else {
    await firestoreService.updateExpense(expenseId, {
      'approver2ApprovedAt': Timestamp.now(),
    });
  }
  
  // 2명 모두 승인했는지 확인
  final updated = await firestoreService.getExpense(expenseId);
  if (updated.approver1ApprovedAt != null && updated.approver2ApprovedAt != null) {
    await firestoreService.updateExpense(expenseId, {'status': 'approved'});
    await notificationService.notifyManager(expenseId);
    await notificationService.notifyApplicant(expenseId, '승인됨');
  }
}
```

### 확인 기준
- 승인자 화면에서 대기 목록 표시
- 승인 시 status 업데이트 및 담당자 알림 발송
- 반려 시 신청자 알림 + 사유 전달

---

## 단계 9: 담당자 대시보드

### 9-1. 현황 요약 UI (manager_dashboard.dart)
- 상단: 대기중 / 승인중 / 처리완료 / 반려 카운트 카드
- 탭 또는 필터: 전체 / 처리 필요 / 완료
- 목록: 신청자 / 부서 / 금액 / 상태 / 날짜

### 9-2. 상세 화면
- 영수증 사진 + 전체 정보
- **은행계좌 정보** 강조 표시 (복사 버튼 포함)
- **송금완료 처리** 버튼
- 완료 처리 후 신청자에게 알림

### 9-3. 실시간 업데이트
- `StreamBuilder`로 Firestore 실시간 구독
- 새 결재 완료 건 즉시 반영

### 확인 기준
- 전체 지출 현황 실시간 표시
- 송금완료 처리 시 status → 'completed' 업데이트

---

## 단계 10: 푸시 알림 (FCM)

### 10-1. Firebase Cloud Functions 설정
```javascript
// functions/index.js
exports.sendPushNotification = functions.https.onCall(async (data) => {
  const { token, title, body } = data;
  await admin.messaging().send({
    token,
    notification: { title, body },
    android: { priority: 'high' }
  });
});
```

### 10-2. 알림 시나리오
| 이벤트 | 수신자 | 내용 |
|--------|--------|------|
| 결재 제출 | 승인자 2명 | "김영희 권사님의 결재를 확인해 주세요" |
| 1명만 승인 | 나머지 승인자 | "미승인 결재가 있습니다" (당일 재알림) |
| 2명 모두 승인 | 담당자 | "박순자 집사님 8,500원 처리 요청" |
| 반려 | 신청자 | "결재가 반려되었습니다: [사유]" |
| 송금완료 | 신청자 | "지출 처리가 완료되었습니다" |

### 10-3. 앱 시작 시 FCM 토큰 갱신
```dart
// 앱 실행마다 최신 토큰 Firestore에 업데이트
FirebaseMessaging.instance.getToken().then((token) {
  firestoreService.updateFcmToken(currentUserId, token);
});
```

### 확인 기준
- 결재 제출 시 승인자 폰에 푸시 알림 수신 확인
- 백그라운드/포그라운드 모두 알림 동작 확인

---

## 단계 11: 내 신청 내역 화면

### 11-1. UI (my_history_screen.dart)
- 본인 제출 건 목록 (최신순)
- 각 항목: 날짜 / 금액 / 부서 / 상태 뱃지
- 상태: 대기중 🟡 / 승인중 🟠 / 완료 🟢 / 반려 🔴

### 확인 기준
- 본인 신청 내역만 필터링되어 표시

---

## 단계 12: 테스트 및 배포

### 12-1. 기능 테스트 체크리스트
- [ ] 교인 이름 선택 → 부서 → 영수증 촬영 → 제출 전체 흐름
- [ ] OCR 인식 테스트 (마트 영수증, 식당 영수증 등 10종)
- [ ] OCR 실패 시 수동 입력 동작
- [ ] 승인자 2명 동시 승인 후 담당자 알림
- [ ] 1명만 승인 시 status 유지 확인
- [ ] 반려 후 신청자 알림 및 사유 표시
- [ ] 담당자 송금완료 처리 후 신청자 알림
- [ ] 푸시 알림 (포그라운드 / 백그라운드)
- [ ] 60대 테스터 UX 검토 (글씨 크기, 버튼 크기)

### 12-2. 성능 확인
- 영수증 사진 업로드 시간 < 5초 (Wi-Fi 기준)
- OCR 처리 시간 < 3초

### 12-3. 배포 옵션
**A) Google Play 내부 테스트** (추천)
- Google Play Console 등록 → 내부 테스터 이메일 등록
- 교인들 Google 계정으로 초대하여 설치

**B) APK 직접 설치**
- `flutter build apk --release` 로 APK 생성
- 카카오톡으로 APK 파일 전송 → "알 수 없는 앱 설치 허용" 후 설치
- 업데이트 때마다 수동 재배포 필요

### 확인 기준
- 실제 안드로이드 폰에서 전체 흐름 동작 확인
- 교인 5명 이상 베타 테스트 완료

---

## 개발 우선순위 (MVP 기준)

1차 (필수): 단계 1~7, 10 — 기본 결재 흐름 + 알림  
2차 (중요): 단계 8~9 — 승인자·담당자 화면  
3차 (보완): 단계 11~12 — 내역 조회 + 배포

---

## 참고 사항

- Firebase Cloud Functions는 유료 플랜(Blaze) 필요 → 월 $0~수백원 수준
- 대안: FCM 직접 HTTP API 호출 (앱 서버리스 방식, 보안 규칙 주의)
- 영수증 사진은 Firebase Storage에 영구 보관 (기간 정책은 교회 자체 결정)
- 교인 추가/수정은 Firebase 콘솔에서 담당자가 직접 처리
