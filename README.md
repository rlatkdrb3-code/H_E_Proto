# Human Ergonomics Ink A/B Test Prototype

인간공학 수업에서 펜슬 필기 도구의 전환 인터페이스를 비교하기 위해 구현한 Flutter 기반 A/B 테스트 프로토타입입니다. 온라인 강의 화면 위에 필기 레이어를 구성하고, 동일 과업에서 도구 배치와 전환 방식이 수행시간과 오조작에 미치는 차이를 기록합니다.

## Experiment design

- **A안:** 상단 메뉴에서 펜·형광펜·지우개 도구 전환
- **B안:** 좌측 하단 버튼과 프리셋 트레이를 통한 도구 전환
- **측정값:** 도구 접근시간, 전환시간, 오조작 여부, trial별 경과시간
- **데이터 수집:** 가명화한 피실험자 ID와 이벤트 로그를 Google Sheets로 전송
- **조건 통제:** 같은 필기 과업과 화면을 유지하고 도구 전환 인터페이스만 변경

## 구조

- `lib/ink/ink_models.dart`: 펜 도구, 프리셋, 좌표, stroke 데이터 모델
- `lib/ink/ink_canvas.dart`: 필기 입력, 부드러운 선 처리, 형광펜, 지우개, 제외 영역 처리
- `lib/ink/ink_toolbar.dart`: 필기 ON/OFF, 프리셋, 펜 설정, undo, clear 툴바
- `lib/main.dart`: A/B 조건, 실험 세션, 수행 로그 수집을 포함한 시연 화면
- `test/widget_test.dart`: 두 실험 조건의 핵심 UI 회귀 테스트
- `docs/google_sheets_collection.md`: 개인 식별정보와 비밀값을 제외한 수집 구성 예시

## 실행

```bash
flutter pub get
flutter run
```

실험 데이터 수집이 필요한 경우 저장소에 값을 기록하지 않고 실행 시 주입합니다.

```bash
flutter run \
  --dart-define=SHEET_ENDPOINT='<YOUR_APPS_SCRIPT_WEB_APP_URL>' \
  --dart-define=SHEET_TOKEN='<YOUR_SHARED_SECRET>'
```

웹으로 바로 확인하려면:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5317
```
