# 교회 지출 관리 앱 - Claude 작업 가이드

## 프로젝트 개요
교회 지출 신청/승인 관리 Flutter 앱. Firebase 백엔드 사용.

## GitHub
https://github.com/bchappychurch-coder/church-expense-app

## Firebase 프로젝트
- Project ID: church-expense-app
- 계정: bchappychurch@gmail.com (Gmail)
- Android 패키지명: com.church.expense_app

## 새 PC에서 시작하는 법
```
git clone https://github.com/bchappychurch-coder/church-expense-app.git
cd church-expense-app
flutter pub get
flutter run -d chrome
```

## 앱 구조
- **홈**: 이름 선택 또는 직접 입력 → PIN 인증(관리자/승인자만)
- **부서 선택**: Firestore `settings/departments`에서 실시간 로드
- **영수증 촬영**: 카메라 촬영 + 금액 직접 입력 (OCR 없음)
- **용도 선택**: 제출 → Firebase Storage 업로드 + Firestore 저장
- **이력 조회**: 영수증 탭하면 전체화면 확대

## 역할(role)
- `member`: 일반 사용자
- `approver`: 승인자 (PIN 필요)
- `manager`: 담당자 (PIN 필요, 전체 현황 + 설정)

## PIN
- 기본값: `1234`
- Firestore `settings/security.pin`에 저장
- 관리자 대시보드 ⚙️ → PIN 번호 변경

## 핸드폰 연결 (Samsung S24 무선)
```
adb pair [IP]:[PAIR_PORT] [6자리코드]
adb connect [IP]:[PORT]
flutter run -d [IP]:[PORT]
```

## 주요 파일
- `lib/screens/home_screen.dart` - 홈 (이름선택, PIN, 세션복구)
- `lib/screens/department_screen.dart` - 부서선택
- `lib/screens/receipt_screen.dart` - 영수증촬영 (카메라 재시작 복구 포함)
- `lib/screens/purpose_screen.dart` - 용도선택 + 제출
- `lib/screens/manager_dashboard.dart` - 담당자 대시보드 + 설정
- `lib/screens/approver_screen.dart` - 승인자 화면
- `lib/screens/my_history_screen.dart` - 내 이력
- `lib/services/firestore_service.dart` - Firestore CRUD
- `lib/widgets/receipt_image_viewer.dart` - 영수증 확대보기

## Android 빌드 설정
- `android/app/build.gradle.kts`: applicationId = "com.church.expense_app"
- `android/build.gradle.kts`: buildscript repositories 포함
- MainActivity: `android/app/src/main/kotlin/com/church/expense_app/`

## 알려진 이슈
- 카메라 촬영 시 Samsung에서 앱 재시작 → 세션 복구로 해결됨
- BigButton overflow 경고 (무시해도 됨, 시각적 영향 없음)
