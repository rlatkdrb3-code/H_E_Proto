# KH Battle Ink Prototype

`kh_battle` 앱의 태블릿 필기 기능을 별도 Flutter 프로토타입으로 분리한 프로젝트입니다.

## 구조

- `lib/ink/ink_models.dart`: 펜 도구, 프리셋, 좌표, stroke 데이터 모델
- `lib/ink/ink_canvas.dart`: 필기 입력, 부드러운 선 처리, 형광펜, 지우개, 제외 영역 처리
- `lib/ink/ink_toolbar.dart`: 필기 ON/OFF, 프리셋, 펜 설정, undo, clear 툴바
- `lib/main.dart`: 온라인 화상강의 UI에 필기 레이어를 얹은 시연 화면

## 실행

```bash
flutter pub get
flutter run
```

웹으로 바로 확인하려면:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5317
```
